#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# one-time setup for SIT; only runs if the entrypoint doesn't detect an /opt/server/version file

sit_setup() {
# copied from https://github.com/stayintarkov/SIT.Docker/blob/b2c2f80eb6333314bf9ff1776e4528fe6ea74cee/bullet.sh
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
  sed -i 's/127.0.0.1/0.0.0.0/g' /opt/server/Aki_Data/Server/configs/http.json
  NODE_CHANNEL_FD= timeout --preserve-status 40s ./Aki.Server.exe </dev/null >/dev/null 2>&1
  echo "Follow the instructions to proceed!"
fi
}
