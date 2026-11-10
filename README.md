# app-demo-recorder

An agent skill for [Claude Code](https://claude.com/claude-code) and [Codex](https://github.com/openai/codex) that records **clean, fast-paced demo clips of a mobile app** running on an Android emulator or iOS simulator: footage you can drop into an ad, a store preview, a social post, or an AI video tool that takes a screen recording as input.

Recording an app with an agent usually produces clips that look like a robot used the app: long pauses while the agent inspects the screen, a laggy emulator, debug toasts, a status bar showing 3:17 and a low battery. This skill fixes that:

| Problem | What the skill does |
| --- | --- |
| Long dead time between taps and while screens load | `tighten` finds frozen stretches with ffmpeg `freezedetect` and cuts each to 0.35 s (the final result screen keeps 1.5 s). Clips typically lose about half their length. |
| Scrolls and taps missing from Android recordings | Records on the host (`adb emu screenrecord`) instead of in-device `screenrecord`, which competes with the app for the emulator's CPU and can freeze the UI. |
| Choppy, stuttering emulator | Boots the AVD with more memory, cores and the host GPU. |
| Messy status bar | Android demo mode / `simctl status_bar`: fixed time, full battery and signal, no notification icons. |
| Clips where an action silently did nothing | `strip` renders evenly spaced frames side by side so the agent (and you) can check every step happened. |
| Debug/staging builds, test data, ads in the shot | The skill tells the agent to agree on a release build, real account and premium/no-ads state first, and to delete any data it creates for a shot. |

## Install

### As a plugin

```
/plugin marketplace add nathankim0/app-demo-recorder
/plugin install app-demo-recorder@app-demo-recorder
```

### As a personal skill for Claude Code and Codex (symlink, updates with `git pull`)

```bash
git clone https://github.com/nathankim0/app-demo-recorder ~/app-demo-recorder
~/app-demo-recorder/install.sh          # or: install.sh claude | install.sh codex
brew install ffmpeg                     # required
```

Then ask the agent something like "record a demo of the search and checkout screens on the Android emulator". In Codex you can invoke it explicitly with `$app-demo-recorder`.

## Requirements

- macOS with `ffmpeg`
- Android: Android SDK (`adb`, `emulator`) and a running emulator
- iOS: Xcode command line tools and a booted simulator

## The script

`skills/app-demo-recorder/scripts/appdemo.sh` works on its own too:

```bash
S=skills/app-demo-recorder/scripts/appdemo.sh
export APPDEMO_OUT=~/Desktop/clips          # default: ./app-demo-clips

$S devices                                  # running emulators / booted simulators
$S statusbar on                             # 9:41, full battery, no notifications (APPDEMO_TIME to change)
$S start 01_search
#   ...drive the app: adb shell input, xcrun simctl, or your UI automation tool...
$S stop 01_search                           # -> $APPDEMO_OUT/01_search.mp4
$S tighten $APPDEMO_OUT/01_search.mp4 $APPDEMO_OUT/01_search_tight.mp4
$S strip   $APPDEMO_OUT/01_search_tight.mp4 /tmp/01.jpg 8
$S speed   $APPDEMO_OUT/01_search.mp4 $APPDEMO_OUT/01_search_fast.mp4 1.3
$S statusbar off
```

When both an Android emulator and an iOS simulator are running, set `APPDEMO_PLATFORM=android|ios` (and `APPDEMO_DEVICE` if more than one of that kind is running).

`tighten.py` knobs: `--hold` (kept length of each wait, default 0.35 s), `--last-hold` (1.5 s), `--min-freeze` (0.45 s), `--noise` (0.0004). If a small change such as typing a digit gets cut, lower `--noise`.

## License

MIT
