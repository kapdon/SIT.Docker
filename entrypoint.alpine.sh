#!/bin/ash

# Copyright 2024 StayInTarkov
# Use of this source code is governed by an MIT
# license that can be found in the LICENSE file.

# Read the existing version from the version file (if it exists)
EXISTING_VERSION=$(cat /opt/server/version 2>/dev/null)
SIT_VERSION=$(cat /opt/srv/user/mods/SITCoop/version 2>/dev/null)

# Grab user ENV input if exists else default
HEADLESS=${HEADLESS:-true}
UPDATE=${UPDATE:-false}
SPT_IP=${SPT_IP:-0.0.0.0}
SPT_BACKEND_IP=${BACKEND_IP:-$(curl -s4 ipv4.icanhazip.com)}
NEW_SERVER_NAME=${SERVER_NAME:-SIT $SIT_VERSION}

#DBUG
echo "DEBUG build: $buildver, HEADLESS: $HEADLESS, UPDATE: $UPDATE"

echo "Stay In Tarkov Docker"
echo "github.com/StayInTarkov/SIT.Docker"

sit_setup() {
  start=$(date +%s)
  echo "Started copying files to your volume/directory.. Please wait."
  cp -r /opt/srv/* /opt/server/
  rm -r /opt/srv
  end=$(date +%s)

  echo "Files copied to your machine in $(($end-$start)) seconds."
  echo "Starting the server to generate all the required files"
  cd /opt/server
  chown $(id -u):$(id -g) ./* -Rf

  echo "SPT_IP: $SPT_IP, updating http.json"
  sed -ir 's/"ip": .*,/"ip": "'$SPT_IP'",/' /opt/server/Aki_Data/Server/configs/http.json

  echo "BACKEND_IP: $SPT_BACKEND_IP, updating http.json"
  sed -ir 's/"backendIp": .*,/"backendIp": "'$SPT_BACKEND_IP'",/' /opt/server/Aki_Data/Server/configs/http.json

  sed -i "s/\"serverName\": \".*\"/\"serverName\": \"$NEW_SERVER_NAME\"/" /opt/server/Aki_Data/Server/configs/core.json
  MODIFIED_NAME=$(sed -n 's/.*"serverName": "\([^"]*\)".*/\1/p' /opt/server/Aki_Data/Server/configs/core.json)
  echo "Server Name: $MODIFIED_NAME, updating core.json"

  # remove previous install.log n boot server once in bg to generate files.
  rm /opt/server/install.log
  screen -L -Logfile "install.log" -d -m -S AkiServer ./Aki.Server.exe
	while [ ! -f "/opt/server/user/mods/SITCoop/config/coopConfig.json" ]; do
		sleep 10  # sleep till coopConfig.json is generated
	done
	screen -S AkiServer -X "^C" # kill Aki.Server
}

# perform one-time server setup if no version file is found
if [ -d "/opt/srv" ]; then
  if [ ! -e "/opt/server/version" ]; then
    echo "No version file found, running first-time setup..."

    sit_setup

    # will prevent setup from running again
    echo "saving $SIT_VERSION to /opt/server/version"
    printf "%s" "$SIT_VERSION" > /opt/server/version
    echo "SIT Version installed: $(cat /opt/server/version)"

# new SIT version found, reinstall if UPDATE flag present, else print version diff.
  elif [ "$EXISTING_VERSION" != "$SIT_VERSION" ]; then
    echo "new SIT version: $SIT_VERSION"
    echo "existing SIT version: $EXISTING_VERSION"
    if [ "$UPDATE" = true ]; then
      echo "UPDATE flag true, installing update..."
      sit_setup
      # will prevent setup from running again
      echo "saving $SIT_VERSION to /opt/server/version"
      printf "%s" "$SIT_VERSION" > /opt/server/version
      echo "SIT Version updated: $(cat /opt/server/version)"
    else
      echo "UPDATE flag false, use -e UPPDATE=true if updating."
      echo "Starting SIT Server in 5 seconds.."
      sleep 5
    fi
  fi
# quit if not headless
  if [ "$HEADLESS" = false ]; then
    echo "SIT.Docker setup is now complete!"
    echo "You can configure and start your container."
    exit 0
  fi
fi

# delete js n js.map files from existing mods (ignore SITCoop) and make sure server generates them fresh to prevent errors from copying windows artifact files.
echo "clearing mod *.js *.js.map artifact cache..."
find /opt/server/user/mods -type d -name "SITCoop" -prune -o \
-type f \( -name "*.js" -o -name "*.js.map" \) \
-exec sh -c 'for x; do ts="${x%.*}.ts"; [ -f "$ts" ] && rm "$x"; done' _ {} +

# continue to run whichever command was passed in (typically running Aki.Server.exe)
exec "$@"
