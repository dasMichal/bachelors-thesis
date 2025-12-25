#!/usr/bin/env python3
import subprocess
import os
import sys
import time

#get user name
USER_NAME = os.getenv("USER")
#or get the user name by regex from home path
#home_path = os.path.expanduser("~")
#match = re.search(r'/home/([^/]+)', home_path)
#if match:
#    USER_NAME = match.group(1)

def main(interface, gateway=False, mobile=False):
    if not interface:
        print("No interface IP . Please provide one with --ip")
        sys.exit(1)
    


    print(f"Starting HaLow MeshPoint setup for user: {USER_NAME}")
    print("Stopping wpa_supplicant service to avoid conflicts with onboard Wi-Fi chip")


    os.system("sudo systemctl stop wpa_supplicant  ")
    #os.system("sudo systemctl stop NetworkManager ")
    
    os.system("python ~/nrc_pkg/scripts/start.py 4 0 EU 1 "+interface+" &")
    # wait a bit for the script to start and get settled 
    print("Waiting for MeshPoint to initialize...")
    time.sleep(20)
    print("MeshPoint should be initialized now.")
    if gateway:
        print ("Setting up as Gateway Node...")
        os.system("sudo ~/bachelors-thesis/networking/setBridge.sh")
    if mobile:
        print ("Setting up as Mobile Node with WiFi SoftAP...")
        os.system("sudo ~/bachelors-thesis/networking/bridgeWLAN-DHCP.sh")
    


# --- CLI ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MulticastVoiceApp")
    parser.add_argument("--ip", help="Interface IP address", type=str)
    parser.add_argument("--gateway", help="Sets Node as Gateway", action="store_true")
    parser.add_argument("--mobile", help="Sets node as a Mobile Node with WiFi SoftAP", action="store_true")
    
    args = parser.parse_args()

    main(interface=args.ip, gateway=args.gateway, mobile=args.mobile)
