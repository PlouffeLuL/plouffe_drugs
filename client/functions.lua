local Utils <const> = exports.plouffe_lib:Get("Utils")
local Callback <const> = exports.plouffe_lib:Get("Callback")
local Interface <const> = exports.plouffe_lib:Get("Interface")
local Lang <const> = exports.plouffe_lib:Get("Lang")

local Dr = {}

local Wait <const> = Wait
local PlayerPedId <const> = PlayerPedId
local GetOffsetFromEntityInWorldCoords <const> = GetOffsetFromEntityInWorldCoords
local GetEntityCoords <const> = GetEntityCoords
local GetEntityRotation <const> = GetEntityRotation
local SetEntityCoords <const> = SetEntityCoords
local SetEntityRotation <const> = SetEntityRotation
local PlaceObjectOnGroundProperly <const> = PlaceObjectOnGroundProperly
local DisableControlAction <const> = DisableControlAction
local IsDisabledControlJustReleased <const> = IsDisabledControlJustReleased
local DeleteEntity <const> = DeleteEntity
local TaskTurnPedToFaceEntity <const> = TaskTurnPedToFaceEntity
local SetEntityHeading <const> = SetEntityHeading
local GetEntityHeading <const> = GetEntityHeading
local SetEntityCollision <const> = SetEntityCollision

local plant_types <const> = {
    `bkr_prop_weed_01_small_01c`,
    `bkr_prop_weed_med_01a`,
    `bkr_prop_weed_lrg_01a`
}

local function wake()
    local list = Callback:Sync("plouffe_drugs:loadPlayer")
    for k,v in pairs(list) do
        Dr[k] = v
    end

    Dr:Start()
end
CreateThread(wake)

function Dr:Start()
    self:ExportAllZones()
    self:RegisterEvents()

    if GetConvar("plouffe_drugs:qtarget", "") == "true" then
        if GetResourceState("qtarget") ~= "missing" then
            local breakCount = 0

            while GetResourceState("qtarget") ~= "started" and breakCount < 30 do
                breakCount += 1
                Wait(1000)
            end

            if GetResourceState("qtarget") ~= "started" then
                return
            end

            exports.qtarget:AddTargetModel(plant_types,{
                distance = 1.5,
                options = {
                    {
                        icon = 'fas fa-info',
                        label = "Menu",
                        action = Dr.WeedInteractionMenu
                    }
                }
            })

            exports.qtarget:AddTargetModel({`v_ret_ml_tableb`},{
                distance = 1.5,
                options = {
                    {
                        icon = 'fas fa-info',
                        label = "Menu",
                        action = Dr.MethInteractionMenu
                    }
                }
            })

            exports.qtarget:AddTargetModel({`prop_barrel_02a`},{
                distance = 1.5,
                options = {
                    {
                        icon = 'fas fa-info',
                        label = Lang.bank_tryLoot,
                        action = Dr.LootBarrel
                    }
                }
            })
        end
    end
end

function Dr:ExportAllZones()
    for k,v in pairs(self.Zones) do
        local registered, reason = exports.plouffe_lib:Register(v)
    end
end

function Dr:RegisterEvents()
    AddEventHandler("plouffe_drugs:onZone", function(params)
        if self[params.fnc] then
            self[params.fnc](self, params)
        end
    end)

    AddStateBagChangeHandler("table_smoke", nil, function(bagName,key,value,reserved,replicated)
        if value ~= true then
            return
        end

        local str = bagName:gsub("entity:", "")
        local netId = tonumber(str)
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            self.ParticleFx("exp_grd_flare", entity, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 1.0)
        end
	end)

    AddStateBagChangeHandler("table_fire", nil, function(bagName,key,value,reserved,replicated)
        if value ~= true then
            return
        end

        local str = bagName:gsub("entity:", "")
        local netId = tonumber(str)
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            self.ParticleFx("ent_ray_heli_aprtmnt_l_fire", entity,  0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.2)
        end
	end)

    AddStateBagChangeHandler("airdrop_smoke", nil, function(bagName,key,value,reserved,replicated)
        if value ~= true then
            StopParticleFxLooped(self.barrel_particles, 1)
            self.barrel_particles = nil
            return
        end

        local str = bagName:gsub("entity:", "")
        self:GenerateBarrelSmoke(tonumber(str))
	end)
end

function Dr:PlaceWeedPot()
    if self.placingWeed then
        self.placingWeed = false
        return
    end

    Interface.Notifications.Show({
        style = "info",
        header = "Weed controls",
        persistentId = "weed_press_e",
        message = Lang.press_e_to_confirm
    })

    Interface.Notifications.Show({
        style = "info",
        header = "Weed controls",
        persistentId = "weed_press_c",
        message = Lang.press_c_to_cancel
    })

    self.placingWeed = true

    local ped = PlayerPedId()
    local offSet = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.5, 0.0)
    local object = Utils:CreateProp("bkr_prop_weed_01_small_01c", offSet, 0.0, true, false)
    local rotation = GetEntityRotation(object)
    local isCanceled = false

    SetEntityCollision(object, false, true)
    SetEntityAlpha(object, 150)

    while self.placingWeed do
        Wait(0)
        offSet = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
        SetEntityCoords(object, offSet.x, offSet.y, offSet.z)
        SetEntityRotation(object, rotation.x, rotation.y, rotation.z)
        PlaceObjectOnGroundProperly(object)

        DisableControlAction(0, 26)
        DisableControlAction(0, 38)

        if IsDisabledControlJustReleased(0, 26) then
            isCanceled = true
            self.placingWeed = false
        elseif IsDisabledControlJustReleased(0, 38) then
            self.placingWeed = false
        end
    end

    local data = {
        rotation = rotation,
        coords = GetEntityCoords(object)
    }

    DeleteEntity(object)

    Interface.Notifications.Remove("weed_press_e")
    Interface.Notifications.Remove("weed_press_c")

    return not isCanceled and data or nil
end

function Dr.GetClosestPlant(pedCoords)
    local entity = 0

    for k,v in pairs(plant_types) do
        entity = GetClosestObjectOfType(pedCoords.x, pedCoords.y, pedCoords.z, 1.0, v, false, true, true)
        if entity ~= 0 then
            return entity, NetworkGetNetworkIdFromEntity(entity)
        end
    end
end

function Dr.PlantWeed()
    for k,v in pairs(Dr.plants_items) do
        if Utils:GetItemCount(k) < v then
            return Interface.Notifications.Show({
                style = "error",
                header = "Weed",
                message = Lang.missing_something
            })
        end
    end

    local position = Dr:PlaceWeedPot()
    if not position then
        return
    end

    for k,v in pairs(Dr.Weed.blacklickzones) do
        if #(position.coords - v.coords) < v.distance then
            return Interface.Notifications.Show({
                style = "error",
                header = "Weed",
                message = Lang.cant_plant_here
            })
        end
    end

    if #Dr.Weed.whitelistzones > 0 then
        local isInZone = false
        for k,v in pairs(Dr.Weed.whitelistzones) do
            if #(position.coords - v.coords) < v.distance then
                isInZone = true
                break
            end
        end

        if not isInZone then
            return Interface.Notifications.Show({
                style = "error",
                header = "Weed",
                message = Lang.cant_plant_here
            })
        end
    end


    TriggerServerEvent("plouffe_drugs:plant_weed", position, Dr.auth)
end
exports("PlantWeed", Dr.PlantWeed)

function Dr.AddWater(item)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local entity, netId = Dr.GetClosestPlant(pedCoords)

    if not netId then
        return
    end

    if not Dr.water_items[item] or Utils:GetItemCount(item) < 1 then
        return Interface.Notifications.Show({
            style = "error",
            header = "Weed",
            message = Lang.missing_something
        })
    end

    TaskTurnPedToFaceEntity(ped, entity, 2000)

    local finished = Interface.Progress.Circle({
        duration = 5000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'missfam4',
            clip = 'base'
        },
        prop = {
            bone = 36029,
            model = `prop_wateringcan`,
            pos = vec3(0.10, -0.22, 0.02),
            rot = vec3(-90.0, 0.0, -40.0)
        }
    })

    if not finished then
        return
    end

    TriggerServerEvent("plouffe_drugs:water_weed", netId, item, Dr.auth)
end
exports("AddWater", Dr.AddWater)

function Dr.AddFert(item)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local entity, netId = Dr.GetClosestPlant(pedCoords)

    if not netId then
        return
    end

    if not Dr.fert_items[item] or Utils:GetItemCount(item) < 1 then
        return Interface.Notifications.Show({
            style = "error",
            header = "Weed",
            message = Lang.missing_something
        })
    end

    TaskTurnPedToFaceEntity(ped, entity, 2000)

    local finished = Interface.Progress.Circle({
        duration = 5000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'impexp_int-0',
            clip = 'mp_m_waremech_01_dual-0'
        },
        prop = {
            bone = 24817,
            model = `prop_cs_sack_01`,
            pos = vec3(-0.20, 0.46, 0.016),
            rot = vec3(0.0, -90.0, 0.0)
        }
    })

    if not finished then
        return
    end

    TriggerServerEvent("plouffe_drugs:fert_weed", netId, item, Dr.auth)
end
exports("AddFert", Dr.AddFert)

function Dr.WeedInteractionMenu()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local entity, netId = Dr.GetClosestPlant(pedCoords)

    if not netId then
        return
    end

    local data = Callback:Sync("plouffe_drugs:get_plant_data", netId, Dr.auth)

    if not data then
        return
    end

    local menu = {
        {
            header = Lang.quality,
            text = ("%s / 100"):format(math.floor(data.quality))
        },
        {
            header = Lang.water,
            text = ("%s / 100"):format(math.floor(data.water))
        },
        {
            header = Lang.fert,
            text = ("%s / 100"):format(math.floor(data.fert))
        },
        {
            header = Lang.destroy,
            fn = Dr.DestroyPlant
        }
    }

    if data.isReady then
        table.insert(menu,         {
            header = Lang.harvest,
            fn = Dr.HarvestPlant
        })
    end

    if Dr.AllowAdvancedData then
        menu[#menu+1] = {
            header = "Data",
            fn = Dr.ShowAdvancedPlantData
        }
    end

    local clicked = Interface.Menu.Open(menu)

    if not clicked or not clicked.fn then
        return
    end

    clicked.fn(netId)
end

function Dr.ShowAdvancedPlantData(netId)
    Wait(100)
    local data, time_data = Callback:Sync("plouffe_drugs:get_advanced_plant_data", netId, Dr.auth)
    if not data then
        return
    end

    local menu = {
        {
            header = "Time passed",
            text = tostring(time_data.time_passed)
        },
        {
            header = "Growth time",
            text = tostring(time_data.growth_time)
        },
        {
            header = "Creation os time",
            text = tostring(data.creation_time)
        },
        {
            header = "Is ready",
            text = tostring(data.isReady or "false")
        },
        {
            header = "Fert",
            text = tostring(data.fert)
        },
        {
            header = "Min Required Fert",
            text = tostring(data.requirement.fert)
        },
        {
            header = "Water",
            text = tostring(data.water)
        },
        {
            header = "Min Required Water",
            text = tostring(data.requirement.water)
        },
        {
            header = "Quality",
            text = tostring(data.quality)
        },
        {
            header = "Quality Reducer",
            text = tostring(data.quality_reducer)
        },
        {
            header = "Sex",
            text = tostring(data.sex)
        },
        {
            header = "Age",
            text = tostring(data.age)
        },
        {
            header = "Creator unique",
            text = tostring(data.creator)
        }
    }

    local clicked = Interface.Menu.Open(menu)
end
exports("ShowAdvancedPlantData", Dr.ShowAdvancedPlantData)

function Dr.DestroyPlant(netId)
    local finished = Interface.Progress.Circle({
        duration = 5000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'random@mugging4',
            clip = 'struggle_loop_b_thief',
            flag = 1
        }
    })

    if not finished then
        return
    end

    TriggerServerEvent("plouffe_drugs:destroy_weed", netId, Dr.auth)
end

function Dr.HarvestPlant(netId)
    local finished = Interface.Progress.Circle({
        duration = 5000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'amb@prop_human_bum_bin@base',
            clip = 'base'
        }
    })

    if not finished then
        return
    end

    TriggerServerEvent("plouffe_drugs:harvest_weed", netId, Dr.auth)
end

function Dr.OnWeed()
    local finished = Interface.Progress.Circle({
        duration = 10000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            combat = true
        },
        anim = {
            dict = 'anim@safehouse@bong',
            clip = 'bong_stage3'
        },
        prop = {
            bone = 18905,
            model = `hei_heist_sh_bong_01`,
            pos = vec3(0.10, -0.25, 0.0),
            rot = vec3(95.0, 190.0, 180.0)
        }
    })

    if Dr.onWeed or not finished then
        return
    end

    Dr.onWeed = true

    local amount = 25
    local ped = PlayerPedId()

    while amount > 0 and Dr.onWeed and not IsPedDeadOrDying(ped) do
        local newHealth = GetEntityHealth(ped) + 1
        amount -= 1
        SetEntityHealth(ped, newHealth)
        Wait(1000)    
    end

    Dr.onWeed = false
end
exports("OnWeed", Dr.OnWeed)

function Dr.PlaceTable()
    for k,v in pairs(Dr.table_items) do
        if Utils:GetItemCount(k) < v then
            return Interface.Notifications.Show({
                style = "error",
                header = "Meth",
                message = Lang.missing_something
            })
        end
    end

    local position = Dr:PlaceMethTable()
    if not position then
        return
    end

    for k,v in pairs(Dr.Meth.blacklickzones) do
        if #(position.coords - v.coords) < v.distance then
            return Interface.Notifications.Show({
                style = "error",
                header = "Meth",
                message = Lang.cant_place_here
            })
        end
    end

    if #Dr.Meth.whitelistzones > 0 then
        local isInZone = false
        for k,v in pairs(Dr.Meth.whitelistzones) do
            if #(position.coords - v.coords) < v.distance then
                isInZone = true
                break
            end
        end

        if not isInZone then
            return Interface.Notifications.Show({
                style = "error",
                header = "Meth",
                message = Lang.cant_place_here
            })
        end
    end

    TriggerServerEvent("plouffe_drugs:place_table", position, Dr.auth)
end
exports("PlaceTable", Dr.PlaceTable)

function Dr:PlaceMethTable()
    if self.placingMethTable then
        self.placingMethTable = false
        return
    end

    Interface.Notifications.Show({
        style = "info",
        header = "Meth controls",
        persistentId = "weed_press_e",
        message = Lang.press_e_to_confirm
    })

    Interface.Notifications.Show({
        style = "info",
        header = "Meth controls",
        persistentId = "weed_press_c",
        message = Lang.press_c_to_cancel
    })

    self.placingMethTable = true

    local ped = PlayerPedId()
    local offSet = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.5, 0.0)
    local object = Utils:CreateProp("v_ret_ml_tableb", offSet, 0.0, true, false)
    local rotation = GetEntityRotation(object)
    local isCanceled = false

    SetEntityCollision(object, false, true)
    SetEntityAlpha(object, 150)

    while self.placingMethTable do
        Wait(0)
        local pedHeading = GetEntityHeading(ped)
        offSet = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
        SetEntityCoords(object, offSet.x, offSet.y, offSet.z)
        SetEntityRotation(object, rotation.x, rotation.y, rotation.z)
        SetEntityHeading(object, pedHeading)
        PlaceObjectOnGroundProperly(object)

        DisableControlAction(0, 26)
        DisableControlAction(0, 38)

        if IsDisabledControlJustReleased(0, 26) then
            isCanceled = true
            self.placingMethTable = false
        elseif IsDisabledControlJustReleased(0, 38) then
            self.placingMethTable = false
        end
    end
    local coords = GetEntityCoords(object)
    local data = {
        rotation = GetEntityRotation(object),
        coords = vector3(coords.x, coords.y, coords.z - 0.5)
    }

    DeleteEntity(object)

    Interface.Notifications.Remove("weed_press_e")
    Interface.Notifications.Remove("weed_press_c")

    return not isCanceled and data or nil
end

function Dr.GetClosestTable(pedCoords)
    local entity = 0

    entity = GetClosestObjectOfType(pedCoords.x, pedCoords.y, pedCoords.z, 1.5, `v_ret_ml_tableb`, false, true, true)
    if entity ~= 0 then
        return entity, NetworkGetNetworkIdFromEntity(entity)
    end
end

function Dr.StartCooking(entity, netId)
    local ped = PlayerPedId()
    local finished

    if Entity(entity).state.table_inuse then
        return Interface.Notifications.Show({
            style = "info",
            header = "Meth table",
            message = "Already in use"
        })
    end

    Entity(entity).state.table_inuse = true

    TaskTurnPedToFaceEntity(ped, entity, 2000)

    CreateThread(function()
        finished = Interface.Progress.Circle({
            duration = 30000,
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            },
            anim = {
                dict = 'anim@arena@amb@seating@seat_c@',
                clip = 'pour'
            }
        })
    end)

    local interval = math.random(1000, 5000)
    local lastPick = GetGameTimer()

    while finished == nil do
        Wait(100)

        if GetGameTimer() - lastPick > interval then
            interval = math.random(1000, 5000)

            local succes = Interface.Lockpick.New({
                amount = 0,
                range = 20,
                maxKeys = 4
            })

            lastPick = GetGameTimer()

            if not succes then
                Interface.Progress.Cancel()

                Entity(entity).state.table_fire = true
                Wait(500)
                Entity(entity).state.table_fire = false
            else
                Entity(entity).state.table_smoke = true
                Wait(500)
                Entity(entity).state.table_smoke = false
            end
        end
    end

    Entity(entity).state.table_inuse = false

    TriggerServerEvent("plouffe_drugs:finished_cooking", netId, finished, Dr.auth)
end

function Dr.ParticleFx(name, entity, x,y,z,x2,y2,z2,scale)
    local particles
    UseParticleFxAsset("core")
    particles = StartNetworkedParticleFxLoopedOnEntity(name, entity, x, y, z, x2, y2, z2, scale, false, false, false)
    SetTimeout(500, function()
        StopParticleFxLooped(particles,1)
    end)
end

function Dr.MethInteractionMenu()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local entity, netId = Dr.GetClosestTable(pedCoords)

    if not netId then
        return
    end

    local data = Callback:Sync("plouffe_drugs:get_table_data", netId, Dr.auth)

    if not data then
        return
    end

    local menu = {
        {
            header = Lang.durability,
            text = ("%s / 100"):format(math.floor(data.durability))
        },
        {
            header = Lang.destroy,
            fn = Dr.DestroyTable
        },
        {
            header = Lang.start_cooking,
            fn = Dr.StartCooking
        }
    }

    local clicked = Interface.Menu.Open(menu)

    if not clicked or not clicked.fn then
        return
    end

    clicked.fn(entity, netId)
end

function Dr.DestroyTable(entity, netId)
    local finished = Interface.Progress.Circle({
        duration = 10000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = "amb@prop_human_bum_bin@base",
            clip = "base"
        }
    })

    if not finished then
        return
    end

    TriggerServerEvent("plouffe_drugs:destroy_meth", netId, Dr.auth)
end

function Dr.OnMeth()
    local finished = Interface.Progress.Circle({
        duration = 10000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            combat = true
        },
        anim = {
            dict = 'switch@trevor@trev_smoking_meth',
            clip = 'trev_smoking_meth_loop',
        },
        prop = {
            bone = 28422,
            model = `prop_cs_meth_pipe`,
            pos = vec3(-0.0, -0.0, -0.02),
            rot = vec3(0.0, 50.0, 0.0)
        }
    })

    if Dr.onMeth or not finished then
        return
    end

    Dr.onMeth = true

    SetPedCanRagdoll(PlayerPedId(), false)

    SetTimeout(45000, function()
        SetPedCanRagdoll(PlayerPedId(), true)
        Dr.onMeth = false
    end)
end
exports("OnMeth", Dr.OnMeth)

function Dr:RequestCokeDrop()
    local finished = Interface.Progress.Circle({
        duration = 10000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            combat = true
        },
        anim = {
            dict = '"cellphone@',
            clip = 'cellphone_call_listen_base',
        },
        prop = {
            bone = 28422,
            model = `prop_npc_phone_02`,
            pos = vec3(-0.0, -0.0, -0.0),
            rot = vec3(0.0, 0.0, 0.0)
        }
    })

    if not finished then
        return
    end

    local data, reason = Callback:Sync("plouffe_drugs:generate_plane_data", Dr.auth)
    if not data then
        return Interface.Notifications.Show({
            style = "info",
            header = "Coke",
            message = reason
        })
    end

    local vehicle = NetworkGetEntityFromNetworkId(data.vehicle_net)
    local ped = NetworkGetEntityFromNetworkId(data.ped_net)
    local barrel = NetworkGetEntityFromNetworkId(data.barrel_net)
    local rope = NetworkGetEntityFromNetworkId(data.rope_net)

    SetBlockingOfNonTemporaryEvents(ped, true)

    SetEntityInvincible(vehicle, true)
    SetEntityInvincible(ped, true)

    SetVehicleEngineOn(vehicle, true, true, true)
    SetHeliBladesFullSpeed(vehicle)

    TaskVehicleDriveToCoord(ped, vehicle, data.destination.x,data.destination.y,data.destination.z + 20, 5.0, 1.0, `cargobob`, 16777216, 1.0, true)
    AttachEntityToEntity(rope, vehicle, -1, 0.0, 1.0, -15.0, 0.0, 0.0, 0.0, false, true, false, false, 0, true)
    AttachEntityToEntity(barrel, rope, -1, 0.0, 0.0, -0.2, 0.0, 0.0, 0.0, false, true, false, false, 0, true)

    FreezeEntityPosition(vehicle, false)

    TriggerEvent("plouffe_drugs:on_airdrop")
end

function Dr.ReleaseEntities()
    local pId = PlayerId()

    local data = {
        rope = NetworkGetEntityFromNetworkId(GlobalState.active_air_drop.rope_net),
        vehicle = NetworkGetEntityFromNetworkId(GlobalState.active_air_drop.vehicle_net),
        ped = NetworkGetEntityFromNetworkId(GlobalState.active_air_drop.ped_net)
    }

    for k,v in pairs(data) do
        if DoesEntityExist(v) and NetworkGetEntityOwner(v) == pId then
            SetEntityAsNoLongerNeeded(v)
        end
    end
end

function Dr:GenerateBarrelSmoke(netId)
    self:ReleaseEntities()

    if self.barrel_particles then
        StopParticleFxLooped(self.barrel_particles, 1)
        self.barrel_particles = nil
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local break_count = 20

    while not DoesEntityExist(entity) and break_count > 0 do
        Wait(1000)
        entity = NetworkGetEntityFromNetworkId(netId)
        break_count -= 1
    end

    if DoesEntityExist(entity) then
        if  NetworkGetEntityOwner(entity) == PlayerId() and IsEntityAttached(entity) then
            DetachEntity(entity,true,true)
            FreezeEntityPosition(entity,false)
            SetEntityVelocity(entity, 0.0, 0.0, - 0.5)
        end

        if DoesParticleFxLoopedExist(self.barrel_particles) then
            StopParticleFxLooped(self.barrel_particles, 1)
        end

        UseParticleFxAsset("core")
        self.barrel_particles = StartNetworkedParticleFxLoopedOnEntity("exp_grd_flare", entity,  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, false, false, false)
    end
end

function Dr.LootBarrel()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local entity = GetClosestObjectOfType(pedCoords.x, pedCoords.y, pedCoords.z, 5.0, `prop_barrel_02a`, false, true, true)

    if not DoesEntityExist(entity) then
        return
    end

    local finished = Interface.Progress.Circle({
        duration = 10000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = "amb@prop_human_bum_bin@base",
            clip = "base",
            flag = 1
        }
    })

    if not finished then
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)

    TriggerServerEvent("plouffe_drugs:loot_barrel", netId, Dr.auth)
end

function Dr.OnCoke()
    local finished = Interface.Progress.Circle({
        duration = 10000,
        useWhileDead = false,
        canCancel = true,
        disable = {
            combat = true
        },
        anim = {
            dict = 'switch@trevor@trev_smoking_meth',
            clip = 'trev_smoking_meth_loop',
        },
        prop = {
            bone = 28422,
            model = `h4_prop_h4_coke_tube_01`,
            pos = vec3(-0.0, -0.0, -0.02),
            rot = vec3(0.0, 50.0, 0.0)
        }
    })

    if Dr.onCoke or not finished then
        return
    end

    Dr.onCoke = true

    local ped = PlayerPedId()
    local player = PlayerId()
    local init = GetGameTimer()

    local modifierStrength = 0
    local isSpeedBoost = false

    local lastRandi = 0

    CreateThread(function()
        SetTimecycleModifier("BikerFilter")
        local time = GetGameTimer()

        while time - init < 60000 and not LocalPlayer.state.dead do
            time = GetGameTimer()

            if time - lastRandi > 5000 then
                local randi = math.random(1,100)
                local isUnlucky = 10 > randi

                if isUnlucky then
                    SetPedToRagdoll(ped, 500, 500, 0, 0, 0, 0)
                end

                lastRandi = time
            end

            if modifierStrength <= 0.7 and not isSpeedBoost then
                modifierStrength += 0.001

                if modifierStrength >= 0.7 then
                    SetRunSprintMultiplierForPlayer(player, 1.49)
                    isSpeedBoost = true
                end
            elseif isSpeedBoost then
                modifierStrength -= 0.001
                ResetPlayerStamina(player)

                if modifierStrength <= 0 then
                    isSpeedBoost = false
                    SetRunSprintMultiplierForPlayer(player, 1.0)
                end
            end

            Wait(0)

            SetTimecycleModifierStrength(modifierStrength)
        end

        ClearTimecycleModifier()
        SetRunSprintMultiplierForPlayer(player, 1.0)

        Dr.onCoke = false
    end)
end
exports("OnCoke", Dr.OnCoke)