fx_version 'cerulean' -- Spécifie la version de l'architecture FiveM utilisée
game 'gta5' -- Indique que le jeu cible est GTA V

client_scripts {
    '@baseevents/client.lua', -- Script pour détecter les événements de mort
    'config.lua', -- Fichier de configuration
    'utils.lua', -- Fichier des fonctions utilitaires
    'interaction.lua', -- Fichier de gestion des interactions
    'patrols.lua', -- Fichier de gestion des patrouilles
    'client.lua', -- Script principal
    'chase.lua', -- Script pour gérer les poursuites
    'test.lua' -- Script de test
}

server_scripts {
    'server.lua' -- Script côté serveur
}