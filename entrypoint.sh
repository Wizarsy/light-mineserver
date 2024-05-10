#!/usr/bin/env bash

install_java_apk() {
  __PACKAGES_DIR="${PWD}"/.packages
  if [ -z "$(find . -path "*/.packages")" ]; then
    mkdir -p "$__PACKAGES_DIR"
  fi
  __JAVA="$(apk search --no-cache "openjdk$1-jre*" | grep -Eo '.*(base|headless)')"
  __LATEST_JAVA="$(apk list --no-cache "$__JAVA" | awk '/openjdk/ {print $1}')"
  if [ ! -e "$__PACKAGES_DIR/java.version" ] || [ "$(cat "$__PACKAGES_DIR/java.version")" != "$__LATEST_JAVA" ]; then
    rm -f "$__PACKAGES_DIR"/*.apk
    echo "$__LATEST_JAVA" > "$__PACKAGES_DIR/java.version"
  fi
  apk fetch -R --no-cache "$__JAVA" -o "$__PACKAGES_DIR"
  if [ -n "$(find . -wholename "*/.packages/*.apk")" ]; then
    apk add --no-network --allow-untrusted --repositories-file=/dev/null --no-cache "$__PACKAGES_DIR"/*.apk
  fi
}

dowload_server() {
  if [ ! -e "server.jar" ] && [ ! -e "forge*.jar" ]; then
    mojang="https://piston-data.mojang.com/v1/objects/${2}/server.jar"
    forge="https://maven.minecraftforge.net/net/minecraftforge/forge/${2}/forge-${2}-installer.jar"
    curl -L# "${!1}" -o "server.jar"
  fi
}

config_server() {
  if [ "$1" = "forge" ]; then
    if [ ! -e "forge*.jar" ] || [ ! -e "run.sh" ]; then
      java -jar server.jar --installServer > /dev/null
      rm -f server.jar
    fi
    if [ -e "run.sh" ]; then
      echo -e "-Xms$XMX\n-Xmx$XMX" > user_jvm_args.txt
    fi
  fi
  if [ ! -e "eula.txt" ]; then
    echo "eula=true" > eula.txt
    echo "[]" | tee > banned-players.json banned-ips.json ops.json whitelist.json
    echo -e "enable-jmx-monitoring=false\nrcon.port=25575\nlevel-seed=$SEED\ngamemode=survival\nenable-command-block=false\nenable-query=false\ngenerator-settings={}\nenforce-secure-profile=true\nlevel-name=world\nmotd=$MOTD\nquery.port=25565\npvp=$PVP\ngenerate-structures=true\nmax-chained-neighbor-updates=1000000\ndifficulty=$DIFFICULTY\nnetwork-compression-threshold=256\nmax-tick-time=60000\nrequire-resource-pack=false\nuse-native-transport=true\nmax-players=$MAX_PLAYERS\nonline-mode=$ONLINE\nenable-status=true\nallow-flight=false\ninitial-disabled-packs=\nbroadcast-rcon-to-ops=true\nview-distance=$VIEW_DISTANCE\nserver-ip=\nresource-pack-prompt=\nallow-nether=true\nserver-port=25565\nenable-rcon=false\nsync-chunk-writes=true\nop-permission-level=4\nprevent-proxy-connections=false\nhide-online-players=false\nresource-pack=\nentity-broadcast-range-percentage=100\nsimulation-distance=$SIMULATION_DISTANCE\nrcon.password=\nplayer-idle-timeout=0\nforce-gamemode=false\nrate-limit=0\nhardcore=false\nwhite-list=false\nbroadcast-console-to-ops=true\nspawn-npcs=true\nspawn-animals=true\nlog-ips=true\nfunction-permission-level=2\ninitial-enabled-packs=vanilla\nlevel-type=minecraft\:normal\ntext-filtering-config=\nspawn-monsters=true\nenforce-whitelist=false\nspawn-protection=16\nresource-pack-sha1=\nmax-world-size=29999984" > server.properties
  else
    sed -i -e "s/online-mode.*/online-mode=$ONLINE/" -e "s/level-seed.*/level-seed=$SEED/" -e "s/gamemode.*/gamemode=$GAMEMODE/" -e "s/difficulty.*/difficulty=$DIFFICULTY/" -e "s/max-players.*/max-players=$MAX_PLAYERS/" -e "s/pvp.*/pvp=$PVP/" -e "s/motd.*/motd=$MOTD/" -e "s/view-distance*/view-distance=$VIEW_DISTANCE/" -e "s/simulation-distance*/simulation-distance=$SIMULATION_DISTANCE/" server.properties
  fi
}

run_server() {
  if [ -e "run.sh" ]; then
    "${PWD}"/run.sh nogui &
  else
    __EXEC=$(find "$PWD" -name "forge*.jar" -o -name "server.jar")
    java -Xms"$XMX" -Xmx"$XMX" -jar "$__EXEC" nogui &
  fi
}

backup() {
  __BACKUP_DIR="${PWD}"/backups
  if [ -z "$(find . -path "*/backups")" ]; then
    mkdir -p "$__BACKUP_DIR"
  fi
  while true; do
    sleep "$AUTOSAVE"
    tar --exclude="backups" --exclude=".packages" -czf "$__BACKUP_DIR/mineserver-$(date "+%F-%H_%M_%S").tar.gz" .
  done
}

main() {
  __CANDIDATES=$(cat "/etc/mineserver/$LOCAL_CANDIDATES" 2> /dev/null || curl -L# "$ONLINE_CANDIDATES")
  OLDIFS="$IFS"
  IFS="-"; read -ra __VERSION <<< "$MINE_VERSION"
  IFS="$OLDIFS"
  unset OLDIFS
  __JAVA_VERSION=$(jq -r ".${__VERSION[0]}.java" <<< "$__CANDIDATES")
  __ID=$(jq -r ".${__VERSION[0]}.${__VERSION[1]}" <<< "$__CANDIDATES")

  install_java_apk "$__JAVA_VERSION"

  dowload_server "${__VERSION[1]}" "$__ID" 

  config_server "${__VERSION[1]}"

  run_server

  backup
}

main