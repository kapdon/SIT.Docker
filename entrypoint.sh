#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

SIT_VERSION="${SIT:=latest}"

# perform one-time server setup if no version file is found
if [ ! -e "/opt/server/version" ]; then
  echo "No version file found, running first-time setup..."
  source /opt/setup.sh
  sit_setup
  echo "Version $SIT_VERSION installed."
  echo "$SIT_VERSION" > /opt/server/version
fi

exec "$@"
