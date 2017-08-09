!#/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

SMBIOS_V=$(dmidecode -t 0 | grep SMBIOS | tail -1 | awk '{print $2}')
if [ $(echo "$SMBIOS_V<2.6"| bc ) == 0 ]
then
  printf "GOOD NEWS: You can change interface naming with biosdevname. \n"
else
  printf "BAD NEWS: You can not change interface naming with biosdevname. \n"
  exit 0
fi

printf "Cheking for udev rules.. \n"
if [  "$(ls -A /etc/udev/rules.d/)" ];
then
  echo "Do you wish to remove the udev rules?"
  select yn in "Yes" "No"; do
    case $yn in
        Yes ) rm /etc/udev/rules.d/* ; break;;
        No ) ;;
    esac
  done
else
  printf "No rules present. \n"
fi

printf "Generating netfix script .. \n"
cp netfix.sh  /usr/local/bin/netfix.sh
printf "Backing up interfaces file .. \n"
cp /etc/network/interfaces /etc/network/interfaces.bak
printf "Enabling netfix service .. \n"
cp netfix.service /etc/systemd/system/netfix.service
systemctl enable netfix.service
printf "Done \n"
printf "You should: \n 1- Edit /etc/default/grub biosdevflag=1 \n 2- update-grub \n 3- Edit /etc/network/interfaces \n 4- reboot \n :)"
