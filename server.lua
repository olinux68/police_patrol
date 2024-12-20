-- server.lua
RegisterServerEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    local playerId = source
    local killerId = data.killerServerId

    if killerId then
        TriggerClientEvent('police:alert', killerId)
    end
end)

-- client.lua
RegisterNetEvent('police:alert')
AddEventHandler('police:alert', function()
    -- Logique pour la sanction (ex: amende, prison)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'Vous avez été sanctionné pour meurtre !' } })
end)