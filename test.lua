-- Patrol management functions

local footPatrols, carPatrols = 0, 0
local lastCarPatrolTime = 0
local lastFootPatrolTime = 0

-- Function to create a patrol
function createPatrol(patrolType)
    if (patrolType == "foot" and footPatrols >= Config.MaxFootPatrols) or (patrolType == "car" and carPatrols >= Config.MaxCarPatrols) then
        print("Maximum number of patrols reached for " .. patrolType)
        return
    end

    local loc = (patrolType == "foot" and Config.FootPatrolLocations or Config.CarPatrolLocations)[math.random(#(patrolType == "foot" and Config.FootPatrolLocations or Config.CarPatrolLocations))]
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

-- Threads to create and manage patrols
Citizen.CreateThread(function()
    while true do
        local currentTime = GetGameTimer()
        if currentTime - lastFootPatrolTime >= 60000 then -- One minute interval between each foot patrol
            createPatrol("foot")
            lastFootPatrolTime = currentTime
        end
        Citizen.Wait(1000) -- Check every second
    end
end)

Citizen.CreateThread(function()
    while true do
        local currentTime = GetGameTimer()
        if currentTime - lastCarPatrolTime >= 60000 then -- One minute interval between each car patrol
            createPatrol("car")
            lastCarPatrolTime = currentTime
        end
        Citizen.Wait(1000) -- Check every second
    end
end)