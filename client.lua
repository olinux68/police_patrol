-- Variables globales
bousculadeCounts = {}
lastBousculadeTime = {}

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
            TriggerServerEvent('police:carTheftAlert', playerCoords)
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

-- ...existing code...