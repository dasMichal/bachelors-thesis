#Stop local DHCP 
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq

#Create Bridge
sudo ip link add name br0 type bridge

#Add Interfaces (SoftAP +HaLow wlan0)
sudo ip link set dev wlx168811c373b8 master br0
sudo ip link set dev bat0 master br0

#Bring all up
sudo ip link set dev wlx168811c373b8 up
sudo ip link set dev bat0 up
sudo ip link set dev br0 up

#IP for Pi Zero itself (optional, for SSH management)
sudo ip addr add 192.168.178.74/24 dev br0
