#!/bin/bash

# Detect sudo requirement
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi


# Allow user to specify interface, otherwise auto-detect
ETH_IFACE="${1:-}"
#Grab IP from bat0 automatically only after start.py has run and assigned an IP to bat0
MESH_IP=$(ip -4 addr show bat0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$MESH_IP" ]; then # if MESH_IP is empty
    echo "[-] Error: bat0 has no IP address! Run start.py first."
    exit 1
fi



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

echo "  Configuring multicast optimizations for gateway..."

sudo ip link set br0 type bridge mcast_snooping 1
sudo ip link set br0 type bridge mcast_querier 1
sudo ip link set br0 type bridge mcast_query_use_ifaddr 1
sudo ip link set br0 type bridge mcast_stats_enabled 1
sudo ip link set br0 type bridge mcast_igmp_version 3

echo "  Multicast querier and snooping enable



# Add Interfaces

echo " Adding $ETH_IFACE and bat0 to bridge br0"
sudo ip link set dev "$ETH_IFACE" master br0
sudo ip link set dev bat0 master br0

# Clone MAC from Ethernet interface to Bridge

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

sudo ip addr add "$IP_ADDR/24" dev br0 # Network IP on the bridge
sudo ip addr add "$MESH_IP/24" dev br0 #so we hava also a Mesh local IP on the bridge
sudo ip link set dev br0 up
# Set default route via gateway 
sudo ip route add default via "$GATEWAY" dev br0

# Announce Gateway via batman
sudo batctl gw_mode server

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Enable NAT for mesh network
sudo iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o br0 -j MASQUERADE
# Allow forwarding between mesh (bat0) and external interface ($ETH_IFACE)
sudo iptables -A FORWARD -i bat0 -o "$ETH_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i "$ETH_IFACE" -o bat0 -j ACCEPT

sudo alfred -i br0 -b bat0 -m > /dev/null 2>&1 & # start alfred silent in the background because hes yapping 

AlfredKeyGateway=69

setGateway()
{
    echo -n "$MESH_IP" | sudo alfred -s $AlfredKeyGateway
    echo "[GATEWAY] Published gateway IP to Alfred: $MESH_IP"
    sleep 300

}

# Run gateway check immediately
setGateway

# Run gateway check every 5 minutes in background
while true; do
    sleep 300  # 5 minutes = 300 seconds
    setGateway
done &