#!/bin/bash

# start hostap with Access Point 
sudo hostapd -B /etc/hostapd/hostapd.conf > /dev/null 2>&1



#Grab IP from bat0 automatically only after start.py has run and assigned an IP to bat0
MESH_IP=$(ip -4 addr show bat0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$MESH_IP" ]; then # if MESH_IP is empty
    echo "[-] Error: bat0 has no IP address! Run start.py first."
    exit 1
fi



# Extract the last octet (z.b. 2 from 192.168.10.2) to determine NODE_ID 
NODE_ID=$(echo $MESH_IP | awk -F. '{print $4}') # get last octet
IP_BASE=$(echo $MESH_IP | awk -F. '{print $1"."$2"."$3}') # get first three octets 

# Calculate DHCP Range: .X0 - .X9 (z.b Node 2 serves .20-.29)
DHCP_START="${IP_BASE}.${NODE_ID}0" 
DHCP_END="${IP_BASE}.${NODE_ID}9"

echo "[*] Detected Node IP: ${MESH_IP} (ID: ${NODE_ID})"

# Create Bridge
sudo ip link add name br0 type bridge

echo "[*] Configuring multicast optimizations..."

# Aktiviere Multicast Snooping (lernt welche Ports welche Gruppen wollen)
sudo ip link set br0 type bridge mcast_snooping 1

# Aktiviere IGMP Querier (sendet periodische IGMP Queries)
sudo ip link set br0 type bridge mcast_querier 1

# Nutze Bridge-IP als Querier Source Address
sudo ip link set br0 type bridge mcast_query_use_ifaddr 1

# Aktiviere Multicast-Statistiken für Debugging
sudo ip link set br0 type bridge mcast_stats_enabled 1

# IGMPv3 für bessere Multicast-Effizienz (ATAK & Codec2 kompatibel)
sudo ip link set br0 type bridge mcast_igmp_version 3

# Optional: Last-Member Query Intervall reduzieren (schnelleres Leave)
sudo ip link set br0 type bridge mcast_last_member_interval 100  # 1 Sekunde

echo "[+] Multicast snooping & querier enabled on br0"




# Add Ports 
# Detect SoftAP interface automatically (wlan0, wlx...) using regex
# Exclude bat0 and lo and wlan0 (HaLow adaper)
AP_IFACE=$(ls /sys/class/net | grep -E '^(wlan[^0]|wlx|onboard)' | grep -v bat | head -1) # I LOVE REGEXS <3
if [ -z "$AP_IFACE" ]; then
    echo "[-] Warning: No SoftAP interface found! creating bridge with bat0 only."
else
    echo "[*] Adding SoftAP interface: ${AP_IFACE}"
    ip link set dev $AP_IFACE master br0
fi

ip link set dev bat0 master br0

# Move IP from bat0 to br0 #We must flush bat0 and put the IP on br0 for the bridge to work locally
ip addr flush dev bat0
ip addr add ${MESH_IP}/24 dev br0
ip link set dev br0 up

# Configure & Start Local DHCP (Dnsmasq)
cat > /tmp/dnsmasq-mesh.conf <<EOF
interface=br0
dhcp-range=${DHCP_START},${DHCP_END},255.255.255.0,12h
dhcp-option=3,${MESH_IP}  # Gateway = Me
dhcp-option=6,8.8.8.8     # DNS
EOF

killall dnsmasq 2>/dev/null
dnsmasq -C /tmp/dnsmasq-mesh.conf
echo "[+] Bridge UP. IP: ${MESH_IP}. DHCP Range: ${DHCP_START}-${DHCP_END}"
sudo ip route replace default via 192.168.10.3 dev br0 ## 


sudo batctl gw_mode client
echo "[*] Set batman-adv gateway mode to client."

#sudo alfred -i br0 -b bat0  > /dev/null 2>&1 & # Start alfred silent in background

#AlfredKeyGateway=69


#sudo ./runAlfred.sh & 



# Function to check and update gateway
checkGateway() {
    GATEWAY_IP=$(sudo alfred -r $AlfredKeyGateway | grep -oP '"\d+(\.\d+){3}"' | tr -d '"')

    if [ -z "$GATEWAY_IP" ]; then
        echo "[-] No gateway announced via Alfred. Clients will have no internet."

    else
        echo "[+] Gateway from Alfred: $GATEWAY_IP"
        sudo ip route replace default via $GATEWAY_IP dev br0
    fi
}

# Run gateway check immediately
#checkGateway

# Run gateway check every 5 minutes in background
#while true; do
#    sleep 300  # 5 minutes = 300 seconds
#    checkGateway
#done &



