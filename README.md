<p align="center">
  <img width="110" height="110" src="Awayke/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png" alt="Awayke icon">
</p>

<h1 align="center"><a href="https://daemonphantom.github.io/Awayke/">Awayke</a></h1>

<p align="center">
  Close the lid. Keep your Mac awayke.
</p>

<p align="center">
  <a href="https://github.com/daemonphantom/Awayke/releases/latest"><img src="https://img.shields.io/github/downloads/daemonphantom/Awayke/total?color=666666&labelColor=444444" alt="Downloads"></a>
  <a href="https://github.com/daemonphantom/Awayke/releases/latest"><img src="https://img.shields.io/github/v/release/daemonphantom/Awayke?color=666666&labelColor=444444" alt="Latest release"></a>
  <a href="https://github.com/daemonphantom/Awayke"><img src="https://img.shields.io/github/stars/daemonphantom/Awayke?style=social" alt="Stars"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-666666?labelColor=444444" alt="macOS 13+">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-666666?labelColor=444444" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://github.com/daemonphantom/Awayke/releases/latest"><strong>Download the latest release →</strong></a>
</p>

---

macOS puts your Mac to sleep when you close the lid. Awayke flips `pmset disablesleep` that stops it, and puts it behind a single menubar icon.

## What it does

<img width="310" height="126" alt="Awayke menubar toggle" src="https://github.com/user-attachments/assets/457398c5-2324-4328-b2fe-a0d555042caf" />

**Left-click** the laptop icon to toggle on/off.

**Right-click** for a bounded session:

- Stay active for 15min - 2h, or  until you close and reopen the lid
- Optional low-battery cutoff at 10%, 20%, or 30%

Quitting Awayke always re-enables sleep.

## Install

### Download (recommended)

1. Grab `Awayke.app.zip` from the [latest release](https://github.com/daemonphantom/Awayke/releases/latest).
2. Unzip and drag `Awayke.app` into `/Applications`.
3. Open it.
4. macOS asks you to allow Awayke background helper. Approve it once to get rid of sudo password permission asks.

<img width="372" height="141" alt="Background helper approval dialog" src="https://github.com/user-attachments/assets/02157a1b-e462-4905-b3b3-a0f7c2c6c235" />

### Build from source

```bash
git clone https://github.com/daemonphantom/Awayke.git
cd Awayke
open Awayke.xcodeproj
```

Requires Xcode 16+ and macOS 13 Ventura or later.

> **Why isn't this on the App Store?**
> App Store sandboxing blocks the system call Awayke depends on. Lunar, TextExpander, and BetterTouchTool ship outside the App Store for the same reason.

## Who it's for

- Long builds, downloads, or a server process you don't want to babysit
- Agentic coding sessions with Claude Code, Cursor, or Codex that run for a while
- Walking to the next room mid-task without losing state
- Using an old MacBook as a home server

No more wedging an HDMI cable into the hinge.

## How it works

Most keep-awake tools use `caffeinate` or IOKit power assertions. Those stop the display and idle sleep, but macOS handles lid-close sleep on a separate path that ignores them. The only reliable override is Apple's own `pmset disablesleep`.

`pmset` needs root, so Awayke installs a small privileged helper daemon via `SMAppService` on first run. The menubar app talks to the helper over XPC; the helper runs `pmset -a disablesleep 1` or `0`. You approve the helper once. After that, toggling is silent and survives reboots.

## Is this safe?

The command Awayke runs is Apple's own tooling, and short sessions carry little thermal risk. Two rules:

1. Don't put a lid-closed, awake MacBook in a bag. It will get hot.
2. Keep it on AC power for anything long.

Use at your own risk.

## Caveats

- `pmset -a disablesleep` is system-wide. While Awayke is active, nothing sleeps from a closed lid.
- macOS still forces sleep on critical battery, regardless of `disablesleep`.
- If Awayke crashes or the Mac loses power while active, the setting may persist. Toggle it off and on again, or run `sudo pmset -a disablesleep 0` in Terminal.

## Why not Amphetamine?

Amphetamine is excellent and can do this too, three menus deep. Awayke exists for people who want exactly the one thing.

| | Awayke | Amphetamine | caffeinate |
|---|:-:|:-:|:-:|
| Prevents lid-close sleep | ✅ | ✅ (buried in menus) | ❌ |
| One-click toggle | ✅ | ❌ | ❌ |
| No sudo prompt | ✅ | ✅ | ❌ |
| Timed sessions | ✅ | ✅ | ✅ |
| Low-battery cutoff | ✅ | ✅ | ❌ |
| Does nothing else | ✅ | ❌ | – |

Closing the lid to sleep your Mac is one of the best things about macOS. Awayke doesn't change that. It's an occasional override.

## Privacy

Awayke collects nothing. No analytics, no crash reports, no network calls.

## Contributing

Bug reports and pull requests are welcome. Open an [issue](https://github.com/daemonphantom/Awayke/issues) if something misbehaves on your machine, and include your macOS version.

## License

[MIT](LICENSE)
