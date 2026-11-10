# AGENTS.md

Instructions for any coding agent (Claude Code, Codex, others) working in this repository. `CLAUDE.md` is a symlink to this file; edit `AGENTS.md` only.

## What this repo is

An agent skill that records clean, fast-paced demo clips of a mobile app on an Android emulator or iOS simulator. It ships as a Claude Code plugin (this repo is its own marketplace) and as a plain skill folder that `install.sh` symlinks into `~/.claude/skills` and `~/.codex/skills`.

```text
skills/app-demo-recorder/SKILL.md            the skill: workflow the agent follows
skills/app-demo-recorder/scripts/appdemo.sh  devices, statusbar, start/stop recording, tighten, speed, strip
skills/app-demo-recorder/scripts/tighten.py  cuts frozen stretches with ffmpeg freezedetect
skills/app-demo-recorder/agents/openai.yaml  Codex display metadata
.claude-plugin/plugin.json                   plugin manifest (version)
.claude-plugin/marketplace.json              marketplace manifest (metadata.version)
install.sh                                   symlink installer for Claude Code and Codex
assets/banner.png                            README banner
```

## Rules for every change

1. **Commit and push after every change.** One logical change per commit. Push to `main` right after committing. Do not leave work uncommitted at the end of a task.
2. **Release only for distribution changes.** A change is a distribution change when it alters what users install or how the skill behaves: `skills/`, `.claude-plugin/`, `install.sh`, or a changed install command. For these:
   - bump the version one step in `.claude-plugin/plugin.json` (`version`) and `.claude-plugin/marketplace.json` (`metadata.version`): patch for fixes and small tweaks, minor for new features, major for breaking changes
   - move the `Unreleased` notes in `CHANGELOG.md` under the new version
   - commit `Release vX.Y.Z`, push, then tag and release:
     ```bash
     git tag -a vX.Y.Z -m "vX.Y.Z"
     git push origin vX.Y.Z
     gh release create vX.Y.Z --title "vX.Y.Z" --notes-file <notes>
     ```
3. **Docs-only changes do not release.** README, AGENTS.md, images, comments, and typo fixes are committed and pushed with no version bump, tag, or release.
4. **Keep READMEs in sync.** Any change to `README.md` gets the same change in `README.ko.md`, and the reverse.
5. **Validate before committing** a distribution change: `claude plugin validate .`, `bash -n skills/app-demo-recorder/scripts/appdemo.sh`, and `python3 -m py_compile skills/app-demo-recorder/scripts/tighten.py` must pass. When you change recording or trimming behavior, run it once on a real emulator or simulator and check the result with `appdemo.sh strip`.
6. **Never commit secrets or private information**: no tokens, employer or internal names, app names or screenshots from private projects, personal emails, or home paths.

## Project rules

- Keep the skill app-agnostic. Examples use generic feature names (`01_search`), never a specific company's app.
- `appdemo.sh` must keep working on both Android (`adb emu screenrecord`) and iOS (`simctl io recordVideo`). Do not switch Android back to in-device `adb shell screenrecord`; it freezes the UI on emulators.
- Public commits use the author `nathankim0 <37360089+nathankim0@users.noreply.github.com>`.

## Commit messages

Imperative, short subject. Example: `Detect a recording that is already running`.
