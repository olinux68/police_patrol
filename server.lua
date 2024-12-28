-- server.lua
RegisterServerEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    local playerId = source
    local killerId = data.killerServerId

    if killerId then
        TriggerClientEvent('police:alert', killerId)
    end
end)

-- Fonction pour gérer la mort des PNJ et le drop d'objets
AddEventHandler('baseevents:onPlayerKilled', function(killerId, data)
    local xPlayer = ESX.GetPlayerFromId(killerId)
    if xPlayer then
        -- Exemple de drop d'objet
        local item = 'bread' -- Nom de l'objet à dropper
        local count = 1 -- Quantité de l'objet à dropper
        xPlayer.addInventoryItem(item, count)
    end
end)

-- Fonction pour gérer la mort des PNJ et le drop d'objets ramassables
AddEventHandler('baseevents:onNPCDeath', function(npcId, killerId)
    local xPlayer = ESX.GetPlayerFromId(killerId)
    if xPlayer then
        -- Exemple de drop d'objet
        local item = 'bread' -- Nom de l'objet à dropper
        local count = 1 -- Quantité de l'objet à dropper
        local npcCoords = GetEntityCoords(npcId)
        
        -- Créer un objet physique sur le sol
        TriggerClientEvent('police:createDroppedItem', -1, item, count, npcCoords)
    end
end)

RegisterServerEvent('police:pickupDroppedItem')
AddEventHandler('police:pickupDroppedItem', function(item, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        xPlayer.addInventoryItem(item, count)
    end
end)

RegisterServerEvent('police:carTheftAlert')
AddEventHandler('police:carTheftAlert', function(coords)
    TriggerClientEvent('police:startCarChase', -1, coords)
end)

RegisterServerEvent('police:sendToJail')
AddEventHandler('police:sendToJail', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        -- Logique pour envoyer le joueur en prison
        -- Exemple : xPlayer.set('jailTime', 10) -- Mettre le joueur en prison pour 10 minutes
        TriggerClientEvent('esx_jail:sendToJail', playerId, 10) -- Envoyer le joueur en prison pour 10 minutes
    end
end)

-- client.lua
RegisterNetEvent('police:alert')
AddEventHandler('police:alert', function()
    -- Logique pour la sanction (ex: amende, prison)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous avez été sanctionné pour meurtre !' } })
end)
