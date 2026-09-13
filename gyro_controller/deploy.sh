#!/usr/bin/env bash
# Push, compile, upload and run the gyro controller on the Arduino UNO Q.
# Usage:  ./deploy.sh            (full: push + compile + upload + run)
#         ./deploy.sh run        (skip compile/upload, just run controller.py)
#         ./deploy.sh daemon     (like run, but detached via nohup: survives
#                                 adb/USB drops; logs to controller.log on the
#                                 board; stop with ./deploy.sh stop)
#         ./deploy.sh stop       (kill a detached controller)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="gyro_controller"
BOARD_PARENT="/home/arduino"
BOARD_DIR="$BOARD_PARENT/$NAME"
FQBN="arduino:zephyr:unoq"
PORT="${HTTP_PORT:-8090}"
MODE="${1:-all}"

if [ "$MODE" = "stop" ]; then
  # Remove the watchdog cron entry FIRST or it revives the controller within
  # a minute. [c]ontroller trick: the pattern must not match the remote
  # shell's own command line, or pkill kills the shell along with the target.
  adb shell 'crontab -l 2>/dev/null | grep -v gyro_watchdog | crontab -' || true
  adb shell 'pkill -f "[c]ontroller.py"' || true
  echo "==> controller stopped (watchdog removed)"
  exit 0
fi

echo "==> pushing project to board ($BOARD_DIR)"
adb push "$HERE" "$BOARD_PARENT/" >/dev/null

if [ "$MODE" != "run" ] && [ "$MODE" != "daemon" ]; then
  echo "==> compiling sketch (this can take a minute)"
  adb shell "cd '$BOARD_DIR' && arduino-cli compile -b $FQBN ."
  echo "==> uploading sketch to the MCU"
  adb shell "cd '$BOARD_DIR' && arduino-cli upload -b $FQBN ."
fi

echo "==> forwarding web UI: http://localhost:$PORT"
adb forward tcp:$PORT tcp:$PORT >/dev/null

if [ "$MODE" = "daemon" ]; then
  adb shell 'pkill -f "[c]ontroller.py"' || true
  # Cron watchdog: the USB gadget stack reloads periodically -> systemd
  # restarts adbd and kills adbd's whole cgroup (nohup does NOT help).
  # Cron-spawned processes live in cron's cgroup and survive; the watchdog
  # also respawns the controller within ~10 s of any death.
  adb shell "chmod +x '$BOARD_DIR/watchdog.sh'"
  adb shell "(crontab -l 2>/dev/null | grep -v gyro_watchdog; echo '* * * * * $BOARD_DIR/watchdog.sh # gyro_watchdog') | crontab -"
  adb shell "'$BOARD_DIR/watchdog.sh' >/dev/null 2>&1 & sleep 1"
  echo "==> controller running under cron watchdog (survives adbd/gadget resets)"
  echo "    Open http://localhost:$PORT — logs: adb shell cat $BOARD_DIR/controller.log"
  echo "    Stop with: ./deploy.sh stop"
else
  echo "==> starting controller.py on the board (Ctrl+C to stop)"
  echo "    Open http://localhost:$PORT and flip the HID switch when ready."
  adb shell "cd '$BOARD_DIR' && python3 controller.py"
fi
