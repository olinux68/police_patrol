# Police Patrol Resource

## Description

Cette ressource gère les patrouilles de police, les poursuites de voleurs de voiture et les interactions avec les joueurs dans le jeu GTA V via FiveM. Elle inclut des fonctionnalités pour créer des patrouilles à pied et en voiture, détecter les vols de voiture, et gérer les arrestations et les poursuites.

## Installation

1. Clonez ce dépôt dans votre répertoire `resources` de votre serveur FiveM.
2. Ajoutez la ligne suivante à votre fichier `server.cfg` :
   ```
   ensure police_patrol
   ```

## Configuration

Le fichier `config.lua` contient les paramètres de configuration pour cette ressource. Vous pouvez ajuster les modèles de police, les emplacements de patrouille, et d'autres paramètres selon vos besoins.

## Scripts

### Client Scripts

- `client.lua` : Script principal pour gérer les interactions et les événements côté client.
- `chase.lua` : Script pour gérer les poursuites de voleurs de voiture et les arrestations.
- `utils.lua` : Fonctions utilitaires pour diverses opérations, telles que la création de blips et la détection de vols de voiture.
- `test.lua` : Script de test pour vérifier les fonctionnalités de patrouille.

### Server Scripts

- `server.lua` : Script principal pour gérer les événements côté serveur, tels que les alertes de vol de voiture et les envois en prison.

## Fonctionnalités

### Patrouilles de Police

- Création de patrouilles à pied et en voiture.
- Gestion des patrouilles avec des limites maximales configurables.
- Suppression automatique des patrouilles après un certain temps.

### Poursuites de Voleurs de Voiture

- Détection des vols de voiture et déclenchement de poursuites par la police.
- Comportement agressif de la police lors des poursuites.
- Arrestation des voleurs de voiture et envoi en prison.

### Interactions et Événements

- Gestion des interactions avec les joueurs, telles que les bousculades et les combats.
- Détection des morts de PNJ et des joueurs, avec drop d'objets configurables.
- Création de blips sur la carte pour les patrouilles et les objets droppés.

## Utilisation

### Démarrer et Arrêter les Patrouilles

Pour démarrer les patrouilles, utilisez l'événement suivant :
```lua
TriggerEvent('police:startPatrols')
```

Pour arrêter les patrouilles, utilisez l'événement suivant :
```lua
TriggerEvent('police:stopPatrols')
```

### Détection de Vol de Voiture

Le script détecte automatiquement les vols de voiture et déclenche une alerte à la police. Vous pouvez ajuster la logique de détection dans le fichier `utils.lua`.

### Arrestation et Envoi en Prison

Lorsqu'un joueur est arrêté par la police, il est automatiquement envoyé en prison pour une durée configurable. Vous pouvez ajuster la logique d'arrestation et d'envoi en prison dans les fichiers `chase.lua` et `server.lua`.

## Contribuer

Les contributions sont les bienvenues ! Si vous avez des suggestions ou des améliorations, n'hésitez pas à ouvrir une issue ou à soumettre une pull request.

## Licence

Cette ressource est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.
