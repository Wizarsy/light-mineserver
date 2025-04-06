#!/usr/bin/env bash

init() {
  __DIRS=("./.config" "./.config/packages" "./backups" )
  for dir in "${__DIRS[@]}"; do
    if [[ ! -e "$dir" ]]; then
      mkdir -p "$dir"
    fi
  done
  __CANDIDATES=$(cat "${__DIRS[0]}/candidates.json" 2> /dev/null || curl -L# "$CANDIDATES_FILE" | tee "${__DIRS[0]}/candidates.json")
  OLDIFS="$IFS"
  IFS="-"; read -ra __VERSION <<< "$SERVER_VERSION"
  IFS="$OLDIFS"
  unset OLDIFS
  __JAVA_VERSION=$(jq -r ".${__VERSION[0]}.java" <<< "$__CANDIDATES")
  __FILE_ID=$(jq -r ".${__VERSION[0]}.${__VERSION[1]}" <<< "$__CANDIDATES")
}

install_java() {
  local __CONFIG_DIR="${__DIRS[0]}"
  local __PACKAGES_DIR="${__DIRS[1]}"
  local __LATEST_JAVA="$(apk list -q --no-cache "openjdk$1-jre" | awk '{print $1}')"
  local __JAVA="${__LATEST_JAVA%%-[0-9]*}"
  if [[ -n "$__LATEST_JAVA" ]]; then
    if [[ ! -e "$__CONFIG_DIR/java" || "$(cat "$__CONFIG_DIR/java")" != "$__LATEST_JAVA" ]]; then 
      rm -f "$__PACKAGES_DIR"/*.apk
      echo "$__LATEST_JAVA" > "$__CONFIG_DIR/java"
    fi
    if [[ ! -e "$__CONFIG_DIR/apksmanifest" || $(diff <(find "$__PACKAGES_DIR" -name "*.apk" | cut -d "/" -f 4) <(cat "$__CONFIG_DIR/apksmanifest")) ]]; then
      apk fetch -R --no-cache "$__JAVA" -o "$__PACKAGES_DIR"
      find "$__PACKAGES_DIR" -name "*.apk" | cut -d "/" -f 4 > "$__CONFIG_DIR/apksmanifest"
    fi
    if [[ -n "$(find "$__PACKAGES_DIR" -name "*.apk")" ]]; then
      apk add --no-cache --no-network --allow-untrusted --repositories-file=/dev/null "$__PACKAGES_DIR"/*.apk
    fi
  fi
}

download_server() {
  local __CONFIG_DIR="${__DIRS[0]}"
  if [[ (! -e "$__CONFIG_DIR/mine" || "$(cat "$__CONFIG_DIR/mine")" != "$MINE_VERSION") || (! -e "./server.jar" || "$(find . -name "forge*.jar")") ]]; then
    local mojang="https://piston-data.mojang.com/v1/objects/${2}/server.jar"
    local forge="https://maven.minecraftforge.net/net/minecraftforge/forge/${2}/forge-${2}-installer.jar"
    curl -L# "${!1}" -o "./server.jar"
    echo "$MINE_VERSION" > "$__CONFIG_DIR/mine"
  fi
  return
}

config_server() {
  if [[ ! -e "./eula.txt" ]]; then
    echo "eula=true" > ./eula.txt
    echo "[]" | tee > ./banned-players.json ./banned-ips.json ./ops.json ./whitelist.json
    echo -e "accepts-transfers=false\nallow-flight=false\nallow-nether=true\nbroadcast-console-to-ops=true\nbroadcast-rcon-to-ops=true\ndifficulty=survival\nenable-command-block=false\nenable-jmx-monitoring=false\nenable-query=false\nenable-rcon=false\nenable-status=true\nenforce-secure-profile=true\nenforce-whitelist=false\nentity-broadcast-range-percentage=100\nforce-gamemode=false\nfunction-permission-level=2\ngamemode=survival\ngenerate-structures=true\ngenerator-settings={}\nhardcore=false\nhide-online-players=false\ninitial-disabled-packs=\ninitial-enabled-packs=vanilla\nlevel-name=world\nlevel-seed=\nlevel-type=minecraft\:normal\nlog-ips=true\nmax-chained-neighbor-updates=1000000\nmax-players=20\nmax-tick-time=60000\nmax-world-size=29999984\nmotd=A Minecraft Server\nnetwork-compression-threshold=256\nonline-mode=true\nop-permission-level=4\nplayer-idle-timeout=0\nprevent-proxy-connections=false\npvp=true\nquery.port=25565\nrate-limit=0\nrcon.password=\nrcon.port=25575\nregion-file-compression=deflate\nrequire-resource-pack=false\nresource-pack=\nresource-pack-id=\nresource-pack-prompt=\nresource-pack-sha1=\nserver-ip=\nserver-port=25565\nsimulation-distance=10\nspawn-animals=true\nspawn-monsters=true\nspawn-npcs=true\nspawn-protection=16\nsync-chunk-writes=true\ntext-filtering-config=\nuse-native-transport=true\nview-distance=10\nwhite-list=false" > ./server.properties
  fi
  if [[ "$1" = "forge" ]]; then
    if [[ ! "$(find . -name "forge*.jar")" && ! -e "./run.sh" ]]; then
      java -jar ./server.jar --installServer > /dev/null
      rm -f "./server.jar"
    fi
  fi
}

user_config() {
  # sed -i -e "s/online-mode.*/online-mode=$ONLINE/" -e "s/level-seed.*/level-seed=$SEED/" -e "s/gamemode.*/gamemode=$GAMEMODE/" -e "s/difficulty.*/difficulty=$DIFFICULTY/" -e "s/max-players.*/max-players=$MAX_PLAYERS/" -e "s/pvp.*/pvp=$PVP/" -e "s/motd.*/motd=$MOTD/" -e "s/view-distance*/view-distance=$VIEW_DISTANCE/" -e "s/simulation-distance*/simulation-distance=$SIMULATION_DISTANCE/" ./server.properties
  printenv | grep "MINE_"
}

run_server() {
  if [[ "$1" = "forge" && -e "./run.sh" ]]; then
    echo "$JVM_ARGS" | tr " " "\n" > user_jvm_args.txt
    ./run.sh $MINE_ARGS
  else
    local __EXEC="$(find . -name "forge*.jar" -o -name "server.jar")"
    java $JVM_ARGS -jar "$__EXEC" $MINE_ARGS
  fi
}

backup() {
  if [[ "$AUTOBACKUP" -ge 900 ]]; then
    local __BACKUP_DIR="${__DIRS[2]}"
    while true; do
      sleep "$AUTOBACKUP"
      tar --exclude="backups" --exclude="${__DIRS[0]}" -czf "$__BACKUP_DIR/light-mineserver-$(date "+%d_%m_%4Y-%H_%M_%S").tar.gz" .
    done
  fi
}

main() {
  init
  install_java "$__JAVA_VERSION"
  download_server "${__VERSION[1]}" "$__FILE_ID" 
  config_server "${__VERSION[1]}"
  user_config 
  run_server "${__VERSION[1]}" &
  __SERVER_PID=$!
  backup &
  __BACKUP_PID=$!
  wait $__SERVER_PID $__BACKUP_PID
}

main











: '
[ ] ajustar e dividir função de backup para poder se utilizada de maneira standalone e permitir o backup após mudança de versão
[ ] passagem das configurações a partir de vaiaveis de ambiente dinamicas com o prefixo MINE_
[ ] adicionar suporte ao spigot
'