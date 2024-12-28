-- Fonction pour démarrer une patrouille en voiture
function startCarPatrol(patrolLocation)
    local vehicle = CreateVehicle(GetHashKey('police'), patrolLocation.x, patrolLocation.y, patrolLocation.z, patrolLocation.heading, true, false)
    local ped = CreatePedInsideVehicle(vehicle, 4, GetHashKey('s_m_y_cop_01'), -1, true, false)
    TaskVehicleDriveWander(ped, vehicle, 20.0, 786603)
    SetVehicleSiren(vehicle, true)
    -- Ajout d'un blip pour le véhicule de patrouille
    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 1) -- Icône de blip
    SetBlipColour(blip, 3) -- Couleur de blip
    SetBlipScale(blip, 0.8) -- Taille du blip
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Police Patrol")
    EndTextCommandSetBlipName(blip)
end

-- Fonction pour arrêter une patrouille en voiture
function stopCarPatrol(vehicle)
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end

-- Fonction pour démarrer une patrouille à pied
function startFootPatrol(patrolLocation)
    local ped = CreatePed(4, GetHashKey('s_m_y_cop_01'), patrolLocation.x, patrolLocation.y, patrolLocation.z, patrolLocation.heading, true, false)
    TaskWanderStandard(ped, 10.0, 10)
    -- Ajout d'un blip pour la patrouille à pied
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 3) -- Icône de blip pour patrouille à pied
    SetBlipColour(blip, 3) -- Couleur de blip
    SetBlipScale(blip, 0.8) -- Taille du blip
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Foot Patrol")
    EndTextCommandSetBlipName(blip)
end

-- Fonction pour arrêter une patrouille à pied
function stopFootPatrol(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end

-- Fonction pour démarrer toutes les patrouilles
function startAllPatrols()
    for _, location in ipairs(Config.CarPatrolLocations) do
        startCarPatrol(location)
    end
    for _, location in ipairs(Config.FootPatrolLocations) do
        startFootPatrol(location)
    end
end

-- Fonction pour arrêter toutes les patrouilles
function stopAllPatrols()
    for vehicle in EnumerateVehicles() do
        if IsVehicleModel(vehicle, GetHashKey('police')) then
            stopCarPatrol(vehicle)
        end
    end
    for ped in EnumeratePeds() do
        if IsPedModel(ped, GetHashKey('s_m_y_cop_01')) then
            stopFootPatrol(ped)
        end
    end
end

-- Fonction pour énumérer les véhicules
function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, vehicle = FindFirstVehicle()
        if not handle or handle == -1 then
            EndFindVehicle(handle)
            return
        end

        local success
        repeat
            coroutine.yield(vehicle)
            success, vehicle = FindNextVehicle(handle)
        until not success

        EndFindVehicle(handle)
    end)
end

-- Fonction pour énumérer les peds
function EnumeratePeds()
    return coroutine.wrap(function()
        local handle, ped = FindFirstPed()
        if not handle or handle == -1 then
            EndFindPed(handle)
            return
        end

        local success
        repeat
            coroutine.yield(ped)
            success, ped = FindNextPed(handle)
        until not success

        EndFindPed(handle)
    end)
end