#!/usr/bin/env sh
#set -x

SLEEP_SECONDS=2
MAX_ITERATIONS=10
PING_WAIT=4
PING_IP='8.8.8.8'
IF_BACKUP_FILE='/etc/network/interfaces.bak'
GRUB_FILE='/etc/default/grub.bak'
count=0

while [ $count -lt $MAX_ITERATIONS ]; do
  /bin/ping -c 1 -W $PING_WAIT $PING_IP >/dev/null
  rc=$?

  if [ $rc -eq 0 ]; then
    echo 'Network changes worked, doing nothing' >> /tmp/netfix.log
    exit 0
  fi

  count=$((count+1))
  sleep $SLEEP_SECONDS
done

if [ $rc -ge 1 ]; then
  echo 'Server has no connectivity'
  puppet agent --disable "Netfix disabled puppet, you probably screwed up networking."
  cp $IF_BACKUP_FILE /etc/network/interfaces
  service networking restart >/dev/null
  rc=$?
  if [ rc -ge 1 ];
  then
    # Network didn't come back up
    cp $GRUB_FILE /etc/default/grub
    update-grub
    reboot
  else
    exit 0
  fi
fi 
