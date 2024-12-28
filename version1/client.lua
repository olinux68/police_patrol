--[[
Author: olinux
Version: 2.0
Date: 2024-12-20
Description: Script to manage police patrols (on foot and in vehicles) and police interactions with players in FiveM.
]]

-- Configuration variables
local policeModels = { GetHashKey("s_m_y_cop_01"), GetHashKey("s_f_y_cop_01") }
local swatModels = { GetHashKey("s_m_y_swat_01") }
local policeCars = { "police", "police2", "police3" }
local swatCars = { "riot", "fbi2" }

local footPatrolLocations = {
    { x = 453.151642, y = -990.118652, z = 30.678344, heading = 223.937012 },
    -- Add more foot patrol locations here
}
local carPatrolLocations = {
    { x = 463.582428, y = -1014.712098, z = 28.066650, heading = 82.204728 },
    { x = 431.116486, y = -997.028564, z = 25.758300, heading = 172.913392 },
    { x = 421.529664, y = -1028.650512, z = 29.077636, heading = 2.834646 },
    -- Add more car patrol locations here
}

local footPatrols, maxFootPatrols = 0, 3
local carPatrols, maxCarPatrols = 0, 10
local bousculadeCounts, lastBousculadeTime = {}, {}

-- Preload models
for _, model in ipairs(policeModels) do RequestModel(model) end
for _, model in ipairs(swatModels) do RequestModel(model) end
for _, car in ipairs(policeCars) do RequestModel(GetHashKey(car)) end
for _, car in ipairs(swatCars) do RequestModel(GetHashKey(car)) end

-- Simulated function to get vehicles owned by a player
local function GetOwnedVehicles(player) return { { plate = "ABC123" }, { plate = "XYZ789" } } end

-- Function to create a blip on the map
local function createBlip(entity, blipSprite, blipColor, blipName)
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, blipSprite)
    SetBlipColour(blip, blipColor)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipName)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- Utility function to check if a ped is a police officer
local function IsPedPolice(ped)
    local pedModel = GetEntityModel(ped)
    for _, model in ipairs(policeModels) do if pedModel == model then return true end end
    return false
end

-- Function to disable aggressive actions of the police
local function disablePoliceAggression(policePed)
    SetPedFleeAttributes(policePed, 0, false)
    SetPedCombatAttributes(policePed, 17, true)
    SetPedSeeingRange(policePed, 0.0)
    SetPedHearingRange(policePed, 0.0)
    SetPedAlertness(policePed, 0)
    SetPedKeepTask(policePed, true)
end

-- Function to get nearby peds
local function GetNearbyPeds(coords, radius)
    local peds, handle, ped = {}, FindFirstPed()
    local success
    repeat
        local pedCoords = GetEntityCoords(ped)
        if #(coords - pedCoords) <= radius then table.insert(peds, ped) end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)
    return peds
end

-- Function to get nearby police officers
local function GetNearbyPolicePeds(coords, radius)
    local policePeds = {}
    for _, ped in ipairs(GetNearbyPeds(coords, radius)) do
        if IsPedPolice(ped) then table.insert(policePeds, ped) end
    end
    return policePeds
end

-- Utility function to check if a vehicle is owned by the player
local function IsVehicleOwnedByPlayer(vehicle)
    local player = GetPlayerFromServerId(NetworkGetPlayerIndexFromPed(vehicle))
    if player then
        local vehiclePlate = GetVehicleNumberPlateText(vehicle)
        for _, ownedVehicle in ipairs(GetOwnedVehicles(player)) do
            if ownedVehicle.plate == vehiclePlate then return true end
        end
    end
    return false
end

-- Function to send a player to prison for car theft
local function sendToPrisonForTheft(playerPed)
    SetEntityCoords(playerPed, 1690.0, 2605.0, 45.5) -- Prison coordinates
    bousculadeCounts[GetPlayerServerId(NetworkGetEntityOwner(playerPed))] = 0 -- Reset bousculade count
end

-- Function to arrest a player by a police officer
local function arrestPlayerByPolice(playerPed, policePed)
    if IsEntityDead(playerPed) then return end
    for _, policePed in ipairs(GetNearbyPolicePeds(GetEntityCoords(playerPed), 50.0)) do
        disablePoliceAggression(policePed)
        ClearPedTasksImmediately(policePed) -- Stop police from shooting
    end
    TaskSetBlockingOfNonTemporaryEvents(playerPed, true)
    TaskHandsUp(playerPed, 5000, playerPed, -1, true)
    Citizen.Wait(5000)
    TaskEnterVehicle(playerPed, GetVehiclePedIsIn(playerPed, true), 20000, 0, 1.0, 1, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'You are under arrest!' } })
    Citizen.Wait(10000)
    sendToPrisonForTheft(playerPed)
end

-- Function to handle bousculades
local function handleBousculade(playerPed, policePed)
    local playerId, currentTime = GetPlayerServerId(NetworkGetEntityOwner(playerPed)), GetGameTimer()
    if not lastBousculadeTime[playerId] or currentTime - lastBousculadeTime[playerId] > 5000 then
        bousculadeCounts[playerId] = (bousculadeCounts[playerId] or 0) + 1
        lastBousculadeTime[playerId] = currentTime
        print("Bousculade count for player " .. playerId .. ": " .. bousculadeCounts[playerId])
        TriggerEvent('chat:addMessage', { args = { 'Police', 'You have pushed a police officer!' } })
        disablePoliceAggression(policePed)
        if bousculadeCounts[playerId] >= 3 then
            print("Player " .. playerId .. " has pushed a police officer 3 times. Arresting player.")
            arrestPlayerByPolice(playerPed, policePed)
        end
    end
end

-- Function to kill a player
local function killPlayer(playerPed)
    SetEntityHealth(playerPed, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'You killed a police officer and have been shot!' } })
end

-- Function to call SWAT in case of police murder
local function callSWAT()
    print("SWAT called")  -- Debug message
    for _, loc in ipairs(carPatrolLocations) do
        local swatModel, swatCar = swatModels[math.random(#swatModels)], GetHashKey(swatCars[math.random(#swatCars)])
        while not HasModelLoaded(swatModel) or not HasModelLoaded(swatCar) do Citizen.Wait(0) end
        local vehicle = CreateVehicle(swatCar, loc.x, loc.y, loc.z, loc.heading or 0.0, true, false)
        local ped = CreatePedInsideVehicle(vehicle, 4, swatModel, -1, true, false)
        GiveWeaponToPed(ped, GetHashKey("WEAPON_CARBINERIFLE"), 1000, false, true)
        SetPedCombatAbility(ped, 2)
        SetPedCombatMovement(ped, 2)
        SetPedCombatRange(ped, 2)
        SetPedAccuracy(ped, 100)
        TaskVehicleDriveToCoordLongrange(ped, vehicle, loc.x, loc.y, loc.z, 20.0, 786603, 5.0)
        TaskCombatHatedTargetsAroundPed(ped, 100.0)
        Citizen.SetTimeout(600000, function()
            if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end)
    end
end

-- Function to perform random checks on NPCs and players
local function performRandomCheck(ped)
    if IsEntityDead(ped) then return end
    if math.random(1, 100) <= 20 then -- 20% chance of a check
        if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0) end
        TaskStandStill(ped, 5000)
        if IsPedAPlayer(ped) then TriggerEvent('chat:addMessage', { args = { 'Police', 'Police check in progress...' } }) end
        Citizen.Wait(5000) -- Wait during the check
        if HasPedGotWeapon(ped, GetHashKey("WEAPON_PISTOL"), false) then
            TriggerEvent('chat:addMessage', { args = { 'Police', 'You are in possession of illegal weapons!' } })
            arrestPlayerByPolice(ped, policePed)
        end
    end
end

-- Function to initiate a police chase
local function initiatePoliceChase(playerPed)
    print("Police chase initiated for vehicle theft.")
    Citizen.Wait(10000) -- Wait 10 seconds to simulate the chase
    local policePeds = GetNearbyPolicePeds(GetEntityCoords(playerPed), 50.0) -- 50 unit radius
    if #policePeds > 0 then arrestPlayerByPolice(playerPed, policePeds[1])
    else print("No police officers nearby to arrest the player.") end
end

-- Function to handle police interactions based on the offense
local function handlePoliceInteraction(playerPed, targetPed)
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = bousculadeCounts[playerId] or 0
    if IsEntityDead(targetPed) then
        print("Target ped is dead")  -- Debug message
        if IsPedPolice(targetPed) then
            print("Target ped is a police officer")  -- Debug message
            callSWAT()  -- Call SWAT in case of police murder
        end
        killPlayer(playerPed)
    elseif IsPedInMeleeCombat(playerPed) then
        if IsPedPolice(targetPed) then handleBousculade(playerPed, targetPed) end
    elseif HasPedGotWeapon(playerPed, GetHashKey("WEAPON_PISTOL"), false) then
        arrestPlayerByPolice(playerPed, targetPed)
    elseif IsPedInAnyVehicle(playerPed, false) and not IsVehicleOwnedByPlayer(GetVehiclePedIsIn(playerPed, false)) then
        initiatePoliceChase(playerPed)
    else performRandomCheck(playerPed) end
end

-- Function to create a patrol
local function createPatrol(patrolType)
    if (patrolType == "foot" and footPatrols >= maxFootPatrols) or (patrolType == "car" and carPatrols >= maxCarPatrols) then
        print("Maximum number of patrols reached for " .. patrolType)
        return
    end

    local loc = (patrolType == "foot" and footPatrolLocations or carPatrolLocations)[math.random(#(patrolType == "foot" and footPatrolLocations or carPatrolLocations))]
    local model1, model2 = policeModels[math.random(#policeModels)], policeModels[math.random(#policeModels)]
    local carModel = patrolType == "car" and GetHashKey(policeCars[math.random(#policeCars)]) or nil

    while not HasModelLoaded(model1) or not HasModelLoaded(model2) or (carModel and not HasModelLoaded(carModel)) do Citizen.Wait(0) end

    local ped1, ped2, vehicle
    if patrolType == "foot" then
        ped1 = CreatePed(4, model1, loc.x, loc.y, loc.z, loc.heading or 0.0, true, true)
        ped2 = CreatePed(4, model2, loc.x, loc.y, loc.z, loc.heading or 0.0, true, true)
        -- Ensure NPC visibility
        SetEntityVisible(ped1, true)
        SetEntityVisible(ped2, true)
        -- Additional visibility checks
        Citizen.Wait(1000)
        if not IsEntityVisible(ped1) then SetEntityVisible(ped1, true) end
        if not IsEntityVisible(ped2) then SetEntityVisible(ped2, true) end
    else
        vehicle = CreateVehicle(carModel, loc.x, loc.y, loc.z, loc.heading or 0.0, true, false)
        ped1 = CreatePedInsideVehicle(vehicle, 4, model1, -1, true, false)
        ped2 = CreatePedInsideVehicle(vehicle, 4, model2, 0, true, false)
    end

    if DoesEntityExist(ped1) and DoesEntityExist(ped2) then
        GiveWeaponToPed(ped1, GetHashKey("WEAPON_PISTOL"), 1000, false, true)
        GiveWeaponToPed(ped2, GetHashKey("WEAPON_PISTOL"), 1000, false, true)
        if patrolType == "foot" then
            TaskWanderStandard(ped1, 10.0, 10)
            TaskWanderStandard(ped2, 10.0, 10)
            createBlip(ped1, 1, 3, "Foot Patrol")
            createBlip(ped2, 1, 3, "Foot Patrol")
        else
            TaskVehicleDriveWander(ped1, vehicle, 20.0, 786603)
            createBlip(vehicle, 56, 3, "Police Patrol")
        end
        print("Patrol " .. patrolType .. " created")
    else
        print("Failed to create patrol " .. patrolType)
    end

    if patrolType == "foot" then footPatrols = footPatrols + 1 else carPatrols = carPatrols + 1 end

    Citizen.SetTimeout(600000, function()
        if DoesEntityExist(ped1) then DeleteEntity(ped1) end
        if DoesEntityExist(ped2) then DeleteEntity(ped2) end
        if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        if patrolType == "foot" then footPatrols = footPatrols - 1 else carPatrols = carPatrols - 1 end
    end)
end

-- Threads to create and manage patrols
Citizen.CreateThread(function()
    while true do
        createPatrol("foot")
        Citizen.Wait(60000) -- One minute interval between each foot patrol
    end
end)

Citizen.CreateThread(function()
    while true do
        createPatrol("car")
        Citizen.Wait(30000) -- Check every 30 seconds to renew car patrols
    end
end)

-- Thread to handle serious offenses and police reactions
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local policePeds = GetNearbyPolicePeds(playerCoords, 2.0) -- 2 unit radius to detect bousculades

        for _, policePed in ipairs(policePeds) do
            if IsPedPolice(policePed) and HasEntityCollidedWithAnything(policePed) then
                handleBousculade(playerPed, policePed)
            end
        end

        if IsPedInMeleeCombat(playerPed) then
            local targetPed = GetMeleeTargetForPed(playerPed)
            if targetPed and IsPedPolice(targetPed) then
                handlePoliceInteraction(playerPed, targetPed)
            end
        elseif IsPlayerFreeAiming(PlayerId()) and IsPedShooting(playerPed) then
            local _, targetPed = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if targetPed and IsPedPolice(targetPed) then
                handlePoliceInteraction(playerPed, targetPed)
            end
        elseif IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if not IsVehicleOwnedByPlayer(vehicle) then
                initiatePoliceChase(playerPed)
            end
        end
    end
end)