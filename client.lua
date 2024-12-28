-- Variables globales
ESX = nil
bousculadeCounts = {}
lastBousculadeTime = {}
patrols = {}

-- Nouvelle méthode pour obtenir l'objet partagé ESX
Citizen.CreateThread(function()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        Citizen.Wait(0)
    end
end)

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

-- Fonction pour gérer les bousculades
function handleBousculade(playerPed, policePed)
    local currentTime = GetGameTimer()

    if not lastBousculadeTime[playerPed] or currentTime - lastBousculadeTime[playerPed] > 5000 then
        lastBousculadeTime[playerPed] = currentTime
        bousculadeCounts[playerPed] = (bousculadeCounts[playerPed] or 0) + 1

        if bousculadeCounts[playerPed] >= 3 then
            -- Si le joueur a bousculé le policier 3 fois ou plus, envoyer en prison
            ESX.ShowNotification("Vous avez bousculé un policier 3 fois. Vous êtes en état d'arrestation !")
            Citizen.Wait(2000) -- Attendre 2 secondes avant d'envoyer en prison
            -- Jouer l'animation de lever les mains
            TaskPlayAnim(playerPed, "random@mugging3", "handsup_standing_base", 8.0, -8.0, -1, 49, 0, false, false, false)
            Citizen.Wait(3000) -- Attendre 3 secondes pour l'animation
            -- Téléporter le joueur à la prison
            SetEntityCoords(playerPed, 1690.26, 2591.02, 45.91) -- Coordonnées de la prison
            TriggerServerEvent('police:sendToJail', GetPlayerServerId(PlayerId()))
            bousculadeCounts[playerPed] = 0 -- Réinitialiser le compteur
        else
            -- Avertir le joueur
            ESX.ShowNotification("Attention ! Vous avez bousculé un policier. Encore " .. (3 - bousculadeCounts[playerPed]) .. " fois avant l'arrestation.")
            -- Désactiver les actions agressives de la police
            disablePoliceAggression(policePed)
        end
    end
end

-- Fonction pour désactiver les actions agressives de la police
function disablePoliceAggression(policePed)
    SetPedFleeAttributes(policePed, 0, false)
    SetPedCombatAttributes(policePed, 17, true)
    SetPedSeeingRange(policePed, 0.0)
    SetPedHearingRange(policePed, 0.0)
    SetPedAlertness(policePed, 0)
    SetPedKeepTask(policePed, true)
end

-- Fonction pour gérer l'arrestation du joueur
function arrestPlayer(playerPed)
    local playerCoords = GetEntityCoords(playerPed)
    local policePeds = GetNearbyPolicePeds(playerCoords, 10.0) -- Rayon de 10 unités pour détecter les policiers

    for _, policePed in ipairs(policePeds) do
        if IsPedPolice(policePed) then
            if IsPedInAnyVehicle(playerPed, false) then
                TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
                Citizen.Wait(2000) -- Attendre que le joueur sorte du véhicule
            end
            TaskAimGunAtEntity(policePed, playerPed, -1, true)
            Citizen.Wait(2000) -- Attendre que le policier menace le joueur
            TaskArrestPed(policePed, playerPed)
            Citizen.Wait(2000) -- Attendre que l'arrestation soit terminée
            TriggerServerEvent('police:sendToJail', GetPlayerServerId(NetworkGetEntityOwner(playerPed)))
        end
    end
end

-- Fonction pour vérifier si le véhicule est arrêté
function isVehicleStopped(vehicle)
    return GetEntitySpeed(vehicle) < 0.1
end

-- Thread pour gérer l'arrestation du joueur
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Vérifier toutes les secondes

        local playerPed = PlayerPedId()
        local wantedLevel = GetPlayerWantedLevel(PlayerId())

        if wantedLevel > 0 and IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if not IsVehicleOwnedByPlayer(vehicle) and isVehicleStopped(vehicle) then
                arrestPlayer(playerPed)
            end
        end
    end
end)

AddEventHandler('baseevents:onPlayerKilled', function(killerId, data)
    local playerPed = PlayerPedId()
    local killerPed = GetPlayerPed(GetPlayerFromServerId(killerId))
    handlePlayerDeath(playerPed, killerPed)
end)

AddEventHandler('baseevents:onPlayerDied', function(data)
    local playerPed = PlayerPedId()
    handlePlayerDeath(playerPed, nil)
end)

function handlePlayerDeath(playerPed, killerPed)
    if killerPed then
        print("Player killed by another player")
        -- Ajouter la logique pour gérer la mort du joueur par un autre joueur
    else
        print("Player died")
        -- Ajouter la logique pour gérer la mort du joueur par d'autres causes
    end
end

-- Ajouter un événement pour détecter la mort des PNJ
AddEventHandler('gameEventTriggered', function(eventName, eventData)
    if eventName == 'CEventNetworkEntityDamage' then
        local victim = eventData[1]
        local attacker = eventData[2]
        if IsEntityAPed(victim) and IsPedAPlayer(attacker) then
            if IsPedDeadOrDying(victim, 1) then
                dropItem(victim)
            end
        end
    end
end)

-- Détecter la mort des PNJ et déclencher l'événement côté serveur
AddEventHandler('baseevents:onNPCDeath', function(npcId, killerId)
    TriggerServerEvent('baseevents:onNPCDeath', npcId, killerId)
end)

-- Table pour stocker les objets droppés
local droppedItems = {}

-- Événement pour créer un objet droppé
RegisterNetEvent('police:createDroppedItem')
AddEventHandler('police:createDroppedItem', function(item, count, coords)
    local object = CreateObject(GetHashKey('prop_money_bag_01'), coords.x, coords.y, coords.z, true, true, true)
    PlaceObjectOnGroundProperly(object)
    table.insert(droppedItems, { object = object, item = item, count = count })
end)

-- Thread pour détecter et ramasser les objets droppés
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for i, droppedItem in ipairs(droppedItems) do
            local objectCoords = GetEntityCoords(droppedItem.object)
            local distance = #(playerCoords - objectCoords)

            if distance < 2.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ramasser l'objet")
                if IsControlJustReleased(0, 38) then -- E key
                    TriggerServerEvent('police:pickupDroppedItem', droppedItem.item, droppedItem.count)
                    DeleteObject(droppedItem.object)
                    table.remove(droppedItems, i)
                end
            end
        end
    end
end)

-- Fonction pour démarrer les patrouilles
function startPatrols()
    startAllPatrols()
end

-- Fonction pour arrêter les patrouilles
function stopPatrols()
    stopAllPatrols()
end

-- Événement pour démarrer les patrouilles
RegisterNetEvent('police:startPatrols')
AddEventHandler('police:startPatrols', function()
    startPatrols()
end)

-- Événement pour arrêter les patrouilles
RegisterNetEvent('police:stopPatrols')
AddEventHandler('police:stopPatrols', function()
    stopPatrols()
end)

-- Fonction pour détecter le vol de voiture et avertir la police
function detectCarTheft()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if not IsVehicleOwnedByPlayer(vehicle) then
            local playerCoords = GetEntityCoords(playerPed)
            local vehicleOwner = GetPedInVehicleSeat(vehicle, -1)
            if DoesEntityExist(vehicleOwner) and not IsPedAPlayer(vehicleOwner) then
                TriggerServerEvent('police:carTheftAlert', playerCoords)
            end
        end
    end
end

-- Thread pour détecter le vol de voiture
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Vérifier toutes les secondes
        detectCarTheft()
    end
end)

-- Fonction pour gérer l'alerte de vol de voiture
RegisterNetEvent('police:carTheftAlert')
AddEventHandler('police:carTheftAlert', function(coords)
    local policePeds = GetNearbyPolicePeds(coords, 100.0) -- Rayon de 100 unités pour détecter les policiers
    local policeChasers = {}

    for _, policePed in ipairs(policePeds) do
        if IsPedPolice(policePed) then
            table.insert(policeChasers, policePed)
            if #policeChasers >= 2 then
                break
            end
        end
    end

    for _, policePed in ipairs(policeChasers) do
        TaskVehicleChase(policePed, PlayerPedId())
        SetTaskVehicleChaseBehaviorFlag(policePed, 32, true) -- Comportement agressif
        SetTaskVehicleChaseIdealPursuitDistance(policePed, 0.0) -- Distance de poursuite rapprochée
        SetPedFleeAttributes(policePed, 0, false) -- Désactiver la fuite
        SetPedCombatAttributes(policePed, 46, true) -- Désactiver le tir
    end
end)

-- Fonction pour créer une patrouille
function createPatrol(patrolType)
    if (patrolType == "foot" and footPatrols >= Config.MaxFootPatrols) or (patrolType == "car" and carPatrols >= Config.MaxCarPatrols) then
        print("Maximum number of patrols reached for " .. patrolType)
        return
    end

    local loc = (patrolType == "foot" and Config.FootPatrolLocations or Config.CarPatrolLocations)[math.random(#(patrolType == "foot" and Config.FootPatrolLocations or Config.CarPatrolLocations))]
    
    -- Vérifier s'il y a déjà un véhicule à l'emplacement
    if patrolType == "car" and IsAnyVehicleNearPoint(loc.x, loc.y, loc.z, 5.0) then
        print("A vehicle is already near the patrol location. Skipping patrol creation.")
        return
    end

    local model1, model2 = Config.PoliceModels[math.random(#Config.PoliceModels)], Config.PoliceModels[math.random(#Config.PoliceModels)]
    local carModel = patrolType == "car" and GetHashKey(Config.PoliceCars[math.random(#Config.PoliceCars)]) or nil

    print("Requesting models...")
    RequestModel(model1)
    RequestModel(model2)
    if carModel then RequestModel(carModel) end

    while not HasModelLoaded(model1) or not HasModelLoaded(model2) or (carModel and not HasModelLoaded(carModel)) do
        Citizen.Wait(0)
    end
    print("Models loaded successfully")

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
        print("Creating vehicle patrol at coordinates: ", loc.x, loc.y, loc.z)
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
        if patrolType == "foot" then footPatrols = footPatrols + 1 else carPatrols = carPatrols + 1 end
        table.insert(patrols, {type = patrolType, ped1 = ped1, ped2 = ped2, vehicle = vehicle, lastMoveTime = GetGameTimer()})
    else
        print("Failed to create patrol " .. patrolType)
        if not DoesEntityExist(ped1) then print("Failed to create ped1") end
        if not DoesEntityExist(ped2) then print("Failed to create ped2") end
    end

    Citizen.SetTimeout(600000, function()
        if DoesEntityExist(ped1) then DeleteEntity(ped1) end
        if DoesEntityExist(ped2) then DeleteEntity(ped2) end
        if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
        if patrolType == "foot" then footPatrols = footPatrols - 1 else carPatrols = carPatrols - 1 end
    end)
end

-- Thread pour vérifier si les patrouilles sont en mouvement
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) -- Vérifier toutes les 10 secondes
        local currentTime = GetGameTimer()

        for i, patrol in ipairs(patrols) do
            if patrol.type == "car" and DoesEntityExist(patrol.vehicle) then
                if GetEntitySpeed(patrol.vehicle) < 1.0 then
                    if currentTime - patrol.lastMoveTime > 30000 then -- Si la patrouille est immobile depuis plus de 30 secondes
                        TaskVehicleDriveWander(patrol.ped1, patrol.vehicle, 20.0, 786603)
                        patrol.lastMoveTime = currentTime
                    end
                else
                    patrol.lastMoveTime = currentTime
                end
            elseif patrol.type == "foot" and DoesEntityExist(patrol.ped1) and DoesEntityExist(patrol.ped2) then
                if GetEntitySpeed(patrol.ped1) < 1.0 and GetEntitySpeed(patrol.ped2) < 1.0 then
                    if currentTime - patrol.lastMoveTime > 30000 then -- Si la patrouille est immobile depuis plus de 30 secondes
                        TaskWanderStandard(patrol.ped1, 10.0, 10)
                        TaskWanderStandard(patrol.ped2, 10.0, 10)
                        patrol.lastMoveTime = currentTime
                    end
                else
                    patrol.lastMoveTime = currentTime
                end
            end
        end
    end
end)