---
name: app-demo-recorder
description: Record clean, fast-paced demo clips of a mobile app running on an Android emulator or iOS simulator, for ads, store previews, social posts, or AI video tools that take a screen recording as input. Use when the user asks to record, film, or capture the app ("앱 녹화", "앱 영상 찍어줘", "demo video of the app"). Handles the build choice, device performance, a clean status bar, host-side recording, cutting dead time between taps, and checking each clip. Not for automated test runs or for editing finished videos.
---

# App demo recorder

Make short screen recordings that look like a person confidently using the app: one feature per clip, no loading stalls, no debug overlays, no ads, a tidy status bar.

`$S` is `scripts/appdemo.sh` in this skill's directory. It needs `ffmpeg` (`brew install ffmpeg`), plus `adb` for Android or Xcode's `xcrun simctl` for iOS. In sandboxed agents, run it with escalated permissions: it talks to the emulator, the simulator, and writes outside the workspace.

## 1. Agree on what to show

- Ask which features to show if the user has not said. Record **one clip per feature** and name clips `NN_feature` (`01_price_search`, `02_calculator`). Lead with what the product is best at, not with whatever screen the app opens on.
- Ask which build and account to use when it is not obvious. Marketing footage normally needs a **production release build with real data**. A debug/staging build shows dev menus, warning toasts, test data, and runs slower. Do not assume; a staging recording usually has to be redone.
- If the clip needs a paid or premium state, look for a debug/developer override in the app before touching real billing.
- Credentials the user gives you: enter them with a command whose output you discard (`adb shell input text ... >/dev/null` on Android; `printf ... | xcrun simctl pbcopy <udid>` then paste on iOS) rather than through tools that log every command, and do not write them into files.

## 2. Make the device fast and quiet

- **Android emulator**: give it resources. A small AVD stutters on screen and the stutter ends up in the clip.
  `emulator -avd <name> -memory 6144 -cores 4 -gpu host -no-snapshot-save -no-boot-anim`
  If the same app id is already installed with a different signing key, use another AVD instead of uninstalling (uninstalling deletes the user's data).
- Release build installed and running; log in; dismiss first-run popups, permission prompts, and interstitial ads before recording.
- `$S statusbar on`: fixed time (`APPDEMO_TIME`, default 9:41), full battery and signal, notification icons hidden. `$S statusbar off` restores it.
- On Android, do not press system Back on the app's root screen. It finishes the activity and an in-memory override (premium switch, feature flag) is lost on relaunch.

## 3. Rehearse, then record

1. **Rehearse each clip once without recording.** Learn the taps, coordinates, and wait times. Opening the screen once also warms caches, so the recorded take loads faster.
2. Record:
   ```bash
   $S start 01_price_search
   # drive the app: adb shell input tap/swipe/text, xcrun simctl, or your UI automation tool
   $S stop 01_price_search        # -> $APPDEMO_OUT/01_price_search.mp4
   ```
   Recording runs on the host (`adb emu screenrecord` / `simctl io recordVideo`). Do not use in-device `adb shell screenrecord` on an emulator: it competes with the app for CPU and can freeze the UI so scrolls and taps never show up.
3. Send the actions for a clip as one batch with short sleeps (0.5–2.5 s), not one tool call per tap. Inspecting the screen between steps leaves long dead stretches in the take.
4. Scroll in deliberate steps (about 40 % of the screen, 600–800 ms per swipe) so viewers can read.
5. Use the UI driver's text input for non-ASCII text (Korean, emoji); `adb shell input text` only handles ASCII.
6. When a feature only shows value with data (a ledger, a diary, a cart), record creating a realistic entry, then **delete it right after** and confirm the screen is back to its original state. Check sharing defaults first: a new post may be public.

## 4. Check every clip

```bash
$S strip $APPDEMO_OUT/01_price_search.mp4 /tmp/01.jpg 8
```

Look at the strip, not at your script: confirm each intended step actually happened (scrolls moved, the tab switched, the result appeared) and nothing unwanted is on screen: toasts, keyboards covering content, ads, personal data such as a real address, or debug banners. Re-record failed clips; do not ship a clip whose action silently did nothing.

## 5. Cut the waiting

```bash
$S tighten in.mp4 out.mp4          # frozen stretches -> 0.35 s, final result screen kept 1.5 s
$S speed  in.mp4 out.mp4 1.3       # optional uniform speed-up
```

`tighten` finds stretches where the picture does not change and shortens them, so taps follow each other like a person who knows the app. Typical clips lose about half their length. Check a tightened clip with `strip` too: if a small change (typing a digit, toggling a chip) was cut, lower `--noise`; if pauses remain, lower `--min-freeze`.

## 6. Deliver

Put everything in one folder: raw clips, the tightened versions (recommended for editing), and a short README listing each clip, what it shows, and anything the user should know (data created and deleted, personal data visible, emulator camera cutout at the top). Report clip lengths and what could not be recorded and why.
