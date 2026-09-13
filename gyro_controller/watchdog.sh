#!/bin/sh
# Respawn controller.py if it is not running. Installed as a cron job (every
# minute) by `deploy.sh daemon`; checks every 10 s within its minute.
#
# Why this exists: the UNO Q's USB gadget stack reloads periodically, systemd
# then restarts adbd and kills everything in adbd's cgroup -- including any
# controller started via `adb shell`, nohup or not. Cron jobs run in cron's
# cgroup, so a cron-spawned controller survives, and this watchdog revives it
# after any other kind of death too.
#
# The [c]ontroller pattern can't match this script's own command line.
DIR=/home/arduino/gyro_controller
cd "$DIR" || exit 1
i=0
while [ $i -lt 6 ]; do
  if ! /usr/bin/pgrep -f "[c]ontroller.py" >/dev/null 2>&1; then
    nohup /usr/bin/python3 controller.py >> controller.log 2>&1 &
  fi
  i=$((i + 1))
  [ $i -lt 6 ] && sleep 10
done
