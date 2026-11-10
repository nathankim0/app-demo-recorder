#!/usr/bin/env bash
# app-demo-recorder: record clean app demo clips from an Android emulator or iOS simulator.
#
#   appdemo.sh devices                      list running emulators/simulators
#   appdemo.sh statusbar on|off             clean status bar (fixed time, full battery/signal, no notifications)
#   appdemo.sh start NAME                   start a host-side recording
#   appdemo.sh stop NAME                    stop it and write $APPDEMO_OUT/NAME.mp4
#   appdemo.sh tighten IN.mp4 OUT.mp4       shorten frozen waits (see tighten.py for knobs)
#   appdemo.sh speed IN.mp4 OUT.mp4 1.3     change playback speed
#   appdemo.sh strip IN.mp4 OUT.jpg [N]     N evenly spaced frames side by side, for checking a clip
#
# Environment:
#   APPDEMO_PLATFORM  android | ios        (default: whichever single device is running)
#   APPDEMO_DEVICE    adb serial or simulator UDID (default: the only running one)
#   APPDEMO_OUT       output folder         (default: ./app-demo-clips)
#   APPDEMO_TIME      status bar time       (default: 9:41)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="${APPDEMO_OUT:-$PWD/app-demo-clips}"
state="${TMPDIR:-/tmp}"; state="${state%/}/app-demo-recorder"
mkdir -p "$state"

die() { echo "appdemo: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "$1 not found${2:+ ($2)}"; }

android_devices() { command -v adb >/dev/null && adb devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1}'; }
ios_devices() { command -v xcrun >/dev/null && xcrun simctl list devices booted 2>/dev/null | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p'; }

resolve() {
  platform="${APPDEMO_PLATFORM:-}"
  device="${APPDEMO_DEVICE:-}"
  if [ -z "$platform" ]; then
    local a i
    a=$(android_devices | wc -l | tr -d ' ')
    i=$(ios_devices | wc -l | tr -d ' ')
    if [ "$a" -ge 1 ] && [ "$i" -eq 0 ]; then platform=android
    elif [ "$i" -ge 1 ] && [ "$a" -eq 0 ]; then platform=ios
    elif [ "$a" -eq 0 ] && [ "$i" -eq 0 ]; then die "no running Android emulator or booted iOS simulator"
    else die "both Android and iOS devices are running; set APPDEMO_PLATFORM"
    fi
  fi
  if [ -z "$device" ]; then
    local list
    list=$([ "$platform" = android ] && android_devices || ios_devices)
    [ "$(printf '%s\n' "$list" | grep -c .)" -eq 1 ] || die "set APPDEMO_DEVICE (found: $(echo $list))"
    device="$list"
  fi
}

cmd_devices() {
  echo "android:"; android_devices | sed 's/^/  /'
  echo "ios (booted):"; ios_devices | sed 's/^/  /'
}

cmd_statusbar() {
  resolve
  local mode="${1:-on}" t="${APPDEMO_TIME:-9:41}"
  if [ "$platform" = android ]; then
    local s=(adb -s "$device" shell)
    if [ "$mode" = on ]; then
      "${s[@]}" settings put global sysui_demo_allowed 1
      for c in "enter" "clock -e hhmm ${t/:/}" "battery -e level 100 -e plugged false" \
               "network -e wifi show -e level 4 -e fully true -e mobile hide" "notifications -e visible false"; do
        "${s[@]}" am broadcast -a com.android.systemui.demo -e command $c >/dev/null
      done
    else
      "${s[@]}" am broadcast -a com.android.systemui.demo -e command exit >/dev/null
    fi
  else
    if [ "$mode" = on ]; then
      xcrun simctl status_bar "$device" override --time "$t" --batteryState charged --batteryLevel 100 \
        --wifiBars 3 --cellularMode active --cellularBars 4 --dataNetwork wifi
    else
      xcrun simctl status_bar "$device" clear
    fi
  fi
  echo "status bar $mode ($platform $device)"
}

cmd_start() {
  resolve
  local name="${1:?name required}"
  mkdir -p "$out"
  if [ "$platform" = android ]; then
    # Host-side capture: the emulator encodes on the Mac, so the app keeps its full frame rate.
    # In-device `adb shell screenrecord` competes with the app for the emulator's CPU and can freeze RN/Flutter UIs.
    rm -f "$state/$name.webm"
    local r
    r=$(adb -s "$device" emu screenrecord start --time-limit 180 "$state/$name.webm" 2>&1)
    case "$r" in *KO*) die "emulator refused to record: ${r//$'\n'/ } (another recording running? try: adb -s $device emu screenrecord stop)";; esac
  else
    rm -f "$state/$name.mov"
    xcrun simctl io "$device" recordVideo --codec h264 --force "$state/$name.mov" >/dev/null 2>&1 &
    echo $! > "$state/$name.pid"
  fi
  echo "$platform $device" > "$state/$name.dev"
  sleep 1
  echo "recording $name"
}

cmd_stop() {
  need ffmpeg "brew install ffmpeg"
  local name="${1:?name required}"
  [ -f "$state/$name.dev" ] || die "no recording named $name"
  read -r platform device < "$state/$name.dev"
  local src
  if [ "$platform" = android ]; then
    adb -s "$device" emu screenrecord stop >/dev/null
    src="$state/$name.webm"
  else
    kill -INT "$(cat "$state/$name.pid")" 2>/dev/null || true
    src="$state/$name.mov"
  fi
  for _ in $(seq 1 20); do [ -s "$src" ] && break; sleep 0.5; done
  sleep 2
  [ -s "$src" ] || die "recording file missing: $src"
  mkdir -p "$out"
  ffmpeg -v error -y -i "$src" -an -c:v libx264 -crf 18 -pix_fmt yuv420p -r 30 -movflags +faststart "$out/$name.mp4"
  rm -f "$state/$name".{dev,pid}
  printf '%s  %.1fs\n' "$out/$name.mp4" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out/$name.mp4")"
}

cmd_tighten() { need ffmpeg "brew install ffmpeg"; python3 "$here/tighten.py" "$@"; }

cmd_speed() {
  need ffmpeg "brew install ffmpeg"
  local in="${1:?in}" o="${2:?out}" f="${3:-1.3}"
  ffmpeg -v error -y -i "$in" -an -vf "setpts=PTS/$f" -r 30 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart "$o"
  echo "$o"
}

cmd_strip() {
  need ffmpeg "brew install ffmpeg"
  local in="${1:?in}" o="${2:?out.jpg}" n="${3:-8}" d
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
  ffmpeg -v error -y -i "$in" -vf "fps=$n/$d,scale=-1:360,tile=${n}x1" -frames:v 1 "$o"
  echo "$o"
}

case "${1:-}" in
  devices|statusbar|start|stop|tighten|speed|strip) c=$1; shift; "cmd_$c" "$@" ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
