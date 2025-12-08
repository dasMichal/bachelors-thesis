#!/bin/bash

# Allow user to specify interface, otherwise auto-detect
ETH_IFACE="${1:-}"

# Auto-detect active Ethernet interface if not specified
if [ -z "$ETH_IFACE" ]; then
    echo "No interface specified, auto-detecting..."
    # Find active Ethernet interface (excluding loopback, wireless, and virtual interfaces)
    ETH_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|en)' | grep -v '@' | head -n 1)
    
    if [ -z "$ETH_IFACE" ]; then
        echo "Error: No active Ethernet interface found"
        exit 1
    fi
    echo "Auto-detected interface: $ETH_IFACE"
else
    echo "Using specified interface: $ETH_IFACE"
fi

# Verify interface exists and is up
if ! ip link show "$ETH_IFACE" &> /dev/null; then
    echo "Error: Interface $ETH_IFACE does not exist"
    exit 1
fi

# Get current network info
# Get IP address of the interface
IP_ADDR=$(ip addr show "$ETH_IFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
# Get Gateway IP Address
GATEWAY=$(ip route | grep default | awk '{print $3}')
echo "Current IP Address on $ETH_IFACE: $IP_ADDR"
echo "Current Gateway: $GATEWAY"

# Create Bridge

echo " Creating bridge br0"
sudo ip link add name br0 type bridge

# Add Interfaces

echo " Adding $ETH_IFACE and bat0 to bridge br0"
sudo ip link set dev "$ETH_IFACE" master br0
sudo ip link set dev bat0 master br0

# Clone MAC from Ethernet interface

echo " Cloning MAC address from $ETH_IFACE to br0"
ETH_MAC=$(cat /sys/class/net/"$ETH_IFACE"/address)
echo " Ethernet MAC Address: $ETH_MAC"
sudo ip link set dev br0 address "$ETH_MAC"

# Bring interfaces UP  -- no IPs on them 

echo " Bringing up interfaces $ETH_IFACE, bat0"
sudo ip link set dev "$ETH_IFACE" up
sudo ip link set dev bat0 up
sudo ip addr flush dev "$ETH_IFACE"
sudo ip addr flush dev bat0

# Move IP to Bridge (or use DHCP)
# Static IP method (safest for server/gateway):

echo " Assigning IP address $IP_ADDR to br0" 
#sudo ip addr add 192.168.178.130/24 dev br0
sudo ip addr add "$IP_ADDR/24" dev br0
sudo ip link set dev br0 up
# Set default route via gateway 
sudo ip route add default via "$GATEWAY" dev br0
