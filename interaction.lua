-- Interactions management functions

-- Function to handle bousculades
function handleBousculade(playerPed, policePed)
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

-- Function to handle car theft
function handleCarTheft(playerPed, vehicle)
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPeds = GetNearbyPeds(playerCoords, 50.0) -- 50 unit radius to detect nearby peds

    for _, ped in ipairs(nearbyPeds) do
        if not IsPedAPlayer(ped) and HasEntityClearLosToEntity(ped, playerPed, 17) then
            -- Simulate the ped contacting the police
            print("Ped contacting police about car theft")
            TriggerEvent('chat:addMessage', { args = { 'Citizen', 'I saw someone stealing a car!' } })
            Citizen.Wait(1000) -- Simulate time taken to contact police
            sendPoliceToLocation(playerCoords)
            break -- Only one ped needs to call the police
        end
    end
end

-- Function to send police to a specific location
function sendPoliceToLocation(coords)
    print("Sending police to location: " .. coords)
    local policePeds = GetNearbyPolicePeds(coords, 1000.0) -- Large radius to find nearby police
    table.sort(policePeds, function(a, b)
        return #(coords - GetEntityCoords(a)) < #(coords - GetEntityCoords(b))
    end)
    for i = 1, math.min(2, #policePeds) do
        local policePed = policePeds[i]
        local vehicle = GetVehiclePedIsIn(policePed, false)
        if vehicle then
            print("Assigning police vehicle to chase: " .. policePed)
            createBlip(vehicle, 1, 1, "Police Patrol") -- Add a red blip
            TaskVehicleDriveToCoordLongrange(policePed, vehicle, coords.x, coords.y, coords.z, 20.0, 786603, 5.0)
            SetVehicleSiren(vehicle, true) -- Activer la sirène
            SetDriveTaskDrivingStyle(policePed, 786603) -- Code de conduite agressif
        else
            print("No vehicle found for policePed: " .. policePed)
        end
    end
end

-- Function to create a blip on the map
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

-- Function to arrest a player by a police officer
function arrestPlayerByPolice(playerPed, policePed)
    TaskSetBlockingOfNonTemporaryEvents(policePed, true)
    TaskLeaveVehicle(policePed, GetVehiclePedIsIn(policePed, false), 0)
    TaskArrestPed(policePed, playerPed)
    Citizen.Wait(5000)
    ClearPedTasksImmediately(playerPed)
    SetEntityCoords(playerPed, 1690.0, 2605.0, 45.5) -- Prison coordinates
    TriggerEvent('chat:addMessage', { args = { 'Police', 'You are under arrest!' } })
    -- Réinitialiser le compteur de bousculades après avoir mis le joueur en prison
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = 0
end

-- Function to kill a player
function killPlayer(playerPed)
    SetEntityHealth(playerPed, 0)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'You killed a police officer and have been shot!' } })
end

-- Function to call SWAT in case of police murder
function callSWAT()
    print("SWAT called")  -- Debug message
    for _, loc in ipairs(Config.CarPatrolLocations) do
        local swatModel, swatCar = Config.SwatModels[math.random(#Config.SwatModels)], GetHashKey(Config.SwatCars[math.random(#Config.SwatCars)])
        RequestModel(swatModel)
        RequestModel(swatCar)
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
function performRandomCheck(ped)
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

-- Function to block and arrest the player
function blockAndArrestPlayer(policePed, playerPed, vehicle)
    TaskVehicleTempAction(policePed, vehicle, 27, 1000) -- Bloquer le véhicule
    Citizen.Wait(1000)
    TaskLeaveVehicle(policePed, vehicle, 0)
    TaskArrestPed(policePed, playerPed)
    Citizen.Wait(5000)
    ClearPedTasksImmediately(playerPed)
    SetEntityCoords(playerPed, 1690.0, 2605.0, 45.5) -- Coordonnées de la prison
    TriggerEvent('chat:addMessage', { args = { 'Police', 'You are under arrest!' } })
    -- Réinitialiser le compteur de bousculades après avoir mis le joueur en prison
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = 0
end

-- Fonction pour initier une poursuite policière
function initiatePoliceChase(playerPed)
    print("Police chase initiated for vehicle theft.")
    Citizen.Wait(10000) -- Wait 10 seconds to simulate the chase
    local policePeds = GetNearbyPolicePeds(GetEntityCoords(playerPed), 50.0) -- 50 unit radius
    if #policePeds > 0 then
        for i = 1, math.min(2, #policePeds) do
            local policePed = policePeds[i]
            local vehicle = GetVehiclePedIsIn(policePed, false)
            if vehicle then
                print("Assigning police vehicle to chase: " .. policePed)
                createBlip(vehicle, 1, 1, "Police Patrol") -- Add a red blip
                TaskVehicleChase(policePed, playerPed)
                SetTaskVehicleChaseBehaviorFlag(policePed, 32, true) -- Enable siren
                SetDriveTaskDrivingStyle(policePed, 786603) -- Code de conduite agressif
                Citizen.CreateThread(function()
                    while true do
                        Citizen.Wait(1000)
                        if not IsPedInAnyVehicle(playerPed, false) then
                            blockAndArrestPlayer(policePed, playerPed, vehicle)
                            break
                        end
                        -- Ajouter la logique pour immobiliser le véhicule du voleur
                        local playerVehicle = GetVehiclePedIsIn(playerPed, false)
                        if playerVehicle and IsVehicleStopped(playerVehicle) then
                            local distance = #(GetEntityCoords(policePed) - GetEntityCoords(playerPed))
                            if distance <= 10.0 then -- Vérifier si la patrouille est à proximité
                                -- Demander au voleur de sortir du véhicule
                                if #policePeds > 0 then
                                    TriggerEvent('chat:addMessage', { args = { 'Police', 'Sortez du véhicule immédiatement!' } })
                                    TaskLeaveVehicle(playerPed, playerVehicle, 0)
                                    Citizen.Wait(1000)
                                    blockAndArrestPlayer(policePed, playerPed, vehicle)
                                    break
                                else
                                    print("No police officers nearby to arrest the player.")
                                    handleCarTheft(playerPed, GetVehiclePedIsIn(playerPed, false))
                                end
                            end
                        end
                    end
                end)
            else
                print("No vehicle found for policePed: " .. policePed)
            end
        end
    else
        print("No police officers nearby to arrest the player.")
        handleCarTheft(playerPed, GetVehiclePedIsIn(playerPed, false))
    end
end

-- Function to handle police interactions based on the offense
function handlePoliceInteraction(playerPed, targetPed)
    local playerId = GetPlayerServerId(NetworkGetEntityOwner(playerPed))
    bousculadeCounts[playerId] = bousculadeCounts[playerId] or 0
    if IsEntityDead(targetPed) then
        print("Target ped is dead")  -- Debug message
        if IsPedPolice(targetPed) then
            print("Target ped is a police officer")  -- Debug message
            callSWAT()  -- Call SWAT in case of police murder
        end
        dropItem(targetPed)  -- Faire tomber un objet
        killPlayer(playerPed)
    elseif IsPedInMeleeCombat(playerPed) then
        if IsPedPolice(targetPed) then handleBousculade(playerPed, targetPed) end
    elseif HasPedGotWeapon(playerPed, GetHashKey("WEAPON_PISTOL"), false) then
        arrestPlayerByPolice(playerPed, targetPed)
    elseif IsPedInAnyVehicle(playerPed, false) and not IsVehicleOwnedByPlayer(GetVehiclePedIsIn(playerPed, false)) then
        initiatePoliceChase(playerPed)
    else
        performRandomCheck(playerPed)
    end
end

-- Function to drop an item when a ped is killed
function dropItem(ped)
    local pedCoords = GetEntityCoords(ped)
    local items = {
        { item = "prop_money_bag_01", chance = 80 }, -- Argent
        { item = "prop_ld_health_pack", chance = 10 }, -- Nourriture
        { item = "w_pi_pistol", chance = 10 } -- Arme
    }

    local randomChance = math.random(100)
    local cumulativeChance = 0
    local itemToDrop = nil

    for _, item in ipairs(items) do
        cumulativeChance = cumulativeChance + item.chance
        if randomChance <= cumulativeChance then
            itemToDrop = item.item
            break
        end
    end

    if itemToDrop then
        RequestModel(GetHashKey(itemToDrop))
        while not HasModelLoaded(GetHashKey(itemToDrop)) do
            Citizen.Wait(0)
        end
        local item = CreateObject(GetHashKey(itemToDrop), pedCoords.x, pedCoords.y, pedCoords.z, true, true, true)
        if DoesEntityExist(item) then
            PlaceObjectOnGroundProperly(item)
            TriggerEvent('chat:addMessage', { args = { 'System', 'An item has been dropped: ' .. itemToDrop } })
            print("Item dropped at: " .. pedCoords .. " Item: " .. itemToDrop)
        else
            print("Failed to create item: " .. itemToDrop)
        end
    else
        print("No item dropped.")
    end
end