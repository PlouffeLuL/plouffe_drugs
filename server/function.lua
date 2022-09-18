local Auth <const> = exports.plouffe_lib:Get("Auth")
local Utils <const> = exports.plouffe_lib:Get("Utils")
local Callback <const> = exports.plouffe_lib:Get("Callback")
local Lang <const> = exports.plouffe_lib:Get("Lang")
local Inventory <const> = exports.plouffe_lib:Get("Inventory")
local Uniques <const> = exports.plouffe_lib:Get("Uniques")

local CreateObject <const> = CreateObject
local GetEntityModel <const> = GetEntityModel
local NetworkGetNetworkIdFromEntity <const> = NetworkGetNetworkIdFromEntity
local NetworkGetEntityFromNetworkId <const> = NetworkGetEntityFromNetworkId
local DoesEntityExist <const> = DoesEntityExist
local DeleteEntity <const> = DeleteEntity
local FreezeEntityPosition <const> = FreezeEntityPosition
local SetEntityRotation <const> = SetEntityRotation
local SetEntityCoords <const> = SetEntityCoords
local SetResourceKvp <const> = SetResourceKvp
local cookie

function Dr.Init()
    Dr.ValidateConfig()
    Dr.Zones.call_coke.label = Lang.make_a_call

    Wait(1000)

    local plants_data = GetResourceKvpString("weed_plants")
    plants_data = plants_data and json.decode(plants_data) or {}
    Dr.weed_plants = plants_data

    local meth_data = GetResourceKvpString("meth_tables")
    meth_data = meth_data and json.decode(meth_data) or {}
    Dr.meth_tables = meth_data

    Dr.last_air_drop = tonumber(GetResourceKvpString("last_air_drop")) or 0

    Dr:RefreshPlants()
    Dr:RefreshTables()

    Server.ready = true

    Dr.CalculatePlayers()

    while true do
        Wait(20000)
        Dr:ProcessMeth()
        Dr:ProcessWeed()
    end
end

function Dr.CalculatePlayers()
    if cookie then
        RemoveEventHandler(cookie)
        cookie = nil
    end
    if GetNumPlayerIndices() == 0 then
        cookie = AddEventHandler('plouffe_lib:setGroup', function(playerId)
            RemoveEventHandler(cookie)
            cookie = nil
            Wait(1000)
            Dr:RefreshPlants()
            Dr:RefreshTables()
            Dr.CalculatePlayers()
        end)
    else
        cookie = AddEventHandler('playerDropped', function(reason)
            if GetNumPlayerIndices() == 0 then
                Dr.CalculatePlayers()
            end
        end)
    end
end

function Dr:GetData(key)
    local retval = {auth = key}

    for k,v in pairs(self) do
        if type(v) ~= "function" then
            retval[k] = v
        end
    end

    return retval
end

function Dr.ValidateConfig()
    Dr.weed_growth_time = tonumber(GetConvar("plouffe_drugs:weed_growth_time", ""))
    Dr.weed_item = GetConvar("plouffe_drugs:weed_item", "")
    Dr.meth_item = GetConvar("plouffe_drugs:meth_item", "")
    Dr.meth_amount = tonumber(GetConvar("plouffe_drugs:meth_amount", ""))
    Dr.drop_interval = tonumber(GetConvar("plouffe_drugs:drop_interval", ""))
    Dr.coke_item = GetConvar("plouffe_drugs:coke_item", "")
    Dr.coke_amount = tonumber(GetConvar("plouffe_drugs:coke_amount", ""))

    Dr.AllowAdvancedData = GetConvar("plouffe_drugs:allow_advanced_data", "")
    Dr.AllowAdvancedData = Dr.AllowAdvancedData == "true" and true or nil

    Dr.seed_item = GetConvar("plouffe_drugs:seed_item", "")
    Dr.seed_item = Dr.seed_item ~= "" and Dr.seed_item or nil

    local data = json.decode(GetConvar("plouffe_drugs:plants_items", ""))
    if data and type(data) == "table" then
        Dr.plants_items = {}

        for k,v in pairs(data) do
            local one, two = v:find(":")
            Dr.plants_items[v:sub(0,one - 1)] = tonumber(v:sub(one + 1,v:len()))
        end
        data = nil
    end

    data = json.decode(GetConvar("plouffe_drugs:water_items", ""))
    if data and type(data) == "table" then
        Dr.water_items = {}

        for k,v in pairs(data) do
            local one, two = v:find(":")
            Dr.water_items[v:sub(0,one - 1)] = tonumber(v:sub(one + 1,v:len()))
        end
        data = nil
    end

    data = json.decode(GetConvar("plouffe_drugs:fert_items", ""))
    if data and type(data) == "table" then
        Dr.fert_items = {}

        for k,v in pairs(data) do
            local one, two = v:find(":")
            Dr.fert_items[v:sub(0,one - 1)] = tonumber(v:sub(one + 1,v:len()))
        end
        data = nil
    end

    data = json.decode(GetConvar("plouffe_drugs:table_items", ""))
    if data and type(data) == "table" then
        Dr.table_items = {}

        for k,v in pairs(data) do
            local one, two = v:find(":")
            Dr.table_items[v:sub(0,one - 1)] = tonumber(v:sub(one + 1,v:len()))
        end
        data = nil
    end

    data = json.decode(GetConvar("plouffe_drugs:airdrop_items", ""))
    if data and type(data) == "table" then
        Dr.airdrop_items = {}

        for k,v in pairs(data) do
            local one, two = v:find(":")
            Dr.airdrop_items[v:sub(0,one - 1)] = tonumber(v:sub(one + 1,v:len()))
        end
        data = nil
    end

    if not Dr.airdrop_items or type(Dr.airdrop_items) ~= "table" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'airdrop_items' convar. Refer to documentation")
        end
    elseif not Dr.plants_items or type(Dr.plants_items) ~= "table" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'plants_items' convar. Refer to documentation")
        end
    elseif not Dr.water_items or type(Dr.water_items) ~= "table" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'water_items' convar. Refer to documentation")
        end
    elseif not Dr.fert_items or type(Dr.fert_items) ~= "table" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'fert_items' convar. Refer to documentation")
        end
    elseif not Dr.table_items or type(Dr.table_items) ~= "table" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'table_items' convar. Refer to documentation")
        end
    elseif not Dr.weed_growth_time then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'weed_growth_time' convar. Refer to documentation")
        end
    elseif not Dr.weed_item or Dr.weed_item == "" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'weed_item' convar. Refer to documentation")
        end
    elseif not Dr.meth_item or Dr.meth_item == "" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'meth_item' convar. Refer to documentation")
        end
    elseif not Dr.meth_amount then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'meth_amount' convar. Refer to documentation")
        end
    elseif not Dr.drop_interval then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'drop_interval' convar. Refer to documentation")
        end
    elseif not Dr.coke_item or Dr.coke_item == "" then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'coke_item' convar. Refer to documentation")
        end
    elseif not Dr.coke_amount then
        while true do
            Wait(1000)
            print("^1 [ERROR] ^0 Invalid configuration, missing 'coke_amount' convar. Refer to documentation")
        end
    end

    Dr.drop_interval *= (60 * 60)
    Dr.weed_growth_time *= 60

    return true
end

function Dr.PlantWeed(position, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:plant_weed") then
        return
    end

    for k,v in pairs(Dr.Weed.blacklickzones) do
        if #(position.coords - v.coords) < v.distance then
            return
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
            return
        end
    end

    for k,v in pairs(Dr.weed_plants) do
        local entity = NetworkGetEntityFromNetworkId(k)
        if DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)

            if #(coords - position.coords) < 1 then
                return Utils:Notify(playerId, {
                    style = "error",
                    header = "Weed",
                    message = Lang.plant_to_close
                })
            end
        end
    end

    for k,v in pairs(Dr.plants_items) do
        local count = Inventory.Search(playerId, "count", k)
        Inventory.RemoveItem(playerId, k, v)
        if count < v then
            return false
        end
    end

    local pot = CreateObject("bkr_prop_weed_01_small_01c", position.coords.x, position.coords.y, position.coords.z, true, true)
    FreezeEntityPosition(pot, true)
    SetEntityRotation(pot, position.rotation.x, position.rotation.y, position.rotation.z)

    Wait(1000)
    local netId = NetworkGetNetworkIdFromEntity(pot)

    Dr.weed_plants[netId] = {
        water = 0,
        fert = 0,
        quality = 100,
        age = 0,
        sex = math.random(1,2) == 1 and "m" or "f",
        quality_reducer = math.random(1,5),
        requirement = {
            water = math.random(1,60),
            fert = math.random(1,60)
        },
        creation_time = os.time(),
        position = position,
        creator = Uniques.Get(playerId)
    }
end

function Dr:ProcessWeed()
    local time = os.time()
    local weed_stages = math.floor(self.weed_growth_time / 3)
    local tasks = {removes = {}, updates = {}}

    for k,v in pairs(self.weed_plants) do
        local time_age = time - v.creation_time
        local current_age = math.floor(time_age / weed_stages)

        if not v.isReady and (self.weed_growth_time - time_age) <= 0 then
            v.isReady = true
        end

        if v.age ~= current_age then
            local task, new_netId = self:UpdatePlantProp(k, current_age)

            if task == "delete" then
                table.insert(tasks.removes, k)
            elseif task == "update" then
                table.insert(tasks.updates, {index = k, new_netId = new_netId})
            end
        end

        v.fert = v.fert - 0.1 > 0 and v.fert - 0.1 or 0
        v.water = v.water - 0.1 > 0 and v.water - 0.1 or 0

        local reduce = (v.water < v.requirement.water and v.quality_reducer or 0) + (v.fert < v.requirement.fert and v.quality_reducer or 0)

        if reduce > 0 and v.quality > 0 then
            v.quality = v.quality - reduce > 0 and v.quality - reduce or 0
        end
    end

    if #tasks.removes > 0 then
        for k,v in pairs(tasks.removes) do
            self.weed_plants[v] = nil
        end
    end

    if #tasks.updates > 0 then
        for k,v in pairs(tasks.updates) do
            self.weed_plants[v.new_netId] = self.weed_plants[v.index]
            self.weed_plants[v.index] = nil
        end
    end

    SetResourceKvp("weed_plants", json.encode(self.weed_plants))
end

function Dr:UpdatePlantProp(netId, age)
    self.weed_plants[netId].age = age
    local entity = NetworkGetEntityFromNetworkId(netId)
    if age == 1 or age == 2 then
        local model = age == 1 and 'bkr_prop_weed_med_01a' or 'bkr_prop_weed_lrg_01a'
        local position = self.weed_plants[netId].position

        local pot = CreateObject(model, position.coords.x, position.coords.y, 0.0, true, true)

        Wait(100)
        if not DoesEntityExist(pot) then
            return netId
        end

        DeleteEntity(entity)
        FreezeEntityPosition(pot, true)
        SetEntityRotation(pot, position.rotation.x, position.rotation.y, position.rotation.z)
        SetEntityCoords(pot, position.coords.x, position.coords.y, position.coords.z)

        Wait(1000)

        return "update", NetworkGetNetworkIdFromEntity(pot)
    elseif age >= 10 then
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end

        return "delete", false
    end
end

function Dr:RefreshPlants()
    local data = {}
    local plantModels = {
        [`bkr_prop_weed_01_small_01c`] = true,
        [`bkr_prop_weed_med_01a`] = true,
        [`bkr_prop_weed_lrg_01a`] = true
    }

    for k,v in pairs(self.weed_plants) do
        local entity = NetworkGetEntityFromNetworkId(k)
        if DoesEntityExist(entity) and plantModels[GetEntityModel(entity)] then
            data[tonumber(k)] = v
        else
            local model = v.age == 0 and 'bkr_prop_weed_01_small_01c' or v.age == 1 and 'bkr_prop_weed_med_01a' or 'bkr_prop_weed_lrg_01a'
            local object = CreateObject(model, v.position.coords.x, v.position.coords.y, 0.0, true, true)
            Wait(1000)
            if DoesEntityExist(object) then
                local netId = NetworkGetNetworkIdFromEntity(object)
                FreezeEntityPosition(object, true)
                SetEntityRotation(object, v.position.rotation.x, v.position.rotation.y, v.position.rotation.z)
                SetEntityCoords(object, v.position.coords.x, v.position.coords.y, v.position.coords.z)
                data[netId] = v
            end
        end
    end

    self.weed_plants = data
end

function Dr.AddWater(netId, item, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:water_weed") then
        return
    end

    if not Dr.weed_plants[netId] or not Dr.water_items[item] then
        return
    end

    Dr.weed_plants[netId].water = Dr.weed_plants[netId].water + Dr.water_items[item] < 100 and Dr.weed_plants[netId].water + Dr.water_items[item] or 100
end

function Dr.AddFert(netId, item, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:fert_weed") then
        return
    end

    if not Dr.weed_plants[netId] or not Dr.fert_items[item] then
        return
    end

    Dr.weed_plants[netId].fert = Dr.weed_plants[netId].fert + Dr.fert_items[item] < 100 and Dr.weed_plants[netId].fert + Dr.fert_items[item] or 100
end

function Dr.DestroyPlant(netId, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:destroy_weed") then
        return
    end

    if not Dr.weed_plants[netId] then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    Dr.weed_plants[netId] = nil
end

function Dr.HarvestWeed(netId, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:harvest_weed") then
        return
    end

    if not Dr.weed_plants[netId] then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    Inventory.AddItem(playerId, Dr.weed_item, Dr.weed_plants[netId].quality)

    if Dr.seed_item and Dr.weed_plants[netId].sex == "f" then
        Inventory.AddItem(playerId, Dr.seed_item, 1)
    end

    Dr.weed_plants[netId] = nil
end

Callback:RegisterServerCallback("plouffe_drugs:loadPlayer", function(playerId, cb)
    local registred, key = Auth:Register(playerId)

    if not registred then
        return DropPlayer(" "), cb()
    end

    while not Server.ready do
        Wait(100)
    end

    cb(Dr:GetData(key))
end)

Callback:RegisterServerCallback("plouffe_drugs:get_plant_data", function(playerId, cb, netId, auth)
    if not Auth:Validate(playerId, auth) or not Auth:Events(playerId,"plouffe_drugs:get_plant_data") then
        return
    end

    cb(Dr.weed_plants[netId])
end)

Callback:RegisterServerCallback("plouffe_drugs:get_advanced_plant_data", function(playerId, cb, netId, auth)
    if not Auth:Validate(playerId, auth) or not Auth:Events(playerId,"plouffe_drugs:get_plant_data") then
        return
    end

    local data = {}
    local date = os.date("!*t", os.difftime(os.time(),Dr.weed_plants[netId].creation_time))
    local date2 = os.date("!*t", os.difftime(Dr.weed_growth_time, 0))

    date.day -= 1
    date2.day -= 1
    data.time_passed = ("%s : Days, %s : Hours, %s : Minutes, %s : Seconds"):format(date.day, date.hour, date.min, date.sec)
    data.growth_time = ("%s : Days, %s : Hours, %s : Minutes, %s : Seconds"):format(date2.day, date2.hour, date2.min, date2.sec)

    cb(Dr.weed_plants[netId], data)
end)

function Dr.PlaceTable(position, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:place_table") then
        return
    end

    for k,v in pairs(Dr.Meth.blacklickzones) do
        if #(position.coords - v.coords) < v.distance then
            return
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
            return
        end
    end

    for k,v in pairs(Dr.meth_tables) do
        local entity = NetworkGetEntityFromNetworkId(k)
        if DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)

            if #(coords - position.coords) < 1 then
                return Utils:Notify(playerId, {
                    style = "error",
                    header = "Weed",
                    message = Lang.table_to_clode
                })
            end
        end
    end

    for k,v in pairs(Dr.table_items) do
        local count = Inventory.Search(playerId, "count", k)
        Inventory.RemoveItem(playerId, k, v)
        if count < v then
            return false
        end
    end

    local object = CreateObject("v_ret_ml_tableb", position.coords.x, position.coords.y, position.coords.z, true, true)
    FreezeEntityPosition(object, true)
    SetEntityRotation(object, position.rotation.x, position.rotation.y, position.rotation.z)

    Wait(1000)
    local netId = NetworkGetNetworkIdFromEntity(object)

    Entity(object).state:set("table_smoke", false, false)
    Entity(object).state:set("table_fire", false, false)
    Entity(object).state:set("table_inuse", false, false)

    Dr.meth_tables[netId] = {
        durability = 100,
        creation_time = os.time(),
        position = position,
        creator = Uniques.Get(playerId)
    }
end

function Dr:RefreshTables()
    local data = {}
    local model = `v_ret_ml_tableb`
    for k,v in pairs(self.meth_tables) do
        local entity = NetworkGetEntityFromNetworkId(k)
        if DoesEntityExist(entity) and GetEntityModel(entity) == model then
            data[tonumber(k)] = v
        else
            local object = CreateObject(model, v.position.coords.x, v.position.coords.y, 0.0, true, true)
            Wait(1000)
            if DoesEntityExist(object) then
                local netId = NetworkGetNetworkIdFromEntity(object)

                Entity(object).state:set("table_smoke", false, false)
                Entity(object).state:set("table_fire", false, false)
                Entity(object).state:set("table_inuse", false, false)

                FreezeEntityPosition(object, true)
                SetEntityRotation(object, v.position.rotation.x, v.position.rotation.y, v.position.rotation.z)
                SetEntityCoords(object, v.position.coords.x, v.position.coords.y, v.position.coords.z + 0.5)

                data[netId] = v
            end
        end
    end

    self.meth_tables = data
end

Callback:RegisterServerCallback("plouffe_drugs:get_table_data", function(playerId, cb, netId, auth)
    if not Auth:Validate(playerId, auth) or not Auth:Events(playerId,"plouffe_drugs:get_table_data") then
        return
    end

    cb(Dr.meth_tables[netId])
end)

function Dr.FinishedCooking(netId, succes, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:finished_cooking") then
        return
    end

    if not Dr.meth_tables[netId] then
        return
    end

    if not succes then
        Dr.meth_tables[netId].durability -= 5
        if Dr.meth_tables[netId].durability < 1 then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end

            Dr.meth_tables[netId] = nil
        end

        return
    end

    Inventory.AddItem(playerId, Dr.meth_item, Dr.meth_amount)
end

function Dr:ProcessMeth()
    local removes = {}

    for k,v in pairs(self.meth_tables) do
        v.durability -= 0.1
        if v.durability < 1 then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end

            removes[k] = true
        end
    end

    for k,v in pairs(removes) do
        self.meth_tables[k] = nil
    end

    SetResourceKvp("meth_tables", json.encode(self.meth_tables))
end

function Dr.DestroyTable(netId, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:destroy_meth") then
        return
    end

    if not Dr.meth_tables[netId] then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    Dr.meth_tables[netId] = nil
end

function Dr.RequestAirDrop(playerId)
    if Dr.active_air_drop or os.time() - Dr.last_air_drop < Dr.drop_interval then
        return false, Lang.no_air_drop
    end

    for k,v in pairs(Dr.airdrop_items) do
        local count = Inventory.Search(playerId, "count", k)
        Inventory.RemoveItem(playerId, k, v)

        if count < v then
            return false, Lang.missing_something
        end
    end

    Dr.last_air_drop = os.time()
    SetResourceKvp("last_air_drop", Dr.last_air_drop)

    Dr.GenerateAirDropData()
    Dr:HandleChopper()

    return Dr.active_air_drop
end

function Dr.GenerateAirDropData()
    local coords = Dr.Zones.call_coke.coords
    Dr.active_air_drop = {destination = Dr.barrel_spawns[math.random(1,#Dr.barrel_spawns)] }

    Dr.active_air_drop.vehicle = CreateVehicle(`cargobob`,coords.x, coords.y, coords.z + 100, 0.0, true, true)
    Wait(100)
    FreezeEntityPosition(Dr.active_air_drop.vehicle, true)
    Dr.active_air_drop.ped = CreatePedInsideVehicle(Dr.active_air_drop.vehicle, 1, `ig_marnie`, -1, true, true)
    Wait(100)
    Dr.active_air_drop.barrel = CreateObject(`prop_barrel_02a`, coords.x, coords.y, coords.z + 95, true, true)
    FreezeEntityPosition(Dr.active_air_drop.barrel, true)
    Wait(100)
    Dr.active_air_drop.rope = CreateObject(`p_cs_15m_rope_s`, coords.x, coords.y, coords.z + 95, true, true)
    FreezeEntityPosition(Dr.active_air_drop.rope, true)
    Wait(100)

    Dr.active_air_drop.rope_net = NetworkGetNetworkIdFromEntity(Dr.active_air_drop.rope)
    Dr.active_air_drop.barrel_net = NetworkGetNetworkIdFromEntity(Dr.active_air_drop.barrel)
    Dr.active_air_drop.vehicle_net = NetworkGetNetworkIdFromEntity(Dr.active_air_drop.vehicle)
    Dr.active_air_drop.ped_net = NetworkGetNetworkIdFromEntity(Dr.active_air_drop.ped)

    GlobalState.active_air_drop = Dr.active_air_drop
end

function Dr:HandleChopper()
    TriggerEvent("plouffe_drugs:on_airdrop")

    CreateThread(function ()
        local init_time = os.time()

        while #(GetEntityCoords(self.active_air_drop.vehicle) - self.active_air_drop.destination) > 100 and os.time() - init_time < (60 * 20) do
            Wait(1000)
        end

        if #(GetEntityCoords(self.active_air_drop.vehicle) - self.active_air_drop.destination) > 100 then
            self.ClearAirDropProps()
            self.active_air_drop = nil
            GlobalState.active_air_drop = nil

            return
        end

        ClearPedTasks(self.active_air_drop.ped)
        Entity(self.active_air_drop.barrel).state:set("airdrop_smoke", true, true)
        Wait(100)
        if DoesEntityExist(self.active_air_drop.rope) then
            DeleteEntity(self.active_air_drop.rope)
        end

        init_time = os.time()

        while self.active_air_drop and os.time() - init_time < (60 * 30) do
            Wait(1000)
        end

        self.ClearAirDropProps()
        GlobalState.active_air_drop = nil
    end)
end

function Dr.ClearAirDropProps()
    if not Dr.active_air_drop then
        return
    end
    if DoesEntityExist(Dr.active_air_drop.vehicle) then
        DeleteEntity(Dr.active_air_drop.vehicle)
    end
    if DoesEntityExist(Dr.active_air_drop.ped) then
        DeleteEntity(Dr.active_air_drop.ped)
    end
    if DoesEntityExist(Dr.active_air_drop.barrel) then
        DeleteEntity(Dr.active_air_drop.barrel)
    end
    if DoesEntityExist(Dr.active_air_drop.rope) then
        DeleteEntity(Dr.active_air_drop.rope)
    end
end

function Dr.LootBarrel(netId, auth)
    local playerId = source

    if not Auth:Validate(playerId,auth) or not Auth:Events(playerId,"plouffe_drugs:destroy_meth") then
        return
    end

    if not Dr.active_air_drop or Dr.active_air_drop.barrel_net ~= netId then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        return
    end

    local pedCoords = GetEntityCoords(GetPlayerPed(playerId))
    local entityCoords = GetEntityCoords(entity)

    if #(pedCoords - entityCoords) > 15 then
        return
    end

    Dr.ClearAirDropProps()

    Inventory.AddItem(playerId, Dr.coke_item, Dr.coke_amount)
end

Callback:RegisterServerCallback("plouffe_drugs:generate_plane_data", function(playerId, cb, auth)
    if not Auth:Validate(playerId, auth) or not Auth:Events(playerId,"plouffe_drugs:generate_plane_data") then
        return
    end

    cb(Dr.RequestAirDrop(playerId))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == "plouffe_drugs" then
        for k,v in pairs(Dr.weed_plants) do
            local entity = NetworkGetEntityFromNetworkId(k)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end

        for k,v in pairs(Dr.meth_tables) do
            local entity = NetworkGetEntityFromNetworkId(k)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end

        Dr.ClearAirDropProps()
    end
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
	if eventData.secondsRemaining == 60 then
		SetTimeout(50000, function()
            SetResourceKvp("weed_plants", json.encode(Dr.weed_plants))
            SetResourceKvp("meth_tables", json.encode(Dr.meth_tables))
		end)
	end
end)

RegisterCommand("savedrugs", function()
    SetResourceKvp("weed_plants", json.encode(Dr.weed_plants))
    SetResourceKvp("meth_tables", json.encode(Dr.meth_tables))
    print("Saved")
end, true)