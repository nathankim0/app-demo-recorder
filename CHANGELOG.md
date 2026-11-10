# Changelog

## Unreleased

### Added

- `app-demo-recorder` skill: workflow for recording one clean clip per feature from an Android emulator or iOS simulator (build and account choice, fast emulator, rehearsal, batched actions, deleting data created for a shot, checking every clip).
- `appdemo.sh`: `devices`, `statusbar on|off`, host-side `start`/`stop` recording to MP4, `tighten`, `speed`, `strip`.
- `tighten.py`: shortens frozen stretches (loading, waits between taps) with ffmpeg `freezedetect`, keeping the final result screen longer, and cuts the idle lead-in before the first tap or scroll.
- Claude Code plugin and marketplace manifests, and `install.sh` for Claude Code and Codex.
