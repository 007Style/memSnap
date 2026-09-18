<div align="center">

# 🧠 memSnap

### *From the minds of Daneyand & IBM Bob*

**Native macOS menu-bar memory pressure monitor.**  
Know what's eating your RAM — before it becomes a problem.

[![macOS](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![Version](https://img.shields.io/badge/version-1.0.2-brightgreen?style=flat-square)](https://github.com/007Style/memSnap/releases)
[![License](https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square)](LICENSE)
[![Zero Dependencies](https://img.shields.io/badge/dependencies-zero-purple?style=flat-square)]()

</div>

---

## What is memSnap?

memSnap lives quietly in your macOS menu bar as a real-time memory pressure monitor. It uses the macOS kernel's own pressure signals — the same ones Activity Monitor reads — combined with raw usage percentages to give you a five-level view of your system's memory health: **Normal → Elevated → Warning → Critical → Swap**.

One glance at the menu bar tells you everything. One click shows you exactly which processes are to blame, how fast they're growing, and gives you the tools to deal with them — without opening Activity Monitor.

---

## Features

### 🖥️ Menu Bar Icon — 4 Configurable Styles

| Style | Description |
|---|---|
| **Segmented Bar** *(default)* | Horizontal stacked bar showing wired / compressed / app / free memory proportions in real time |
| **Sparkline** | 40-sample pressure history line that shifts color with the current pressure level |
| **Arc Gauge** | Semicircle fill showing total RAM usage %, color-coded by level |
| **Pie Chart** | Proportional circular wedges — wired, compressed, app, free — at a glance |

All four rendered via `NSBitmapImageRep` + `NSBezierPath` at 1 Hz, never blurry, never tinted.

---

### 🔴 5-Level Pressure Detection

memSnap reads both the kernel's `kIOResourceMemoryPressureKey` and raw percentage thresholds, taking the **worse of the two signals** — so you never miss a problem the system itself is worried about.

| Level | Color | Trigger |
|---|:---:|---|
| **Normal** | 🟢 `#44D97A` | Kernel: normal + < 60% used |
| **Elevated** | 🟡 `#F5C842` | Kernel: warning OR 60–80% |
| **Warning** | 🟠 `#F58A1F` | Kernel: warning + 80–90% |
| **Critical** | 🔴 `#F04E4E` | Kernel: critical OR > 90% |
| **Swap** | 🟣 `#9D6BF5` | Swap file in active use |

---

### 📊 Popover Dashboard

Click the menu bar icon to open the full dashboard:

- **Memory breakdown bar** — proportional wired / compressed / app / free bar with GB labels
- **Trend prediction** — `"~4 min until critical"` computed from linear regression slope over the last 60 samples. Never guess when things are about to go wrong.
- **Pressure history sparkline** — Canvas-drawn filled area with faint threshold lines at 60% / 80% / 90%; switchable 1m / 5m / 15m time windows
- **Swap indicator** — Appears only when swap is active; violet bar showing used vs. total swap
- **24-hour heatmap** — 24 color-coded squares showing peak pressure per hour today. Current hour pulses. Spots patterns like "my machine maxes out every afternoon."

---

### ⚡ Process Control

Top 8 processes by RSS, updated every 2 seconds:

| Column | Description |
|---|---|
| **Icon** | App icon via NSWorkspace (cached) |
| **Name** | Process name, truncated to fit |
| **Memory** | RSS in human-readable format (MB / GB) |
| **Growth** | ↑ red / ↓ green / — gray with MB/min rate |
| **CPU %** | Current CPU usage |
| **⬆ Focus** | `NSRunningApplication.activate` — brings app to foreground |
| **✕ Kill** | SIGTERM → 3s poll → offer SIGKILL (macOS Force Quit flow) |

System processes (PID < 100, `kernel_task`) are protected — buttons disabled.

---

### 🤖 Auto-Kill Rules

Set it and forget it. Define rules like `"if Safari exceeds 4000 MB, kill it"`:

- Rules stored as Codable JSON in UserDefaults — persist across restarts
- 60-second per-process cooldown prevents re-kill loops
- Kill log shows last 20 events with relative timestamps ("2 min ago")
- Toggle individual rules on/off without deleting them

---

### 🔔 Smart Notifications

- **Critical alert** fires only after pressure *stays* critical for N seconds (configurable, default 10s) — no false alarms from brief spikes
- **"Show Top Process"** action button on the notification — one tap opens the memSnap popover to the offending process
- **Recovery alert** fires when pressure returns to normal — close the loop
- Both alerts individually toggleable in Settings

---

### 🧰 Actions

| Action | What it does |
|---|---|
| **🧹 Free Cache** | Calls `memory_pressure -S -l warn` to flush disk caches — reclaims space no other tool surfaces easily |
| **📥 Export CSV** | Dumps full pressure history to `~/Desktop/memSnap-export-YYYY-MM-DD-HH-mm.csv` and reveals it in Finder |
| **↗ Activity Monitor** | Opens Activity Monitor's Memory tab for deeper inspection |

---

### ⚙️ Settings

All settings take effect immediately with no restart:

| Setting | Default |
|---|---|
| Icon style | Segmented bar |
| Confirm before killing | On |
| Critical alert | On |
| Recovery alert | On |
| Alert after N seconds at critical | 10s |
| Elevated threshold | 60% |
| Warning threshold | 80% |
| Critical threshold | 90% |
| Launch at Login | Off |

---

### 🎨 About Window

A fully animated 760×610 dark window that would look at home in a sci-fi movie:

- **RAM particle network** — 10 nodes (RAM, HEAP, WIRED, CACHE, SWAP, APP, FREE, KERN, DISK, VRAM) orbiting a center point at varying speeds; connection lines fade by distance
- **Animated hex grid** — slow rotating background, matching the beeMon / netBee aesthetic
- **Pulsing glow ring** — around the 🧠 icon, scales 1.0→1.5 with fading opacity
- **Live pressure sparkline** — real data, updates every 0.5s
- **Live memory donut** — 4 arc segments, spring-animated when proportions change
- **Animated RAM counter** — counts up from 0 to your actual installed GB on open
- **Pressure level badge** — pulses on level change
- **Feature pills** — 8 key features in a 2-column grid
- **System info capsules** — CPU cores, RAM, macOS version

---

## Install

**Option A — DMG (recommended)**
1. Download `memSnap-1.0.2.dmg` from the [latest release](https://github.com/007Style/memSnap/releases/latest)
2. Open the DMG — drag **memSnap.app** into the **Applications** folder
3. Launch memSnap from Applications or Spotlight

**Option B — Build from source**
```bash
git clone https://github.com/007Style/memSnap.git
cd memSnap
./build.sh --local          # builds DMG in build/
# or just:
swift build -c release
```

---

## Permissions

| Permission | Why | Where to grant |
|---|---|---|
| **Notifications** | Critical / recovery pressure alerts | Prompted on first launch |
| **Accessibility** | Process Focus (⬆ bring to foreground) | System Settings → Privacy & Security → Accessibility |

memSnap does **not** require Full Disk Access, Location, Camera, Microphone, or any network entitlements.

---

## Architecture

```
AppDelegate
  └── TrayController (NSStatusItem + 4 icon renderers + left/right click)
        ├── MemoryMonitor       @MainActor singleton, 1 Hz, IOKit + host_statistics64
        ├── ProcessMonitor      @MainActor singleton, 2 Hz, ps + NSRunningApplication
        ├── NotificationManager @MainActor singleton, UNUserNotificationCenter
        ├── AutoKillManager     @MainActor singleton, Combine + UserDefaults
        └── NSPopover (360px)
              ├── MemoryHeaderView    segmented bar + trend label
              ├── PressureHistoryView sparkline + threshold lines + time picker
              ├── SwapView            conditional violet bar
              ├── ProcessListView     top-8 + growth + kill/focus
              ├── PressureHeatmapView 24-hour hourly peak squares
              └── ActionFooterView    purge + export + Activity Monitor

SettingsWindowController   standalone 500×700 NSWindow
AboutWindowController      standalone 760×610 NSWindow (fully animated)
```

**Stack:** Swift 5.9 · SPM · SwiftUI + AppKit · Combine · IOKit · UserNotifications · macOS 13+ · zero external dependencies.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

**v1.0.2** — Settings opens correctly from right-click context menu · Original brain+circuit app icon · this README

**v1.0.1** — Tagline fixed in About window · Settings as standalone window · Installer DMG with Applications symlink

**v1.0.0** — Initial release

---

<div align="center">

### *From the minds of Daneyand & IBM Bob* 🧠🤖

*Pure Swift · SwiftUI · Zero dependencies · macOS 13+*

</div>
