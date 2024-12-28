-- Utility functions

-- Fonction pour créer un blip sur la carte
function createBlip(entity, blipSprite, blipColor, blipName)
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
function IsPedPolice(ped)
    local pedModel = GetEntityModel(ped)
    for _, model in ipairs(Config.PoliceModels) do
        if pedModel == model then
            return true
        end
    end
    return false
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

-- Fonction utilitaire pour vérifier si un véhicule appartient au joueur
function IsVehicleOwnedByPlayer(vehicle)
    local player = GetPlayerFromServerId(NetworkGetPlayerIndexFromPed(vehicle))
    if player then
        local vehiclePlate = GetVehicleNumberPlateText(vehicle)
        for _, ownedVehicle in ipairs(GetOwnedVehicles(player)) do
            if ownedVehicle.plate == vehiclePlate then
                return true
            end
        end
    end
    return false
end

-- Fonction simulée pour obtenir les véhicules appartenant à un joueur
function GetOwnedVehicles(player)
    return { { plate = "ABC123" }, { plate = "XYZ789" } }
end

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