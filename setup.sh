#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

##########################################   HANDLES NEEDED PACKAGES  ##########################################
printf "Checking for needed packages..\n"
if [ $(dpkg-query -W -f='${Status}' bc 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install -y bc || (echo "bc installation failed" && exit) ;
fi

########################################## VERIFIES IF INTERFACES CAN BE RENAMED ################################
DIFACE=`route -n | grep ^0.0.0.0 | sed 's/  */ /g' | cut -d' ' -f8`
SMBIOS_V=$(dmidecode -t 0 | grep SMBIOS | tail -1 | awk '{print $2}')
if [ $(echo "$SMBIOS_V<2.6"| bc ) == 0 ]
then
  printf "${GREEN}GOOD NEWS:${NC} You can change interface naming with biosdevname. \n"
else
  printf "${RED}BAD NEWS:${NC} You can not change interface naming with biosdevname. Creating some ${RED}RULES${NC} ! \n"
  sleep 2;
  if [  "$(ls -A /etc/udev/rules.d/)" ];
  then
    printf "${RED}Rules are already present:${NC} \n"
    cat /etc/udev/rules.d/70-persistent-net.rules
    printf "\n"
    exit 0
  else
    MAC=$(ifconfig $DIFACE | grep HWaddr | awk '{print $5}')
    echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$MAC\", ATTR{dev_id}==\"0x0\", ATTR{type}==\"1\", NAME=\"eth0\""   > /etc/udev/rules.d/70-persistent-net.rules
    printf "${GREEN}Rules created:${NC} \n"
    cat /etc/udev/rules.d/70-persistent-net.rules
    printf "Reboot to verify. \n"
    exit 0
   fi
fi

########################################## HANDLES UDEV RULES ####################################################
printf "Your current interface name is : ${RED}$DIFACE${NC} \n"
printf "Cheking for udev rules.. \n"
if [  "$(ls -A /etc/udev/rules.d/70-persistent-net.rules)" ];
then
  echo "Do you wish to remove the network udev rules?"
  select yn in "Yes" "No"; do
    case $yn in
        Yes ) rm /etc/udev/rules.d/70-persistent-net.rules ; break;;
        No )  exit 0;;
    esac
  done
else
  printf "No network rules present. \n"
fi

########################################## HANDLES BIOSDEVNAME PACKET #############################################
printf "Checking biosdevname packet..\n"
sleep 2;
if [ $(dpkg-query -W -f='${Status}' biosdevname 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install -y biosdevname || (echo "biosdevname installation failed" && exit) ;
fi
printf "Package installed\n"

NIFACE=`biosdevname -i $DIFACE`
retcode=$?
if [ retcode -ne 0 ]; then
    echo "${RED}ERROR: $retcode ${NC} - Biosdevname \n"
    return retcode
fi

printf "Default interface ${RED}$DIFACE${NC} will be re-named to ${GREEN}$NIFACE${NC} \n"
sleep 2;

##########################################  HANDLES NETWORK INTERFACE FILE ########################################
if [ ! -f /etc/network/interfaces.bak ]; then
  printf "Backing up interfaces file .. \n"
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
printf "Updating /etc/network/interfaces file .. \n"
sed "s/$DIFACE/$NIFACE/g" /etc/network/interfaces.bak > /etc/network/interfaces
sleep 2;


############################################# HANDLES GRUB CONFIG #################################################
if [ ! -f /etc/default/grub.bak ]; then
    printf "Backing up /etc/default/grub.cfg into /etc/default/grub.bak \n"
    cp /etc/default/grub /etc/default/grub.bak
fi
sleep 1;
printf "Updating grub configuration .. \n"
#TODO: GRUB_CMD_LINE_DEFAULT= should be removed if already present.
sed '0,/GRUB_CMDLINE_LINUX_DEFAULT/{s/.*GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT="biosdevname=1"/}' /etc/default/grub.bak > /etc/default/grub
update-grub
grub-script-check /boot/grub/grub.cfg
retcode=$?
if [ retcode -ne 0 ]; then
    echo "${RED}ERROR: $retcode ${NC} -  Grub configuration is invalid \n"
    return retcode
fi

############################################# HANDLES NETFIX SERVICE #############################################
printf "Generating ${RED}NETFIX${NC} script .. \n"
sleep 2;
cp netfix.sh  /usr/local/bin/netfix.sh
printf "Enabling netfix service .. \n"
cp netfix.service /etc/systemd/system/netfix.service
systemctl enable netfix.service
printf "Done \n"
printf "You should: \n 1- Check \n 2- reboot \n 3- Disable netfix service. /n :) \n"
printf "To disable Netfix after reboot issue the command: systemctl disable netfix \n"
