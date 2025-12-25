#!/bin/bash

echo "Setup script for ALFA AH (HaLow)."

# Detect sudo requirement
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi


is64bit=$(getconf LONG_BIT)


check_kernel_version() {
    echo "Checking kernel version..."
    kernel_version=$(uname -r)
    required_version="6.1.71-v8+"
    echo "Current kernel version: $kernel_version"
    if [ "$kernel_version" != "$required_version" ]; then
        echo "Warning: Kernel version mismatch. Required: $required_version, Found: $kernel_version"
        echo "Please update your kernel to the required version."
        echo "Would you like to downgrade now? (y/n)"
        read -r response
        if [[ "$response" == "y" || "$response" == "Y" ]];
        then
            downgrade_kernel
        else
            echo "Exiting setup due to kernel version mismatch."
            exit 1
        fi
        exit 1
    else
        echo "Kernel version matches the required version."
    fi


}


downgrade_kernel() {
    echo "Downgrading kernel to required version..."
    $SUDO rpi-update 23a2c11685ae13d37b89b5b56a522944e7d96317
    $SUDO wget https://raw.githubusercontent.com/RPi-Distro/rpi-source/master/rpi-source -O /usr/bin/rpi-source
    $SUDO chmod +x /usr/bin/rpi-source
    rpi-source
    echo "Kernel downgraded."
}

misc_system_tweaks() {
    echo "Applying miscellaneous system tweaks..."
    # Placeholder for any additional tweaks
    #Add my custom aliases so i dont lose my mind 
    echo "alias cls ='clear'" >> ~/.bashrc
    sudo cp smcroute.conf /etc/smcroute.conf
    #sudo systemctl restart smcroute


    echo "System tweaks applied."

    
}

update_software() {
    echo "Updating software components..."
    echo "Updating repository"
    $SUDO apt update
    echo "Installing required packages"
    $SUDO apt install -y build-essential dkms git make dnsmasq hostapd device-tree-compiler iptables batctl alfred bridge-utils bc bison flex libssl-dev libncurses5-dev iperf3 picocom screen traceroute smcroute
    echo "Software components updated."
}

set_module_autoload() {
    echo "Setting up mac80211, batman-adv to load on boot..."
    sudo echo -e "mac80211 \nbatman-adv\ncfg80211" > halow_mesh.conf

}



clone_nrc_repository() {
    echo "--------------------------------"
    echo "Cloning HaLow driver repository"
    cd ~
    if [ ! -d nrc7292_sw_pkg ]; then
        git clone https://github.com/dasMichal/nrc7292_sw_pkg.git || { echo "Git clone failed"; exit 1; }
    fi

    
}


setup_nrc_software() {

    cd ~/nrc7292_sw_pkg/package/evk/sw_pkg || { echo "Path missing"; exit 1; }
    $SUDO chmod +x update.sh
    ./update.sh
}


build_new_nrc_kernel_module() {
    echo "--------------------------------"
    echo "Building HaLow kernel module..."
    cd ~/nrc7292_sw_pkg/package/src/nrc || { echo "Driver source path missing"; exit 1; }
    make clean
    echo "Building driver"
    make
    echo "Build finished."

    kernel_version=$(uname -r)
    build_version=$(modinfo nrc.ko | awk '/vermagic/ {print $2}')
    if [ "$kernel_version" != "$build_version" ]; then
        echo "Mismatch: build ($build_version) vs kernel ($kernel_version)"
        echo "Install matching kernel headers: $SUDO apt install linux-headers-$(uname -r)"
        exit 1
    else
        echo "Version matches."
        #mkdir -p ~/nrc_pkg/sw/driver
        cp -b nrc.ko ~/nrc7292_sw_pkg/package/evk/sw_pkg/nrc_pkg/sw/driver/ # copy to driver folder that will be copied to nrc_pkg at the end of setup
    fi

    # Load dependencies
    if ! lsmod | grep -q mac80211; then
        $SUDO modprobe mac80211
    fi
    if ! lsmod | grep -q cfg80211; then
        $SUDO modprobe cfg80211
    fi

    if [ "$is64bit" -eq 64 ]; then
        echo "building cli_app for 64bit"
        cd ~/nrc7292_sw_pkg/package/src/cli_app || { echo "cli_app source path missing"; exit 1; }
        make clean
        make
        cp -b cli_app ~/nrc7292_sw_pkg/package/evk/sw_pkg/nrc_pkg/script/ # copy to script folder that will be copied to nrc_pkg at the end of setup

    else
        echo "OK"
        #$SUDO insmod ~/nrc_pkg/sw/driver/nrc.ko
    fi


}

update_python_scripts() {
    echo "--------------------------------"
    echo "Updating Python shebangs"
    cd ~/nrc7292_sw_pkg/package/evk/sw_pkg/nrc_pkg/script/ || return
    sed -i '1s|^.*$|#!/usr/bin/env python3|' start.py
    sed -i '1s|^.*$|#!/usr/bin/env python3|' stop.py
}

create_device_tree() {
    echo "Downloading device tree"
    cd ~/nrc7292_sw_pkg/dts || { echo "dts path missing"; exit 1; }
    wget -q https://sznurczak.com/halowsetup/newracom.dts -O newracom.dts
    echo "Compiling overlay"
    dtc -I dts -O dtb -o newracom.dtbo newracom.dts
    echo "Installing overlay"
    $SUDO cp newracom.dtbo /boot/firmware/overlays/
    echo -e "Add following to /boot/firmware/config.txt then reboot\n dtoverlay=disable-wifi \n dtoverlay=newracom\n"
    #echo " to /boot/firmware/config.txt then reboot."
    echo "use sudo nano /boot/firmware/config.txt to edit the file."
}

main() {
    check_kernel_version
    update_software
    set_module_autoload
    clone_nrc_repository
    build_new_nrc_kernel_module
    #update_python_scripts
    create_device_tree
    setup_nrc_software
    echo "HaLow setup completed."
    misc_system_tweaks
    set_module_autoload
    echo "Please reboot the system to apply all changes."
    #move the user to nrc_pkg folder
    cd ~/nrc_pkg || { echo "nrc_pkg path missing"; exit 1; }

}

main