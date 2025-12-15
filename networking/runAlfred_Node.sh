sudo alfred -i br0 -b bat0  > /dev/null 2>&1 & # Start alfred silent in background

AlfredKeyGateway=69


# Function to check and update gateway
checkGateway() {
    GATEWAY_IP=$(sudo alfred -r $AlfredKeyGateway | grep -oP '"\d+(\.\d+){3}"' | tr -d '"')
    oldGateway=$(ip route | grep default | awk '{print $3}')
    if [ -z "$GATEWAY_IP" ]; then
        echo "[-] No gateway announced via Alfred. Clients will have no internet."
        # setting back to old gateway if Alfred does not announce any gateway
        if [ -n "$oldGateway" ]; then
            echo "[*] Reverting to old gateway: $oldGateway"
            sudo ip route replace default via $oldGateway dev br0
    elif [ "$GATEWAY_IP" == "$oldGateway" ]; then
        echo "[*] Gateway unchanged: $GATEWAY_IP"
    
        
    else
        echo "[+] Gateway from Alfred: $GATEWAY_IP"
        sudo ip route replace default via $GATEWAY_IP dev br0
    fi
}

# Run gateway check immediately
checkGateway

# Run gateway check every 5 minutes in background
while true; do
    sleep 300  # 5 minutes = 300 seconds
    checkGateway
done &