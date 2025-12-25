#!/bin/bash

systemctl stop NetworkManager.service
systemctl stop wpa_supplicant.service
systemctl stop igmpproxy.service
batctl ra BATMAN_V

/home/michal/nrc_pkg/script/start.py 4 0 EU 1 192.168.10.4
/home/michal/nrc_pkg/script/ngtest2.sh

echo "Mesh Online"