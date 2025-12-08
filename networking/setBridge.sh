#!/bin/bash


# Get current network info

# Get IP address of eth0 
$IP_ADDR=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
# Get Gateway IP Address
$GATEWAY=$(ip route | grep default | awk '{print $3}')
echo "Current IP Address on eth0: $IP_ADDR"
echo "Current Gateway: $GATEWAY"

# Create Bridge

echo " Creating bridge br0"
sudo ip link add name br0 type bridge

# Add Interfaces

echo " Adding eth0 and bat0 to bridge br0"
sudo ip link set dev eth0 master br0
sudo ip link set dev bat0 master br0

# Clone MAC from Ethernet interface

echo " Cloning MAC address from eth0 to br0"
ETH_MAC=$(cat /sys/class/net/eth0/address)
echo " Ethernet MAC Address: $ETH_MAC"
sudo ip link set dev br0 address $ETH_MAC

# Bring interfaces UP  -- no IPs on them 

echo " Bringing up interfaces eth0, bat0"
sudo ip link set dev eth0 up
sudo ip link set dev bat0 up
sudo ip addr flush dev eth0
sudo ip addr flush dev bat0

# Move IP to Bridge (or use DHCP)
# Static IP method (safest for server/gateway):

echo " Assigning IP address $IP_ADDR to br0" 
#sudo ip addr add 192.168.178.130/24 dev br0
sudo ip addr add $IP_ADDR/24 dev br0
sudo ip link set dev br0 up
# Set default route via gateway 
sudo ip route add default via 192.168.178.1 dev br0
