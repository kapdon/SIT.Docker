#!/bin/ash

# Read the existing version from the version file (if it exists)
EXISTING_VERSION=$(cat /opt/server/version 2>/dev/null)
SIT_VERSION=$(cat /opt/srv/user/mods/SITCoop/version 2>/dev/null)

# Grab container IP and user ENV input if exists else default
SPT_IP=${CONTAINER_IP:-0.0.0.0}
SPT_BACKEND_IP=${BACKEND_IP:-127.0.0.1}
NEW_SERVER_NAME=${SERVER_NAME:-$SIT_VERSION}


echo "Stay In Tarkov Docker"
echo "github.com/StayInTarkov"

sit_setup() {
if [ -d "/opt/srv" ]; then
  start=$(date +%s)
  echo "Started copying files to your volume/directory.. Please wait."
  cp -r /opt/srv/* /opt/server/
  rm -r /opt/srv
  end=$(date +%s)

  echo "Files copied to your machine in $(($end-$start)) seconds."
  echo "Starting the server to generate all the required files"
  cd /opt/server
  chown $(id -u):$(id -g) ./* -Rf
  echo "set SPT_IP to CONTAINER_IP: $SPT_IP, updating http.json"
  sed -ir 's/"ip": .*,/"ip": "'$SPT_IP'",/' /opt/server/Aki_Data/Server/configs/http.json

  echo "BACKEND_IP: $SPT_BACKEND_IP, updating http.json"
  sed -ir 's/"backendIp": .*,/"backendIp": "'$SPT_BACKEND_IP'",/' /opt/server/Aki_Data/Server/configs/http.json

  sed -i "s/\"serverName\": \".*\"/\"serverName\": \"SIT $NEW_SERVER_NAME\"/" /opt/server/Aki_Data/Server/configs/core.json
  MODIFIED_NAME=$(sed -n 's/.*"serverName": "\([^"]*\)".*/\1/p' /opt/server/Aki_Data/Server/configs/core.json)
  echo "Server Name: $MODIFIED_NAME, updating core.json"
  # boot server once in bg to generate files.
  screen -L -Logfile "install.log" -d -m -S AkiServer ./Aki.Server.exe
	while [ ! -f "/opt/server/user/mods/SITCoop/config/coopConfig.json" ]; do
		sleep 10  # sleep till coopConfig.json is generated
	done
	screen -S AkiServer -X "^C" # kill Aki.Server
  echo "Follow the instructions to proceed!"
fi
}

# perform one-time server setup if no version file is found
if [ ! -e "/opt/server/version" ]; then
  echo "No version file found, running first-time setup..."

  sit_setup

  # will prevent setup from running again
  echo "saving $SIT_VERSION to /opt/server/version"
  printf "%s" "$SIT_VERSION" > /opt/server/version
  echo "SIT Version installed: $(cat /opt/server/version)"
  exit 0
# existing version out of date run setup again.
elif [ "$EXISTING_VERSION" != "$SIT_VERSION" ] && [ -d "/opt/srv" ]; then
  echo "new SIT version: $SIT_VERSION found"
  echo "existing SIT version: $EXISTING_VERSION outdated, regenerating files."

  sit_setup

  # will prevent setup from running again
  echo "saving $SIT_VERSION to /opt/server/version"
  printf "%s" "$SIT_VERSION" > /opt/server/version
  echo "SIT Version updated: $(cat /opt/server/version)"
  exit 0
else
  echo "existing SIT version: $EXISTING_VERSION"
  echo "no update found, starting SIT..."
fi

# delete js n js.map files from existing mods (ignore SITCoop) and make sure server generates them fresh to prevent errors from copying windows artifact files.
find /opt/server/user/mods -type d -name "SITCoop" -prune -o \
-type f \( -name "*.js" -o -name "*.js.map" \) \
-exec sh -c 'for x; do ts="${x%.*}.ts"; [ -f "$ts" ] && rm "$x"; done' _ {} +

# continue to run whichever command was passed in (typically running Aki.Server.exe)
exec "$@"
