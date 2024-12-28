Config = {}

-- Configuration des modèles de policiers
Config.PoliceModels = { GetHashKey("s_m_y_cop_01"), GetHashKey("s_f_y_cop_01") }
Config.SwatModels = { GetHashKey("s_m_y_swat_01") }

-- Configuration des véhicules de police
Config.PoliceCars = { "police", "police2", "police3" }
Config.SwatCars = { "riot", "fbi2" }

-- Emplacements des patrouilles à pied
Config.FootPatrolLocations = {
    { x = 453.151642, y = -990.118652, z = 30.678344, heading = 223.937012 },
    -- Ajouter d'autres emplacements de patrouille à pied ici
}

-- Emplacements des patrouilles en voiture
Config.CarPatrolLocations = {
    { x = 463.582428, y = -1014.712098, z = 28.066650, heading = 82.204728 },
    { x = 431.116486, y = -997.028564, z = 25.758300, heading = 172.913392 },
    { x = 421.529664, y = -1028.650512, z = 29.077636, heading = 2.834646 },
    -- Ajouter d'autres emplacements de patrouille en voiture ici
}

-- Configuration des limites de patrouille
Config.MaxFootPatrols = 3  -- Nombre maximum de patrouilles à pied
Config.MaxCarPatrols = 10  -- Nombre maximum de patrouilles en voiture