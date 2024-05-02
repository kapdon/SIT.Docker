#!/bin/bash
BACKEND_IP=${SIT_BACKEND_IP:-127.0.0.1}
# BACKEND_PORT=${SIT_BACKEND_PORT:-6969}

echo "StayInTarkov Docker by bullet"

if [ -d "/opt/srv" ]; then
	start=$(date +%s)
	echo "Started copying files to your volume/directory.. Please wait."
	cp -r /opt/srv/* /opt/server/
	rm -r /opt/srv
	touch /opt/server/delete_me
	end=$(date +%s)
	
	echo "Files copied to your machine in $(($end-$start)) seconds."
	echo "Starting the server to generate all the required files"
	cd /opt/server
	chown $(id -u):$(id -g) ./* -Rf
	sed -i.bak 's/"autoInstallModDependencies": false/"autoInstallModDependencies": true/' /opt/server/Aki_Data/Server/configs/core.json
	screen -L -Logfile "AkiServer.log" -d -m -S AkiServer ./Aki.Server.exe
	while [ ! -f "/opt/server/user/mods/SITCoop/config/coopConfig.json" ]; do
		sleep 5  # sleep till coopConfig.json is generated
	done
	screen -S AkiServer -X "^C" # kill Aki.Server
	# websocket + ip fix
	sed -i 's/127.0.0.1/0.0.0.0/g' /opt/server/Aki_Data/Server/configs/http.json
	# grab SPT port from AKI's http.json in case it has changed.
	SPT_PORT=`sed -n 's/.*"port": \([0-9]*\),.*/\1/p' /opt/server/Aki_Data/Server/configs/http.json`
	# websocket overwrite for SIT.
	sed -i.bak 's/"useMessageWSUrlOverride": false/"useMessageWSUrlOverride": true/' /opt/server/user/mods/SITCoop/config/coopConfig.json
	sed -i.bak "s/\"messageWSUrlOverride\": \"[^\"]*\"/\"messageWSUrlOverride\": \"$BACKEND_IP:$SPT_PORT\"/" /opt/server/user/mods/SITCoop/config/coopConfig.json
	echo "Set SIT coopConfig WSUrlOverride to $BACKEND_IP:$SPT_PORT."
	echo "Follow the instructions to proceed!"
	exit 0
fi

if [ -e "/opt/server/delete_me" ]; then
	echo "Error: Safety file found. Exiting."
	echo "Please follow the instructions."
	exit 1
fi

cd /opt/server && ./Aki.Server.exe

echo "Exiting."
exit 0
