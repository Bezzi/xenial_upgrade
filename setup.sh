#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

SMBIOS_V=$(dmidecode -t 0 | grep SMBIOS | tail -1 | awk '{print $2}')
if [ $(echo "$SMBIOS_V<2.6"| bc ) == 0 ]
then
  printf "${GREEN}GOOD NEWS:${NC} You can change interface naming with biosdevname. \n"
else
  printf "${RED}BAD NEWS:${NC} You can not change interface naming with biosdevname. Create some ${RED}RULES${NC} !! \n"
  exit 0
fi

printf "Checking for needed packets ..\n"
sleep 1;
if [ $(dpkg-query -W -f='${Status}' bc 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install -y bc;
fi
if [ $(dpkg-query -W -f='${Status}' tee 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install -y bc;
fi

printf "Cheking for udev rules.. \n"
if [  "$(ls -A /etc/udev/rules.d/)" ];
then
  echo "Do you wish to remove the udev rules?"
  select yn in "Yes" "No"; do
    case $yn in
        Yes ) rm /etc/udev/rules.d/* ; break;;
        No )  exit 0;;
    esac
  done
else
  printf "No rules present. \n"
fi

printf "Checking biosdevname packet..\n"
sleep 2;
if [ $(dpkg-query -W -f='${Status}' biosdevname 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install -y biosdevname;
fi
printf "Package installed\n"

DIFACE=`route -n | grep ^0.0.0.0 | sed 's/  */ /g' | cut -d' ' -f8`
NIFACE=`biosdevname -i $DIFACE`
printf "Default interface ${RED}$DIFACE${NC} will be re-named to ${GREEN}$NIFACE${NC} \n"
sleep 2;

printf "Backing up interfaces file .. \n"
cp /etc/network/interfaces /etc/network/interfaces.bak
printf "Updating /etc/network/interfaces file .. \n"
sed "s/$DIFACE/$NIFACE/g" /etc/network/interfaces | tee  /etc/network/intefaces
sleep 2;


printf "Backing up grub.cfg .. \n"
cp /etc/default/grub /etc/default/grub.bak
sleep 1;
printf "Updating grub configuration .. \n"
sed '0,/GRUB_CMDLINE_LINUX_DEFAULT/{s/.*GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT="biosdevname=1"/}' /etc/default/grub.bak | tee /etc/default/grub 
update-grub

printf "Generating ${RED}NETFIX${NC} script .. \n"
sleep 2;
cp netfix.sh  /usr/local/bin/netfix.sh
printf "Enabling netfix service .. \n"
cp netfix.service /etc/systemd/system/netfix.service
systemctl enable netfix.service
printf "Done \n"
printf "You should: \n 1- Check \n 2- reboot \n 3- Disable netfix service. /n :) \n"
