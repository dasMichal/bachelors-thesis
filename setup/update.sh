#!/bin/bash

#get user name 
USER_NAME=$(whoami)

if [ -d "/home/$USER_NAME/nrc_pkg_bk" ]; then
 echo "Remove backup folder"
 rm -rf /home/$USER_NAME/nrc_pkg_bk
fi
if [ -d "/home/$USER_NAME/nrc_pkg" ]; then
 echo "Backup previous package"
 mv /home/$USER_NAME/nrc_pkg /home/$USER_NAME/nrc_pkg_bk
fi
sleep 1

echo "Copy new package"
echo "apply nrc_pkg "
cp -r ./nrc_pkg/  /home/$USER_NAME/nrc_pkg/

echo "Change mode"
cd /home/$USER_NAME/nrc_pkg
sudo chmod -R 755 *
sudo chmod -R 777 /home/$USER_NAME/nrc_pkg/script/*
sudo chmod -R 777 /home/$USER_NAME/nrc_pkg/sw/firmware/copy
sleep 1

echo "Done"