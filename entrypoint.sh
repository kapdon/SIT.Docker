#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# sets SIT_VERSION to the value of the SIT environment variable, or "latest" if not set
SIT_VERSION="${SIT:=latest}"

echo "Stay In Tarkov Docker"
echo "github.com/StayInTarkov"

# perform one-time server setup if no version file is found
if [ ! -e "/opt/server/version" ]; then
  echo "No version file found, running first-time setup..."

  source /opt/setup.sh
  sit_setup

  echo "Version $SIT_VERSION installed."
  # will prevent setup from running again
  echo "$SIT_VERSION" > /opt/server/version
  exit 0
fi

# continue to run whichever command was passed in (typically running Aki.Server.exe)
exec "$@"
