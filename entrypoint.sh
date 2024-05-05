#!/usr/bin/env sh

install_java() {
  __PACKAGES_DIR="${PWD}"/.packages
  __JAVA="$(apk search "openjdk$1-jre*" | grep -Eo '.*(base|headless)')"
  if [ "$(cat "$__PACKAGES_DIR/java.version" 2> /dev/null)" != "$__JAVA" ]; then
    rm -f "$__PACKAGES_DIR"/*.apk
  fi
  if [ -n "$__JAVA" ]; then
    mkdir -p "$__PACKAGES_DIR" 2> /dev/null
    __DEPENDENCIES=$(apk info -R "$__JAVA")
    for i in ${__DEPENDENCIES#*:}; do
      (cd "$__PACKAGES_DIR" && apk fetch "${i%=*}")
    done
    (cd "$__PACKAGES_DIR" && apk fetch "$__JAVA")
    for i in "$__PACKAGES_DIR"/*.apk; do
      apk add --allow-untrusted "$i"
    done
  fi
  echo "$__JAVA" > "$__PACKAGES_DIR/java.version"
}

dowload_server() {
  if [ ! -e "server.jar" ] && [ ! -e "forge*.jar" ]; then
    __URI=$(echo "$1" | sed -e "s/{ID}/$2/g" | tr -d '"')
    curl -L# "$__URI" -o "server.jar"
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

run_server () {
  if [ -e "run.sh" ]; then
    "${PWD}"/run.sh nogui &
  else
    __EXEC=$(find "$PWD" -name "forge*.jar" -o -name "server.jar")
    java -Xms"$XMX" -Xmx"$XMX" -jar "$__EXEC" nogui &
  fi
}

backup(){
  __BACKUP_DIR="${PWD}"/backups
  mkdir -p "$__BACKUP_DIR" 2> /dev/null
  while true; do
    sleep "$AUTOSAVE"
    tar --exclude="backups" --exclude=".packages" -czf "$__BACKUP_DIR/mineserver-$(date "+%F-%H_%M_%S").tar.gz" .
  done
}

main() {
  __CANDIDATES=$(cat "/etc/mineserver/$LOCAL_CANDIDATES" 2> /dev/null || curl -L# "$ONLINE_CANDIDATES")
  __VERSION=$(echo "$MINE_VERSION" | cut -d "-" -f1)
  __VENDOR=$(echo "$MINE_VERSION" | cut -d "-" -f2)
  __URL=$(echo "$__CANDIDATES" | jq ".url.${__VENDOR}")
  __JAVA_VERSION=$(echo "$__CANDIDATES" | jq ".${__VERSION}.java")
  __ID=$(echo "$__CANDIDATES" | jq ".${__VERSION}.${__VENDOR}")

  install_java "$__JAVA_VERSION"

  dowload_server "$__URL" "$__ID"

  config_server "$__VENDOR"

  run_server

  backup
}

main