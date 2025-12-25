sudo alfred -i br0 -b bat0 -m > /dev/null 2>&1 & # start alfred silent in the background because hes yapping 

MESH_IP=$(ip -4 addr show bat0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
AlfredKeyGateway=69
SleepAmount=100

sleep 5 
setGateway()
{
    echo -n "$MESH_IP" | sudo alfred -s $AlfredKeyGateway
    echo "[GATEWAY] Published gateway IP to Alfred: $MESH_IP"
    sleep $SleepAmount

}

# Run gateway check immediately
setGateway

# Run gateway check every 2 minutes in background
while true; do
    sleep $SleepAmount  # 2 minutes
    setGateway
done