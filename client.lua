--[[
Auteur: olinux
Version: 2.0
Date: 2024-12-19
Description: Script pour gérer les patrouilles de police (à pied et en voiture) et les interactions des policiers avec les joueurs dans FiveM.
]]

-- Variables de configuration
local policeModels = { GetHashKey("s_m_y_cop_01"), GetHashKey("s_f_y_cop_01") }
local swatModels = { GetHashKey("s_m_y_swat_01") }
local policeCars = { "police", "police2", "police3" }
local swatCars = { "riot", "fbi2" }

local footPatrolLocations = {
    { x = 453.151642, y = -990.118652, z = 30.678344, heading = 223.937012 },
    -- Ajoutez d'autres emplacements pour patrouilles à pied ici
}
local carPatrolLocations = {
    { x = 463.582428, y = -1014.712098, z = 28.066650, heading = 82.204728 },
    -- Ajoutez d'autres emplacements en ville ici
}

local footPatrols, maxFootPatrols = 0, 3
local carPatrols, maxCarPatrols = 0, 10
local bousculadeCounts = {}

-- Préchargement des modèles
for _, model in ipairs(policeModels) do
    RequestModel(model)
end
for _, model in ipairs(swatModels) do
    RequestModel(model)
end
for _, car in ipairs(policeCars) do
    RequestModel(GetHashKey(car))
end
for _, car in ipairs(swatCars) do
    RequestModel(GetHashKey(car))
end

-- Fonction simulée pour obtenir les véhicules possédés par un joueur
local function GetOwnedVehicles(player)
    return { { plate = "ABC123" }, { plate = "XYZ789" } }
end

-- Fonction pour créer un blip sur la carte
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

-- Fonction utilitaire pour vérifier si un ped est un policier
local function IsPedPolice(ped)
    local pedModel = GetEntityModel(ped)
    for _, model in ipairs(policeModels) do
        if pedModel == model then return true end
    end
    return false
end

-- Fonction pour désactiver les actions agressives de la police
local function disablePoliceAggression(policePed)
    SetPedFleeAttributes(policePed, 0, false)
    SetPedCombatAttributes(policePed, 17, true)
    SetPedSeeingRange(policePed, 0.0)
    SetPedHearingRange(policePed, 0.0)
    SetPedAlertness(policePed, 0)
    SetPedKeepTask(policePed, true)
end

-- Fonction pour obtenir les peds à proximité
local function GetNearbyPeds(coords, radius)
    local peds = {}
    local handle, ped = FindFirstPed()
    local success

    repeat
        local pedCoords = GetEntityCoords(ped)
        if #(coords - pedCoords) <= radius then table.insert(peds, ped) end
        success, ped = FindNextPed(handle)
    until not success

    EndFindPed(handle)
    return peds
end

-- Fonction pour obtenir les policiers à proximité
local function GetNearbyPolicePeds(coords, radius)
    local policePeds = {}
    local peds = GetNearbyPeds(coords, radius)

    for _, ped in ipairs(peds) do
        if IsPedPolice(ped) then table.insert(policePeds, ped) end
    end

    return policePeds
end

-- Fonction utilitaire pour vérifier si un véhicule est possédé par le joueur
local function IsVehicleOwnedByPlayer(vehicle)
    local player = GetPlayerFromServerId(NetworkGetPlayerIndexFromPed(vehicle))
    if player then
        local vehiclePlate = GetVehicleNumberPlateText(vehicle)
        local ownedVehicles = GetOwnedVehicles(player)
        for _, ownedVehicle in ipairs(ownedVehicles) do
            if ownedVehicle.plate == vehiclePlate then
                return true
            end
        end
    end
    return false -- Si le véhicule n'est pas trouvé dans la liste des véhicules possédés
end

-- Fonction pour envoyer un joueur en prison pour vol de voiture
local function sendToPrisonForTheft(playerPed)
    SetEntityCoords(playerPed, 1690.0, 2605.0, 45.5) -- Coordonnées de la prison
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = 0 -- Réinitialiser le compteur de bousculades
end

-- Fonction pour arrêter un joueur par un policier
local function arrestPlayerByPolice(playerPed, policePed)
    if IsEntityDead(playerPed) then return end

    -- Désactiver l'agression de tous les policiers à proximité
    local playerCoords = GetEntityCoords(playerPed)
    local policePeds = GetNearbyPolicePeds(playerCoords, 50.0) -- Rayon de 50 unités

    for _, policePed in ipairs(policePeds) do
        disablePoliceAggression(policePed)
        ClearPedTasksImmediately(policePed) -- Arrêter les tirs des policiers
    end

    TaskSetBlockingOfNonTemporaryEvents(playerPed, true)
    TaskHandsUp(playerPed, 5000, playerPed, -1, true)
    Citizen.Wait(5000)
    TaskEnterVehicle(playerPed, GetVehiclePedIsIn(playerPed, true), 20000, 0, 1.0, 1, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous êtes en état d\'arrestation!' } })
    Citizen.Wait(10000)
    -- Appeler la fonction pour envoyer le joueur en prison après l'arrestation
    sendToPrisonForTheft(playerPed)
end

-- Fonction pour gérer les bousculades
local function handleBousculade(playerPed, policePed)
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = (bousculadeCounts[playerId] or 0) + 1
    print("Bousculade count for player " .. playerId .. ": " .. bousculadeCounts[playerId])

    -- Annonce de la bousculade au joueur
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous avez bousculé un policier!' } })

    disablePoliceAggression(policePed)

    if bousculadeCounts[playerId] >= 3 then
        print("Player " .. playerId .. " has bousculé a police officer 3 times. Arresting player.")
        arrestPlayerByPolice(playerPed, policePed)
    end
end

-- Fonction pour tuer un joueur
local function killPlayer(playerPed)
    SetEntityHealth(playerPed, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous avez tué un policier et vous êtes abattu!' } })
end

-- Fonction pour faire intervenir le SWAT en cas de meurtre de policier
local function callSWAT()
    print("SWAT called")  -- Message de débogage
    for _, loc in ipairs(carPatrolLocations) do
        local swatModel = swatModels[math.random(#swatModels)]
        local swatCar = GetHashKey(swatCars[math.random(#swatCars)])

        while not HasModelLoaded(swatModel) or not HasModelLoaded(swatCar) do
            Citizen.Wait(0)
        end

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

-- Fonction pour contrôler les PNJ et les joueurs
local function performRandomCheck(ped)
    if IsEntityDead(ped) then return end

    if math.random(1, 100) <= 20 then -- 20% de chance de contrôle
        if IsPedInAnyVehicle(ped, false) then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        end
        TaskStandStill(ped, 5000)

        if IsPedAPlayer(ped) then
            TriggerEvent('chat:addMessage', { args = { 'Police', 'Contrôle de police sur vous en cours...' } })
        end

        Citizen.Wait(5000) -- Attendre pendant le contrôle

        if HasPedGotWeapon(ped, GetHashKey("WEAPON_PISTOL"), false) then
            TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous êtes en possession d\'armes illégales!' } })
            arrestPlayerByPolice(ped, policePed)
        end
    end
end

-- Fonction pour initier la poursuite de police
local function initiatePoliceChase(playerPed)
    print("Poursuite de police initiée pour le vol de véhicule.")
    Citizen.Wait(10000) -- Attendre 10 secondes pour simuler la poursuite
    -- Trouver un policier à proximité pour arrêter le joueur
    local playerCoords = GetEntityCoords(playerPed)
    local policePeds = GetNearbyPolicePeds(playerCoords, 50.0) -- Rayon de 50 unités
    if #policePeds > 0 then
        arrestPlayerByPolice(playerPed, policePeds[1])
    else
        print("Aucun policier à proximité pour arrêter le joueur.")
    end
end

-- Fonction pour gérer les interactions de la police en fonction de l'infraction
local function handlePoliceInteraction(playerPed, targetPed)
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = bousculadeCounts[playerId] or 0

    if IsEntityDead(targetPed) then
        print("Target ped is dead")  -- Message de débogage
        if IsPedPolice(targetPed) then
            print("Target ped is a police officer")  -- Message de débogage
            callSWAT()  -- Appel du SWAT en cas de meurtre de policier
        end
        killPlayer(playerPed)
    elseif IsPedInMeleeCombat(playerPed) then
        if IsPedPolice(targetPed) then
            handleBousculade(playerPed, targetPed)
        end
    elseif HasPedGotWeapon(playerPed, GetHashKey("WEAPON_PISTOL"), false) then
        arrestPlayerByPolice(playerPed, targetPed)
    elseif IsPedInAnyVehicle(playerPed, false) and not IsVehicleOwnedByPlayer(GetVehiclePedIsIn(playerPed, false)) then
        initiatePoliceChase(playerPed)
    else
        performRandomCheck(playerPed)
    end
end

-- Fonction pour créer une patrouille
local function createPatrol(patrolType)
    if patrolType == "foot" and footPatrols >= maxFootPatrols then
        print("Nombre maximum de patrouilles à pied atteint")
        return
    elseif patrolType == "car" and carPatrols >= maxCarPatrols then
        print("Nombre maximum de patrouilles en voiture atteint")
        return
    end

    local loc = (patrolType == "foot" and footPatrolLocations or carPatrolLocations)[math.random(#(patrolType == "foot" and footPatrolLocations or carPatrolLocations))]
    local model1 = policeModels[math.random(#policeModels)]
    local model2 = policeModels[math.random(#policeModels)]
    local carModel = patrolType == "car" and GetHashKey(policeCars[math.random(#policeCars)]) or nil

    while not HasModelLoaded(model1) or not HasModelLoaded(model2) or (carModel and not HasModelLoaded(carModel)) do
        Citizen.Wait(0)
    end

    local ped1, ped2, vehicle
    if patrolType == "foot" then
        ped1 = CreatePed(4, model1, loc.x, loc.y, loc.z, loc.heading or 0.0, true, true)
        ped2 = CreatePed(4, model2, loc.x, loc.y, loc.z, loc.heading or 0.0, true, true)
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
            createBlip(ped1, 1, 3, "Police à pied")
            createBlip(ped2, 1, 3, "Police à pied")
        else
            TaskVehicleDriveWander(ped1, vehicle, 20.0, 786603)
            createBlip(vehicle, 56, 3, "Patrouille de police")
        end
        print("Patrouille " .. patrolType .. " créée")
    else
        print("Échec de la création de la patrouille " .. patrolType)
    end

    if patrolType == "foot" then
        footPatrols = footPatrols + 1
    else
        carPatrols = carPatrols + 1
    end

    Citizen.SetTimeout(600000, function()
        if DoesEntityExist(ped1) then DeleteEntity(ped1) end
        if DoesEntityExist(ped2) then DeleteEntity(ped2) end
        if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        if patrolType == "foot" then
            footPatrols = footPatrols - 1
        else
            carPatrols = carPatrols - 1
        end
    end)
end

-- Threads pour créer et gérer les patrouilles
Citizen.CreateThread(function()
    while true do
        createPatrol("foot")
        Citizen.Wait(60000) -- Une minute d'intervalle entre chaque patrouille à pied
    end
end)

Citizen.CreateThread(function()
    while true do
        createPatrol("car")
        Citizen.Wait(30000) -- Vérification toutes les 30 secondes pour renouveler les patrouilles en voiture
    end
end)

-- Thread pour gérer les infractions graves et la réaction des policiers
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        local playerPed = PlayerPedId()
        local targetPed = GetMeleeTargetForPed(playerPed) or GetEntityPlayerIsFreeAimingAt(PlayerId())
        
        if targetPed and IsPedPolice(targetPed) then
            handlePoliceInteraction(playerPed, targetPed)
        elseif IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if not IsVehicleOwnedByPlayer(vehicle) then
                initiatePoliceChase(playerPed)
            end
        end
    end
end)