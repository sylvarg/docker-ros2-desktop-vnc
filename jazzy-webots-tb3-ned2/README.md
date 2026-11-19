# jazzy-webots-tb3-ned2

Cette variante part de l'image [`jazzy-webots-tb3`](../jazzy-webots-tb3/README.md).
Elle ajoute MoveIt 2, le contrôleur de trajectoire ROS 2 et le pilote officiel
Niryo, avec la description et la configuration MoveIt du Ned2. Les paquets
Niryo sont chargés automatiquement avant le workspace du TP.

## Construire et lancer

Depuis la racine du dépôt, sous macOS ou Linux :

```sh
bash jazzy-webots-tb3-ned2/build.sh
```

Sous Windows PowerShell :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\jazzy-webots-tb3-ned2\build.ps1
```

Si la clé privée `jazzy-webots-tb3/ssh/id_ed25519_tb3_tp` est présente, le
script construit l'image TB3 avec cette clé via le secret BuildKit existant.
Sinon, il réutilise le tag TB3 local s'il existe, ou construit l'image TB3.
L'image Ned2 hérite de la clé SSH intégrée à l'image TB3. La clé privée est
ignorée par Git. La [clé publique](../jazzy-webots-tb3/ssh/id_ed25519_tb3_tp.pub)
est versionnée.

Le Dockerfile accepte `--build-arg BASE_IMAGE=…` pour partir d'un autre tag
de la variante TB3 lors d'un `docker build` direct. Compose reprend les montages
et les réglages du TB3. Par exemple, avec le fichier d'environnement macOS :

```sh
docker compose --env-file env.macos -f jazzy-webots-tb3-ned2/docker-compose.yaml up -d
```

Sous Windows ou Linux, utiliser `env.windows` ou `env.linux` à la racine du dépôt.
Ouvrir le bureau sur `http://127.0.0.1:6080`. Arrêter l'ancien service s'il
utilise déjà ce port.

## Démarrer Webots sur l’hôte

Depuis la racine du dépôt, lancer le [serveur Webots commun](../local_webots_server/README.md)
dans un terminal de l’hôte. Utiliser le même fichier d’environnement que pour Compose.

```sh
sh local_webots_server/run_webots_host.sh --env-file env.macos
```

Sous Linux, remplacer `env.macos` par `env.linux`. Sous Windows PowerShell :

```powershell
.\local_webots_server\run_webots_host.cmd --env-file env.windows
```

## Connecter les robots

Dans le conteneur, renseigner `TB3_IP` dans `~/.bashrc` et recharger avec
`sb`. Si ce fichier provient d'une ancienne image TB3, renommer la ligne
`export ROBOT_IP=…` en `export TB3_IP=…` pour conserver l'adresse du poste.
La commande `zenoh` se connecte au TB3 attribué et charge le filtre
`tb3_zenoh.json5`, qui garde les interfaces Ned2 et l'horloge de simulation
dans le conteneur.

Monter le workspace du TP qui contient `ned2_simulation` à côté de
`tb3_simulation`, puis compiler le paquet dans le conteneur :

```sh
cd ~/ros2_ws
colcon build --packages-select ned2_simulation --symlink-install
source install/setup.bash
```

Pour le Ned2, utiliser une des deux commandes :

```sh
# Webots
ros2 launch ned2_simulation ned2.launch.py

# Robot réel attribué
export NED2_IP=192.168.0.42
ros2 launch ned2_simulation ned2.launch.py backend:=real robot_ip:="$NED2_IP"
```

Les deux lancements exposent l'action ROS 2 `/ned2/move_action`. Le pilote
accède au Ned2 réel via son port TCP 9090. Se reporter à
`ned2_simulation/INSTALLATION_TP.md` dans le workspace pour l'attribution des
robots et la recette sur le Wi-Fi.
