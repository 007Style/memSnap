# 🧠 memSnap

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Version](https://img.shields.io/badge/version-1.0.0-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

**Native macOS menu-bar memory pressure monitor — know what's eating your RAM before it becomes a problem.**

memSnap lives in your menu bar as a glanceable segmented icon showing wired, compressed, app, and free memory in real time. When pressure rises, it tells you *which process* is to blame, *how long* until things get critical, and lets you kill it right from the popover — no need to open Activity Monitor.

<!-- screenshots here -->

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎨 **4 Icon Styles** | Segmented bar (default), sparkline, arc gauge, or pie chart — all configurable |
| 🟢 **5 Pressure Levels** | Normal (green) → Elevated (amber) → Warning (orange) → Critical (red) → Swap (violet) |
| 📈 **Trend Prediction** | Slope-based "~N minutes until critical" label — warns you before pressure peaks |
| 🔪 **Process Kill & Focus** | Kill or foreground any of the top-8 RSS-sorted processes directly from the popover |
| 📊 **Process Growth Tracking** | Per-process ↑↓ growth indicator (MB/min over a 30-second rolling window) |
| 🗓 **Hourly Pressure Heatmap** | 24-column heatmap showing today's peak pressure level for each hour |
| 🧹 **Purge Cache** | One-click cache purge via `memory_pressure` — frees file-backed pages instantly |
| 📥 **CSV Export** | Export the full 15-minute pressure history to `~/Desktop` with one click |
| 🤖 **Auto-Kill Rules** | User-defined rules: "kill ProcessName if RSS > X MB" with 60-second cooldown |
| 🔔 **Smart Notifications** | Critical & recovery alerts, action button "Show Top Process", configurable de-bounce duration |
| 🌀 **Animated About Window** | RAM particle orbits, live sparkline, memory donut, animated counter, hex grid |
| 🔁 **Pressure History Sparkline** | Scrolling sparkline with threshold lines + 1 m / 5 m / 15 m time-window picker |

---

## 🖼 Screenshots

<!-- screenshots here -->

---

## 📦 Install

1. Download `memSnap-1.0.0.dmg` from the [latest release](https://github.com/daneyand/memSnap/releases/latest).
2. Open the DMG and drag `memSnap.app` into your **Applications** folder.
3. Launch memSnap — the memory icon appears in your menu bar immediately.
4. Grant **Accessibility** access in **System Settings → Privacy & Security → Accessibility** to enable the *Focus* action (brings processes to the foreground).
5. Approve the **Notifications** prompt on first launch to receive pressure alerts.

> **Tip:** Enable "Launch at Login" inside memSnap's Settings (⚙) to have it start automatically.

---

## 🔐 Permissions

| Permission | Why |
|---|---|
| **Accessibility** | Required to bring another app's window to the foreground via the Focus (⬆) button in the process list. memSnap does *not* use Accessibility for any other purpose. |
| **Notifications** | Required to send critical pressure alerts and recovery notifications. Toggled per-type in Settings. |

---

## ⚙️ Settings

All settings take effect immediately with no restart required:

| Setting | Default | Description |
|---|---|---|
| Icon Style | Segmented Bar | Bar / Sparkline / Arc Gauge / Pie Chart |
| Confirm Before Kill | On | Show alert before sending SIGTERM |
| Notify on Critical | On | Alert when pressure reaches critical level |
| Notify on Recovery | On | Alert when pressure returns to normal |
| Notification Threshold | 10 s | Pressure must stay elevated for N seconds before alerting |
| Launch at Login | Off | Start memSnap automatically on login |
| History Window | 5 min | Time window shown in pressure history sparkline |
| Elevated Threshold | 60 % | % used RAM that triggers Elevated level |
| Warning Threshold | 80 % | % used RAM that triggers Warning level |
| Critical Threshold | 90 % | % used RAM that triggers Critical level |

---

## 📋 Pressure Levels

| Level | Color | Trigger |
|---|---|---|
| **Normal** | 🟢 Mint `#44D97A` | Kernel: normal + < 60% used |
| **Elevated** | 🟡 Amber `#F5C842` | Kernel: warning OR 60–80% used |
| **Warning** | 🟠 Orange `#F58A1F` | Kernel: warning + 80–90% used |
| **Critical** | 🔴 Red `#F04E4E` | Kernel: critical OR > 90% used |
| **Swap** | 🟣 Violet `#9D6BF5` | Swap file in use (any amount) |

Pressure is determined from **both** the macOS kernel `kIOResourceMemoryPressureKey` and the raw usage percentage — the worse of the two signals wins.

---

## 🏗 Build From Source

Requires **macOS 13+**, **Swift 5.9+**, and **Xcode Command Line Tools**.

```bash
git clone https://github.com/daneyand/memSnap.git
cd memSnap
./build.sh --local   # builds memSnap.app + DMG in build/
```

For a full release (commits, tags, and publishes to GitHub):

```bash
./build.sh
```

---

## 🗂 Architecture

```
AppDelegate
  └── TrayController
        ├── MemoryMonitor (singleton, 1 Hz)      ← kernel pressure + RSS breakdown + swap + trend
        ├── ProcessMonitor (singleton, 2 Hz)     ← top-8 by RSS + growth tracking + icons
        ├── NotificationManager                  ← critical/recovery + duration threshold + action button
        ├── AutoKillManager                      ← watches rules, fires SIGTERM on threshold breach
        └── NSPopover
              ├── MemoryHeaderView               ← segmented bar + GB numbers + trend prediction label
              ├── PressureHistoryView            ← sparkline + threshold lines + time-window picker
              ├── ProcessListView                ← icon + name + MB + growth arrow + kill/focus
              ├── SwapView                       ← shown only if swap > 0
              ├── PressureHeatmapView            ← 24-col hourly heatmap (today)
              ├── ActionFooterView               ← Purge button + Export CSV + Open Activity Monitor
              └── SettingsView                   ← all prefs (toggled via gear icon)

AboutWindowController
  └── AboutView                                  ← animated: memory particles, live pressure sparkline,
                                                    orbiting RAM cells, hex grid, version, tagline
```

---

## 📄 License

MIT — see [LICENSE](LICENSE).

---

> *From the minds of Daneyand & IBM Bob*
