--[[
Auteur: olinux
Version: 2.0
Date: 2024-12-19
Description: Script pour gérer les patrouilles de police (à pied et en voiture) et les interactions des policiers avec les joueurs dans FiveM.
]]

-- Variables de configuration
local policeModels = {
    GetHashKey("s_m_y_cop_01"),
    GetHashKey("s_f_y_cop_01")
}
local swatModels = {
    GetHashKey("s_m_y_swat_01")
}
local policeCars = {"police", "police2", "police3"}
local swatCars = {"riot", "fbi2"}

local footPatrolLocations = {
    {x = 453.151642, y = -990.118652, z = 30.678344, heading = 223.937012},
    -- Ajoutez d'autres emplacements pour patrouilles à pied ici
}
local carPatrolLocations = {
    {x = 431.235168, y = -997.529664, z = 25.741334, heading = 195.590546},
    -- Ajoutez d'autres emplacements en ville ici
}

local footPatrols = 0
local maxFootPatrols = 3  -- Réduction du nombre maximum de patrouilles à pied à 3
local carPatrols = 0
local maxCarPatrols = 10

local bousculadeCounts = {}

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
        if pedModel == model then
            return true
        end
    end
    return false
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

-- Fonction pour arrêter et emprisonner un joueur
local function arrestPlayer(playerPed)
    if IsEntityDead(playerPed) then
        return
    end

    TaskSetBlockingOfNonTemporaryEvents(playerPed, true)
    TaskHandsUp(playerPed, 5000, playerPed, -1, true)
    Citizen.Wait(5000)
    TaskEnterVehicle(playerPed, GetVehiclePedIsIn(playerPed, true), 20000, 0, 1.0, 1, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous êtes en état d\'arrestation!' } })
    Citizen.Wait(10000)
    SetEntityCoords(playerPed, 1690.0, 2605.0, 45.5) -- Coordonnées de la prison
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = 0
end

-- Fonction pour tuer un joueur
local function killPlayer(playerPed)
    SetEntityHealth(playerPed, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous avez tué un policier et vous êtes abattu!' } })
end

-- Fonction pour envoyer un joueur en prison pour vol de voiture
local function sendToPrisonForTheft(playerPed)
    TaskSetBlockingOfNonTemporaryEvents(playerPed, true)
    TaskHandsUp(playerPed, 5000, playerPed, -1, true)
    Citizen.Wait(5000)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous êtes en état d\'arrestation pour vol de voiture!' } })
    Citizen.Wait(10000)
    SetEntityCoords(playerPed, 1690.0, 2605.0, 45.5) -- Coordonnées de la prison
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = 0
end

-- Fonction pour faire intervenir le SWAT en cas de meurtre de policier
local function callSWAT()
    print("SWAT called")  -- Message de débogage
    for _, loc in ipairs(carPatrolLocations) do
        local swatModel = swatModels[math.random(#swatModels)]
        local swatCar = GetHashKey(swatCars[math.random(#swatCars)])

        RequestModel(swatModel)
        RequestModel(swatCar)

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
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end)
    end
end

-- Fonction pour contrôler les PNJ et les joueurs
local function performRandomCheck(ped)
    if IsEntityDead(ped) then
        return
    end

    if math.random(1, 100) <= 20 then -- 20% de chance de contrôle
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            TaskLeaveVehicle(ped, vehicle, 0)
            TaskStandStill(ped, 5000)
        else
            TaskStandStill(ped, 5000)
        end

        if IsPedAPlayer(ped) then
            TriggerEvent('chat:addMessage', { args = { 'Police', 'Contrôle de police sur vous en cours...' } })
        end

        Citizen.Wait(5000) -- Attendre pendant le contrôle

        if HasPedGotWeapon(ped, GetHashKey("WEAPON_PISTOL"), false) then
            TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous êtes en possession d\'armes illégales!' } })
            arrestPlayer(ped)
        end
    end
end

-- Fonction pour initier la poursuite de police
local function initiatePoliceChase(playerPed)
    print("Poursuite de police initiée pour le vol de véhicule.")
    Citizen.Wait(10000) -- Attendre 10 secondes pour simuler la poursuite
    sendToPrisonForTheft(playerPed)
end

-- Fonction pour gérer les interactions de la police en fonction de l'infraction
local function handlePoliceInteraction(playerPed, targetPed)
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    if not bousculadeCounts[playerId] then
        bousculadeCounts[playerId] = 0
    end

    if IsEntityDead(targetPed) then
        print("Target ped is dead")  -- Message de débogage
        if IsPedPolice(targetPed) then
            print("Target ped is a police officer")  -- Message de débogage
            callSWAT()  -- Appel du SWAT en cas de meurtre de policier
        end
        killPlayer(playerPed)
    elseif IsPedInMeleeCombat(playerPed) then
        if IsPedPolice(targetPed) then
            bousculadeCounts[playerId] = bousculadeCounts[playerId] + 1
            print("Niveau d'agressivité (bousculades) : " .. bousculadeCounts[playerId])
            if bousculadeCounts[playerId] == 1 then
                print("Première bousculade détectée, avertissement.")
                TriggerEvent('chat:addMessage', { args = { 'Police', 'Attention, ne bousculez pas les policiers !' } })
            elseif bousculadeCounts[playerId] >= 2 then
                print("Seconde bousculade détectée, arrestation.")
                arrestPlayer(playerPed)
            end
        end
    elseif HasPedGotWeapon(playerPed, GetHashKey("WEAPON_PISTOL"), false) then
        arrestPlayer(playerPed)
    elseif IsPedInAnyVehicle(playerPed, false) and not IsVehicleOwnedByPlayer(GetVehiclePedIsIn(playerPed, false)) then
        initiatePoliceChase(playerPed)
    else
        performRandomCheck(playerPed)
    end
end

-- Fonction pour créer une patrouille à pied
local function createFootPatrol()
    if footPatrols >= maxFootPatrols then
        print("Nombre maximum de patrouilles à pied atteint")
        return
    end

    local loc = footPatrolLocations[math.random(#footPatrolLocations)]
    local model1 = policeModels[math.random(#policeModels)]
    local model2 = policeModels[math.random(#policeModels)]

    RequestModel(model1)
    RequestModel(model2)

    while not HasModelLoaded(model1) or not HasModelLoaded(model2) do
        Citizen.Wait(0)
    end

    local ped1 = CreatePed(4, model1, loc.x, loc.y, loc.z, loc.heading or 0.0, true, true)
    local ped2 = CreatePed(4, model2, loc.x, loc.y, loc.z, loc.heading or 0.0, true, true)

    if DoesEntityExist(ped1) and DoesEntityExist(ped2) then
        GiveWeaponToPed(ped1, GetHashKey("WEAPON_PISTOL"), 1000, false, true)
        GiveWeaponToPed(ped2, GetHashKey("WEAPON_PISTOL"), 1000, false, true)
        TaskWanderStandard(ped1, 10.0, 10)
        TaskWanderStandard(ped2, 10.0, 10)
        print("Patrouille à pied créée : " .. model1 .. " et " .. model2)
        createBlip(ped1, 1, 3, "Police à pied")
        createBlip(ped2, 1, 3, "Police à pied")
    else
        print("Échec de la création de la patrouille à pied : " .. model1 .. " et " .. model2)
    end

    footPatrols = footPatrols + 1

    Citizen.SetTimeout(600000, function()
        if DoesEntityExist(ped1) then
            DeleteEntity(ped1)
        end
        if DoesEntityExist(ped2) then
            DeleteEntity(ped2)
        end
        footPatrols = footPatrols - 1
    end)
end

-- Fonction pour créer une patrouille en voiture
local function createCarPatrol()
    if carPatrols >= maxCarPatrols then
        print("Nombre maximum de patrouilles en voiture atteint")
        return
    end

    local loc = carPatrolLocations[math.random(#carPatrolLocations)]
    local carModel = GetHashKey(policeCars[math.random(#policeCars)])
    local pedModel = policeModels[math.random(#policeModels)]

    RequestModel(carModel)
    RequestModel(pedModel)

    while not HasModelLoaded(carModel) or not HasModelLoaded(pedModel) do
        Citizen.Wait(0)
    end

    local vehicle = CreateVehicle(carModel, loc.x, loc.y, loc.z, loc.heading or 0.0, true, false)
    local ped = CreatePedInsideVehicle(vehicle, 4, pedModel, -1, true, false)

    if DoesEntityExist(vehicle) and DoesEntityExist(ped) then
        GiveWeaponToPed(ped, GetHashKey("WEAPON_PISTOL"), 1000, false, true)
        TaskVehicleDriveWander(ped, vehicle, 20.0, 786603)
        print("Patrouille en voiture créée : " .. carModel .. " avec " .. pedModel)
        createBlip(vehicle, 56, 3, "Patrouille de police")
    else
        print("Échec de la création de la patrouille en voiture : " .. carModel .. " avec " .. pedModel)
    end

    carPatrols = carPatrols + 1

    Citizen.SetTimeout(600000, function()
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        carPatrols = carPatrols - 1
    end)
end

-- Threads pour créer et gérer les patrouilles
Citizen.CreateThread(function()
    while true do
        createFootPatrol()
        Citizen.Wait(60000) -- Une minute d'intervalle entre chaque patrouille à pied
    end
end)

Citizen.CreateThread(function()
    while true do
        createCarPatrol()
        Citizen.Wait(30000) -- Vérification toutes les 30 secondes pour renouveler les patrouilles en voiture
    end
end)

-- Thread pour gérer les infractions graves et la réaction des policiers
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        local playerPed = PlayerPedId()
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
        end
    end
end)

-- Thread pour détecter le vol de voiture
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        local playerPed = PlayerPedId()
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if not IsVehicleOwnedByPlayer(vehicle) then
                initiatePoliceChase(playerPed)
            end
        end
    end
end)