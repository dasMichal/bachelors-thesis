## Next Gen script thats not using briges for batman to avoid braking multicast optimizations

#!/bin/bash

# IP addresse vom bat0 nehmen die mit ./start erstellt wurde
MESH_IP=$(ip -4 addr show bat0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$MESH_IP" ]; then # if MESH_IP is empty
    echo "Error: bat0 no ip address! Run start.py first."
    exit 1
fi

# Node ID herausfinden

NODE_ID=$(echo $MESH_IP | awk -F. '{print $4}') # letzte octet is die Node ID
IP_BASE=$(echo $MESH_IP | awk -F. '{print $1"."$2"."$3}') # erste drei octets

echo "Node ID: ${NODE_ID} | Mesh IP: ${MESH_IP}"

# Using 10.10.X.1 to stay off the 192.168.10.x mesh backbone
LOCAL_IP="10.10.${NODE_ID}.1"
DHCP_START="10.10.${NODE_ID}.100"
DHCP_END="10.10.${NODE_ID}.200"


# SoftAP (Hotspot) mit hostapd starten 5Ghz
sudo hostapd -B /etc/hostapd/hostapd.conf > /dev/null 2>&1


# Bridge erstellen & konfigurieren
if ip link show br0 > /dev/null 2>&1; then
    sudo ip link set br0 down
    sudo ip link del br0
fi
sudo ip link add name br0 type bridge

echo "Bridge br0 erstellt"

# Add Ports 
# SoftAP finden mit regex  using regex . Ignoriere bat0 und lo und wlan0 (HaLow adapter)
AP_IFACE=$(ls /sys/class/net | grep -E '^(wlan[^0]|wlx|onboard)' | grep -v bat | head -1) # I LOVE REGEXS <3
if [ -z "$AP_IFACE" ]; then
    echo "Warning: No SoftAP interface found! bridge empty."
else
    echo "Adding SoftAP interface: ${AP_IFACE}"
    ip link set dev $AP_IFACE master br0
fi


echo "Configuring multicast optimizations on br0"

#sudo ip link set br0 type bridge mcast_snooping 1
#sudo ip link set br0 type bridge mcast_querier 1
#sudo ip link set br0 type bridge mcast_query_use_ifaddr 1
#sudo ip link set br0 type bridge mcast_stats_enabled 1
#sudo ip link set br0 type bridge mcast_igmp_version 3
#sudo ip link set br0 type bridge mcast_last_member_interval 100  # 1 Sekunde

sudo ip addr flush dev br0
sudo ip addr add ${LOCAL_IP}/24 dev br0
#sudo ip addr add ${LOCAL_IP}/24 dev $AP_IFACE
sudo ip link set br0 up


# NAT einstellungen 
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.br0.rp_filter=0
sudo sysctl -w net.ipv4.conf.bat0.rp_filter=0
#echo 2 | sudo tee /sys/class/net/br0/bridge/multicast_router

# Optional: Ensure TTL is high enough to cross the bridge AND the mesh
#sudo iptables -t mangle -A PREROUTING -i br0 -j TTL --ttl-set 64
sudo iptables -t mangle -A PREROUTING -i br0 -d 224.0.0.0/4 -j TTL --ttl-set 4
sudo iptables -t mangle -A PREROUTING -i bat0 -d 224.0.0.0/4 -j TTL --ttl-set 4


sudo ip route add 10.10.5.0/24 via 192.168.10.5 dev bat0
sudo ip route add 10.10.4.0/24 via 192.168.10.4 dev bat0
sudo ip route add 10.10.3.0/24 via 192.168.10.3 dev bat0
sudo ip route add 10.10.2.0/24 via 192.168.10.2 dev bat0
sudo ip route add 192.168.1.0/24 via 192.168.10.3 dev bat0

# start dnsmasq für SoftAp DHCP
cat > /tmp/dnsmasq-manet.conf <<EOF
interface=br0
bind-interfaces

#listen-address=${LOCAL_IP}

dhcp-range=${DHCP_START},${DHCP_END},255.255.255.0,12h
dhcp-option=3,${LOCAL_IP}
dhcp-option=6,8.8.8.8
EOF

echo "Locading dnsmasq configuration:"
sudo cat /tmp/dnsmasq-manet.conf


sudo killall dnsmasq 2>/dev/null
sudo dnsmasq -C /tmp/dnsmasq-manet.conf

sudo systemctl restart smcroute


echo "Node ${NODE_ID} configured"
echo "Bridge: ${LOCAL_IP}/24"
echo "DHCP Range: ${DHCP_START} - ${DHCP_END}"