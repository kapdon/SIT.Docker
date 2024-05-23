#!/bin/ash

# Copyright 2024 StayInTarkov
# Use of this source code is governed by an MIT
# license that can be found in the LICENSE file.

# Read the existing version from the version file (if it exists)
EXISTING_VERSION=$(cat /opt/server/version 2>/dev/null)
SIT_VERSION=$(cat /opt/srv/user/mods/SITCoop/version 2>/dev/null)

# Grab user ENV input if exists else default
HEADLESS=${HEADLESS:-true}
FORCE=${FORCE:-false}
SPT_IP=${SPT_IP:-0.0.0.0}
SPT_BACKEND_IP=${BACKEND_IP:-$(curl -s4 ipv4.icanhazip.com)}
SPT_LOG_REQUESTS=${LOG_REQUESTS:-true}
NEW_SERVER_NAME=${SERVER_NAME:-SIT $SIT_VERSION}
SPT_CONFIG_PATH=Aki_Data/Server/config
#SPT_CONFIG_PATH=SPT_Data/Server/config

#DBUG
echo "DEBUG build: $buildver, HEADLESS: $HEADLESS, BREAKKING: $BREAKING, FORCE: $FORCE"

echo "Stay In Tarkov Docker"
echo "github.com/StayInTarkov/SIT.Docker"

sit_setup() {
  start=$(date +%s)
  echo "Started copying files to your volume/directory.. Please wait."
  cp -r /opt/srv/* /opt/server/
  rm -rf /opt/srv
  end=$(date +%s)

  echo "Files copied to your machine in $(($end-$start)) seconds."
  echo "Starting the server to generate all the required files"
  cd /opt/server
  chown $(id -u):$(id -g) ./* -Rf

  sed -ir 's/"ip": .*,/"ip": "'$SPT_IP'",/' /opt/server/$SPT_CONFIG_PATH/http.json
  MOD_IP=$(sed -n 's/.*"ip": "\(.*\)",/\1/p' /opt/server/$SPT_CONFIG_PATH/http.json)
  echo "SPT_IP: $MOD_IP, updating http.json"

  sed -ir 's/"backendIp": .*,/"backendIp": "'$SPT_BACKEND_IP'",/' /opt/server/$SPT_CONFIG_PATH/http.json
  MOD_BIP=$(sed -n 's/.*"backendIp": "\(.*\)",/\1/p' /opt/server/$SPT_CONFIG_PATH/http.json)
  echo "BACKEND_IP: $MOD_BIP, updating http.json"

  sed -ir "s/\"serverName\": \".*\"/\"serverName\": \"$NEW_SERVER_NAME\"/" /opt/server/$SPT_CONFIG_PATH/core.json
  MODIFIED_NAME=$(sed -n 's/.*"serverName": "\([^"]*\)".*/\1/p' /opt/server/$SPT_CONFIG_PATH/core.json)
  echo "serverName: $MODIFIED_NAME, updating core.json"

  sed -ir 's/"logRequests": .*,/"logRequests": '"$SPT_LOG_REQUESTS"',/' /opt/server/$SPT_CONFIG_PATH/http.json
  MOD_LOGQ=$(sed -n 's/.*"logRequests": \(.*\),/\1/p' /opt/server/$SPT_CONFIG_PATH/http.json)
  echo "logRequests: $MOD_LOGQ, updating http.json"

  # remove previous install.log n boot server once in bg to generate files.
  rm /opt/server/install.log
  screen -L -Logfile "install.log" -d -m -S SPTServer ./Aki.Server.exe
  # 3.9 upcoming
  # screen -L -Logfile "install.log" -d -m -S AkiServer ./SPT.Server.exe
	while [ ! -f "/opt/server/user/mods/SITCoop/config/coopConfig.json" ]; do
		sleep 10  # sleep till coopConfig.json is generated
	done
  # kill Aki.Server
  pid=$(screen -ls | grep 'SPTServer' | awk '{print $1}' | cut -d '.' -f 1)
  kill -9 "$pid"
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
	# set headless to false only for inital set up.
	HEADLESS = false

# new SIT version found, always reinstall update unless BREAKING flag present, else print version diff.
  elif [ "$EXISTING_VERSION" != "$SIT_VERSION" ] || [ "$FORCE" = true ]; then
    echo "new SIT version: $SIT_VERSION"
    echo "existing SIT version: $EXISTING_VERSION"
    if [ "$BREAKING" = false ]; then
      echo "SIT Update found, no breaking change detected, installing update..."
      sit_setup
      # will prevent setup from running again
      echo "saving $SIT_VERSION to /opt/server/version"
      printf "%s" "$SIT_VERSION" > /opt/server/version
      echo "SIT Version updated: $(cat /opt/server/version)"
    elif [ "$FORCE" = true ]; then
      echo "Breaking SIT Update found, FORCE flag set, installing update..."
      sit_setup
      # will prevent setup from running again
      echo "saving $SIT_VERSION to /opt/server/version"
      printf "%s" "$SIT_VERSION" > /opt/server/version
      echo "SIT Version updated: $(cat /opt/server/version)"
    else
	  echo "WARNING: breaking change found in SIT update"
	  echo "please check release notes to ensure proper steps are taken"
      echo "use -e FORCE=true to update server..."
      echo "FORCE flag not set, update aborted."
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
