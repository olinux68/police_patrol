-- Fonction pour gérer les niveaux de recherche
function setWantedLevel(level)
    local playerPed = PlayerPedId()
    SetPlayerWantedLevel(PlayerId(), level, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
end

-- Thread pour gérer les niveaux de recherche et les réactions de la police
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Vérifier toutes les secondes

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local wantedLevel = GetPlayerWantedLevel(PlayerId())

        if wantedLevel > 0 then
            -- Logique pour gérer les réactions de la police en fonction du niveau de recherche
            local policePeds = GetNearbyPolicePeds(playerCoords, 100.0) -- Rayon de 100 unités pour détecter les policiers
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
                TaskVehicleChase(policePed, playerPed)
                SetTaskVehicleChaseBehaviorFlag(policePed, 32, true) -- Comportement agressif
                SetTaskVehicleChaseIdealPursuitDistance(policePed, 0.0) -- Distance de poursuite rapprochée
                SetPedFleeAttributes(policePed, 0, false) -- Désactiver la fuite
                SetPedCombatAttributes(policePed, 46, true) -- Désactiver le tir
            end
        end
    end
end)

-- Fonction pour obtenir les policiers à proximité
function GetNearbyPolicePeds(coords, radius)
    local policePeds = {}
    local peds = GetNearbyPeds(coords.x, coords.y, coords.z, radius)

    for _, ped in ipairs(peds) do
        if IsPedPolice(ped) then
            table.insert(policePeds, ped)
        end
    end

    return policePeds
end

-- Fonction pour obtenir les peds à proximité
function GetNearbyPeds(x, y, z, radius)
    local peds = {}
    local handle, ped = FindFirstPed()
    local success

    repeat
        local pedCoords = GetEntityCoords(ped)
        local distance = #(vector3(x, y, z) - pedCoords)

        if distance <= radius then
            table.insert(peds, ped)
        end

        success, ped = FindNextPed(handle)
    until not success

    EndFindPed(handle)
    return peds
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
            TaskArrestPed(policePed, playerPed)
            Citizen.Wait(2000) -- Attendre que l'arrestation soit terminée
            TriggerServerEvent('police:sendToJail', GetPlayerServerId(NetworkGetEntityOwner(playerPed)))
        end
    end
end

-- Thread pour gérer l'arrestation du joueur
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Vérifier toutes les secondes

        local playerPed = PlayerPedId()
        local wantedLevel = GetPlayerWantedLevel(PlayerId())

        if wantedLevel > 0 and IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if not IsVehicleOwnedByPlayer(vehicle) then
                arrestPlayer(playerPed)
            end
        end
    end
end)

-- Thread pour gérer les poursuites de voleurs de voiture
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Vérifier toutes les secondes

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if not IsVehicleOwnedByPlayer(vehicle) then
                -- Logique pour gérer les poursuites de voleurs de voiture
                local policePeds = GetNearbyPolicePeds(playerCoords, 100.0) -- Rayon de 100 unités pour détecter les policiers
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
                    TaskVehicleChase(policePed, playerPed)
                    SetTaskVehicleChaseBehaviorFlag(policePed, 32, true) -- Comportement agressif
                    SetTaskVehicleChaseIdealPursuitDistance(policePed, 0.0) -- Distance de poursuite rapprochée
                    SetPedFleeAttributes(policePed, 0, false) -- Désactiver la fuite
                    SetPedCombatAttributes(policePed, 46, true) -- Désactiver le tir
                end
            end
        end
    end
end)

RegisterNetEvent('police:startCarChase')
AddEventHandler('police:startCarChase', function(coords)
    local playerPed = PlayerPedId()
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
        TaskVehicleChase(policePed, playerPed)
        SetTaskVehicleChaseBehaviorFlag(policePed, 32, true) -- Comportement agressif
        SetTaskVehicleChaseIdealPursuitDistance(policePed, 0.0) -- Distance de poursuite rapprochée
        SetPedFleeAttributes(policePed, 0, false) -- Désactiver la fuite
        SetPedCombatAttributes(policePed, 46, true) -- Désactiver le tir
    end
end)
