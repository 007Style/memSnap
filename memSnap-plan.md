# memSnap — Plan v1.0.0

## Overview

**memSnap** is a native macOS menu-bar utility that monitors system memory pressure in real time. It displays a configurable icon in the menu bar — defaulting to a segmented bar showing wired/compressed/app/free proportions — color-coded by pressure level (green → amber → orange → red → violet). Clicking opens a rich popover with a RAM summary, pressure history, trend prediction, process memory growth tracking, top-8 processes with kill/focus actions, swap indicator, a purge button, pressure log export, configurable auto-kill rules, smart notifications with action buttons, and a full settings panel. A standalone About window showcases animated visualizations and the version number.

The project follows identical architecture patterns to `beeMon` and `netBee`: Swift SPM, `@MainActor` singletons, `Timer.publish` + Combine, `NSBitmapImageRep` tray icons, `NSPopover`, and a `DS` design system enum. Version: **1.0.0**.

Tagline (must appear in README, About window, and GitHub release):
> *From the minds of Daneyand & IBM Bob*

---

## Architecture Diagram

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

## Pressure Levels

| Level    | Color      | Hex       | Trigger                              |
|----------|-----------|-----------|--------------------------------------|
| Normal   | Mint green | `#44D97A` | Kernel: normal + < 60% used          |
| Elevated | Amber      | `#F5C842` | Kernel: warning OR 60–80%            |
| Warning  | Orange     | `#F58A1F` | Kernel: warning + 80–90%             |
| Critical | Red        | `#F04E4E` | Kernel: critical OR > 90%            |
| Swap     | Violet     | `#9D6BF5` | Swap file in use (any amount)        |

Pressure level is computed from **both** the macOS kernel memory pressure key (`kIOResourceMemoryPressureKey`) and the raw percentage, taking the worse of the two signals.

---

## Icon Styles (all configurable in Settings)

| Style          | Description                                                              | Default |
|----------------|-------------------------------------------------------------------------|---------|
| `segmentedBar` | Horizontal stacked bar: wired / compressed / app / free                 | ✅      |
| `sparkline`    | 40-sample pressure trend line, color shifts with current level          |         |
| `arcGauge`     | Semicircle fill showing RAM %, color-coded                              |         |
| `pieChart`     | Circular slice showing all four memory regions                          |         |

---

## Sub-Tasks

---

### Sub-Task 1 — Project Scaffold

**Intent**: Create the SPM project structure, Package.swift, and entry point files matching the conventions of `beeMon` and `netBee`.

**Expected Outcomes**:
- `memSnap/` directory with `Package.swift`, `Sources/memSnap/`, `build.sh`
- `main.swift` with `AppDelegate` that sets `.accessory` policy and calls `TrayController()`
- `DesignSystem.swift` with all color/spacing tokens for memSnap
- `VERSION = "1.0.0"` defined as a constant in `AppConstants.swift` and mirrored in `Info.plist`
- Project builds with `swift build` with no warnings

**Todo List**:
1. Create `memSnap/Package.swift` (macOS 13, executable target, Combine + UserNotifications framework linkage)
2. Create `Sources/memSnap/AppConstants.swift` — `enum App { static let version = "1.0.0"; static let bundleID = "com.daneyand.memSnap" }`
3. Create `Sources/memSnap/Info.plist` — `CFBundleShortVersionString: "1.0.0"`, `CFBundleName: "memSnap"`
4. Create `Sources/memSnap/main.swift` — `AppDelegate` init, `NSApp.setActivationPolicy(.accessory)`, `NSApp.run()`
5. Create `Sources/memSnap/DesignSystem.swift` — `DS` enum with: pressure level colors (5 levels), memory region colors (wired blue, compressed violet, app amber, free dark-gray), background/surface/border/text tokens, spacing and corner radius constants, font tokens
6. Create `Sources/memSnap/AppDelegate.swift` — singleton init sequence: `_ = MemoryMonitor.shared`, `_ = ProcessMonitor.shared`, `_ = NotificationManager.shared`, `_ = AutoKillManager.shared`, then `trayController = TrayController()`
7. Copy and adapt `build.sh` from `beeMon` (swap `APP_NAME=memSnap`, `BUNDLE_ID=com.daneyand.memSnap`, `VERSION=1.0.0`)
8. Create placeholder `Sources/memSnap/Assets/` with app icon SVG stub (brain/memory icon)
9. Run `swift build` and confirm zero errors/warnings

**Relevant Context**:
- `beeMon/Package.swift` — SPM structure reference
- `beeMon/build.sh` — bundle assembly reference
- `beeMon/Sources/beeMon/AppDelegate.swift` — singleton ordering pattern
- `beeMon/Sources/beeMon/DesignSystem.swift` — token naming conventions
- `netBee/Sources/netBee/AboutView.swift` — reads version from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`

**Status**: `[ ] pending`

---

### Sub-Task 2 — MemoryMonitor Singleton

**Intent**: Implement the core data-collection singleton that samples macOS memory statistics at 1 Hz, computes `PressureLevel`, tracks historical samples, and derives the trend prediction.

**Expected Outcomes**:
- `MemoryMonitor.shared` samples every 1 second
- Published: `pressureLevel`, `wiredBytes`, `compressedBytes`, `appBytes`, `freeBytes`, `totalBytes`, `swapUsedBytes`, `pressureHistory` (900-sample rolling buffer = 15 min), `usageRateMBPerMin`, `minutesUntilCritical: Double?`
- `pressureLevel` is computed from the worse of `kIOResourceMemoryPressureKey` and raw % thresholds
- `minutesUntilCritical` = `(criticalThresholdBytes - usedBytes) / rateOfChangePerMin`; `nil` if pressure is falling or already critical
- All `@Published` mutations on `@MainActor`
- `MemorySample` struct carries all values as value types

**Todo List**:
1. Define `PressureLevel` enum: `normal`, `elevated`, `warning`, `critical`, `swap` — with `color: Color` and `label: String` computed properties using DS tokens
2. Define `MemorySample` struct: `wiredBytes`, `compressedBytes`, `appBytes`, `freeBytes`, `totalBytes`, `swapUsedBytes`, `pressureLevel`, `timestamp: Date`
3. Implement `MemoryMonitor: ObservableObject` — `@MainActor`, `static let shared`, `private init()`
4. Implement `sample()` using `host_statistics64(HOST_VM_INFO64)` for page counts, `sysctl("vm.swapusage")` for swap, `IOKit kIOResourceMemoryPressureKey` for kernel level
5. Convert page counts to bytes using `vm_kernel_page_size`
6. Compute `PressureLevel` from both kernel key and `MemSnapSettings.shared` thresholds — take worse result
7. Append to `pressureHistory: RollingBuffer<MemorySample>` (capacity 900)
8. Compute `usageRateMBPerMin`: linear regression slope over last 60 samples (or simple delta over last 30s if fewer samples)
9. Compute `minutesUntilCritical` from slope; set `nil` when rate ≤ 0 or already at/above critical
10. Maintain `peakSamples: [Int: MemorySample]` — keyed by hour-of-day (0–23); update when current sample exceeds stored peak for that hour (used by PressureHeatmapView)
11. Start 1 Hz `Timer.publish().autoconnect().sink()` in `private init()` via `DispatchQueue.main.async` deferral

**Relevant Context**:
- `beeMon/Sources/beeMon/SystemMonitor.swift` — `host_statistics64()` pattern, `@MainActor` timer
- `netBee/Sources/netBee/LatencyMonitor.swift` — `DispatchQueue.main.async` init deferral (critical — do not skip)
- IOKit: `IOServiceGetMatchingService`, `IORegistryEntryCreateCFProperty` for `kIOResourceMemoryPressureKey`

**Status**: `[ ] pending`

---

### Sub-Task 3 — ProcessMonitor Singleton

**Intent**: Sample the top 8 processes by RSS every 2 seconds, track per-process memory growth, resolve app icons via NSWorkspace.

**Expected Outcomes**:
- `ProcessMonitor.shared.topProcesses: [ProcessEntry]` — top 8 by memory, published at 2 Hz
- Each `ProcessEntry`: `pid`, `name`, `bundleID?`, `icon: NSImage?`, `rssBytes`, `cpuPercent`, `growthMBPerMin: Double`, `growthDirection: GrowthDirection` (up/down/stable)
- Growth tracked by comparing current RSS to RSS 30 seconds ago from an internal `[Int: UInt64]` history cache keyed by PID
- Icons resolved from `NSRunningApplication` (cached); fallback to `NSWorkspace.shared.icon(forFile:)` for daemons

**Todo List**:
1. Define `GrowthDirection` enum: `up`, `down`, `stable` (threshold: < 5 MB/min = stable)
2. Define `ProcessEntry: Identifiable` struct with all fields including `growthMBPerMin` and `growthDirection`
3. Implement `ProcessMonitor: ObservableObject` — `@MainActor`, `static let shared`
4. Implement `fetchRaw()` as `nonisolated static` using `/bin/ps -Arco pid,rss,pcpu,comm`
5. Parse ps output → sort by RSS descending → take top 8
6. Maintain `rssHistory: [Int: [UInt64]]` — append each sample per PID; keep last 15 entries (30s at 2 Hz); compute growth rate from oldest vs current
7. Resolve `NSRunningApplication` per PID for `bundleIdentifier` and `icon`; cache icons in `[String: NSImage]` by bundle ID
8. Fallback icon for daemons: `NSWorkspace.shared.icon(forFile: "/proc/\(pid)/exe")` or generic system icon
9. Start 2 Hz timer with `DispatchQueue.main.async` deferral in `private init()`

**Relevant Context**:
- `beeMon/Sources/beeMon/ProcessMonitor.swift` — `nonisolated static fetchProcesses()`, ps parsing pattern

**Status**: `[ ] pending`

---

### Sub-Task 4 — TrayController & Icon Rendering

**Intent**: Build the `NSStatusItem` controller that renders one of four configurable icon styles at 1 Hz and handles left-click (popover) and right-click (context menu).

**Expected Outcomes**:
- `TrayController` owns `NSStatusItem` and re-renders the icon every 1s
- Four render paths: `makeSegmentedBarIcon`, `makeSparklineIcon`, `makeArcGaugeIcon`, `makePieChartIcon`
- Icon color/style reflects `PressureLevel` in real time
- Left-click → toggle popover; right-click → context menu with "Open memSnap / About / Settings / Quit"
- `NSBitmapImageRep` + `NSBezierPath`, `isTemplate = false`

**Todo List**:
1. Implement `TrayController` — owns `NSStatusItem`, `NSPopover`, `Set<AnyCancellable>`
2. Configure `statusItem.button` with `sendAction(on: [.leftMouseUp, .rightMouseUp])`
3. Implement `handleClick` — detect right-click via `NSApp.currentEvent?.type == .rightMouseUp`; left = toggle popover, right = show context menu
4. Implement `startIconUpdates()` — `Timer.publish(every: 1.0)` sink reading `MemoryMonitor.shared`
5. `makeSegmentedBarIcon(wired:compressed:app:free:level:)` — 64w × 18h stacked horizontal bar in 4 DS region colors; pressure-level colored 1px outline border
6. `makeSparklineIcon(history:level:)` — 56w × 18h, bezier path line, level-color fill, matches `beeMon` style
7. `makeArcGaugeIcon(percent:level:)` — 22w × 18h, semicircle arc, level color
8. `makePieChartIcon(wired:compressed:app:free:)` — 20w × 20h, proportional wedges in DS region colors
9. Read `MemSnapSettings.shared.iconStyle` to dispatch correct render function
10. Context menu: "Open memSnap" / "About memSnap…" / separator / "Settings…" / separator / "Quit memSnap"
11. "About memSnap…" opens `AboutWindowController`

**Relevant Context**:
- `beeMon/Sources/beeMon/TrayController.swift` — sparkline render, left/right click, context menu `menu = nil` clear pattern
- `netBee/Sources/netBee/TrayController.swift` — stacked bar approach (adapt for 4 memory regions)
- AGENTS.md: `isTemplate = false` must be set on every tray icon `NSImage`

**Status**: `[ ] pending`

---

### Sub-Task 5 — Popover Core Views

**Intent**: Build the main popover with RAM summary, pressure history sparkline, swap indicator, and the trend prediction label.

**Expected Outcomes**:
- `NSPopover` (.transient, 360w × auto) below the tray button
- `MemoryHeaderView` — segmented bar (wired/compressed/app/free) + "X.X GB / Y GB" + trend prediction label ("~4 min until critical" or "Pressure stable")
- `PressureHistoryView` — scrolling sparkline with 3 faint threshold lines + `TimeWindowPicker` (1m / 5m / 15m)
- `SwapView` — conditional; violet bar + swap bytes
- Cards styled with `MetricCard` (rounded rect, DS surface, border, shadow)

**Todo List**:
1. Create `PopoverRootView` — SwiftUI VStack composing all sections; `@ObservedObject var mem = MemoryMonitor.shared`; `@State var showSettings = false`; `@State var showAbout = false`
2. `MemoryHeaderView` — `GeometryReader` for proportional slice widths; DS colors per region; text row below: "12.4 GB used · 3.6 GB free"; trend label beneath: if `minutesUntilCritical != nil` show "⚠️ ~N min until critical" in orange; else "✓ Pressure stable" in muted
3. `PressureHistoryView` — SwiftUI `Canvas` sparkline over `[MemorySample]`; draw 3 `Path` horizontal dashed lines at threshold %; `TimeWindowPicker` toggles slice
4. `SwapView` — only rendered when `swapUsedBytes > 0`; violet `RoundedRectangle` fill bar; "Swap: X MB in use" label
5. `MetricCard<Content: View>` — generic card wrapper with rounded rect, surface fill, border, shadow — matches `beeMon` pattern
6. Gear `⚙` button in popover header leading edge toggles `showSettings`; overlays `SettingsView` when true
7. Set up `NSPopover`: `.transient`, `NSHostingController<PopoverRootView>`, width 360, `preferredEdge: .minY`
8. Position using `pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)`

**Relevant Context**:
- `beeMon/Sources/beeMon/DashboardView.swift` — `MetricCard`, `SectionHeader`
- `netBee/Sources/netBee/DashboardView.swift` — `TimeWindowPicker`
- `beeKey/Sources/beeKey/TrayController.swift` — `.transient` popover setup

**Status**: `[ ] pending`

---

### Sub-Task 6 — ProcessListView (Kill / Focus / Growth)

**Intent**: Build the process list section with app icons, memory usage, growth indicators, and kill/focus actions.

**Expected Outcomes**:
- Top 8 processes by RSS; each row: app icon (20×20) / name / RSS / growth arrow+rate / CPU% / focus button / kill button
- Growth arrow: ↑ red if growing > 5 MB/min, ↓ green if shrinking, — gray if stable
- Focus: brings app to foreground; Kill: SIGTERM → 3s poll → offer SIGKILL
- System process rows have kill/focus disabled + reduced opacity
- "Open Activity Monitor →" link in section footer

**Todo List**:
1. `ProcessListView` — `@ObservedObject var procs = ProcessMonitor.shared`; `ForEach` over `topProcesses`
2. `ProcessRowView` — `HStack`: `Image(nsImage:)` 20×20 / name `.lineLimit(1).truncationMode(.tail)` / memory label / growth badge / cpu label / spacer / focus `⬆` button / kill `✕` button
3. `GrowthBadge` — small capsule: arrow symbol + rate string ("↑ 12 MB/m"), colored by direction
4. `focusProcess(_ entry:)` — `NSRunningApplication(processIdentifier: pid_t(entry.id))?.activate(options: .activateIgnoringOtherApps)`
5. `killProcess(_ entry:)` — check `MemSnapSettings.shared.confirmBeforeKill`; if true, present `NSAlert`; on OK, `kill(pid_t(entry.id), SIGTERM)` then `watchForExit(pid:entry.id)`
6. `watchForExit(pid:)` — `Task` polling `kill(pid, 0)` every 500ms; if alive after 3s, present `NSAlert("Force Quit?")`; on OK, `kill(pid_t(pid), SIGKILL)`
7. Guard: `entry.id < 100 || entry.name == "kernel_task"` → disable both buttons, `opacity(0.35)`
8. Footer: `Button("Open Activity Monitor →")` → `NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))`

**Relevant Context**:
- `beeMon/Sources/beeMon/ProcessMonitor.swift` — `ProcessEntry` model
- `import Darwin` for `kill()`, `SIGTERM`, `SIGKILL`

**Status**: `[ ] pending`

---

### Sub-Task 7 — PressureHeatmapView & ActionFooterView

**Intent**: Build the 24-hour hourly pressure heatmap and the action footer with Purge Memory, Export CSV, and Activity Monitor shortcut.

**Expected Outcomes**:
- `PressureHeatmapView` — 24 colored squares (one per hour 0–23); each colored by peak `PressureLevel` seen that hour; current hour pulses; tooltip on hover shows "2 PM — peak: 87% (Critical)"
- `PurgeMemoryAction` — calls `vm_pressure_monitor` or shells `memory_pressure -S -l warn` to purge file caches; shows brief confirmation label "Cache cleared"
- `ExportCSVAction` — writes `pressureHistory` to `~/Desktop/memSnap-export-<date>.csv` with columns: timestamp, level, wired_mb, compressed_mb, app_mb, free_mb, swap_mb; shows Finder reveal on success

**Todo List**:
1. `PressureHeatmapView` — 24-item `HStack`; each item an `8×12` `RoundedRectangle` filled with `pressureLevel.color` at 0.85 opacity; current hour gets a white 1px border + subtle pulse animation; empty hours (future) filled with DS surface color
2. Data source: `MemoryMonitor.shared.peakSamples[hour]?.pressureLevel` for each hour 0–23
3. Hover tooltip: `NSHostingView` overlay or SwiftUI `.popover` on hover showing hour label + peak % + level name
4. `ActionFooterView` — `HStack` with 3 items:
   - "🧹 Free Cache" button → `purgeMemoryCache()`
   - "📥 Export CSV" button → `exportPressureHistory()`
   - "↗ Activity Monitor" button → open Activity Monitor (reuse from Sub-Task 6 footer)
5. `purgeMemoryCache()` — spawn `Process()` with `/usr/bin/memory_pressure` flag equivalent; update button label to "✓ Done" for 2s via `Task.sleep`
6. `exportPressureHistory()` — format `MemoryMonitor.shared.pressureHistory.elements` as CSV string; write to `FileManager.default.urls(for: .desktopDirectory)` with date-stamped filename; call `NSWorkspace.shared.activateFileViewerSelecting` to reveal in Finder

**Relevant Context**:
- `MemoryMonitor.peakSamples` from Sub-Task 2
- `beeMon` pattern for temporary label state (no prior art — use `@State var purgeConfirmed = false` + `Task.sleep`)

**Status**: `[ ] pending`

---

### Sub-Task 8 — NotificationManager (Smart)

**Intent**: Send macOS notifications with action buttons when pressure transitions, with configurable duration-threshold de-bouncing to prevent false alarms.

**Expected Outcomes**:
- Notifications fire only after pressure stays at critical/swap for N seconds (configurable, default 10s)
- Critical alert notification has an action button "Show Top Process" that opens popover
- Recovery notification fires when pressure returns to normal from elevated/warning/critical
- Both notification types individually toggled in Settings
- Permission requested once at first launch

**Todo List**:
1. `NotificationManager: ObservableObject` — `@MainActor`, `static let shared`
2. Subscribe to `MemoryMonitor.shared.$pressureLevel` via `.sink`; maintain `elevatedSince: Date?` and `previousLevel`
3. On level change to `.critical` or `.swap`: record `elevatedSince = Date()`; schedule a `Task.sleep(durationThreshold)` check; after sleep, if still at same level → fire notification
4. On level change back to `.normal` from any elevated state: cancel pending critical notification, fire recovery notification (if `notifyRecovery` enabled)
5. `sendCriticalNotification()` — `UNMutableNotificationContent`; title "⚠️ Memory Pressure Critical"; body "X.X GB used (N%) — Top process: \(topProcessName) using Y GB"; add action category "MEMSNAP_CRITICAL" with action button "Show Top Process"
6. `sendRecoveryNotification()` — title "✅ Memory Pressure Normal"; body "Pressure returned to normal. \(freeGB) GB now available"
7. Register `UNNotificationCategory` with `UNNotificationAction(identifier: "SHOW_TOP", title: "Show Top Process", options: .foreground)`; assign to `UNUserNotificationCenter`
8. Implement `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` — on "SHOW_TOP" action, call `TrayController.shared.openPopover()`
9. `requestPermission()` — call once in `init()`; store granted Bool in `UserDefaults`
10. Check `MemSnapSettings.shared.notifyCritical` / `notifyRecovery` / `notificationDurationThreshold` before firing

**Relevant Context**:
- `UserNotifications` framework — no SPM dep, just framework linkage in Package.swift
- `beeMon` has no notifications — this is entirely new

**Status**: `[ ] pending`

---

### Sub-Task 9 — AutoKillManager

**Intent**: Watch user-configured auto-kill rules and automatically SIGTERM a process when its RSS exceeds the configured threshold.

**Expected Outcomes**:
- `AutoKillManager.shared` watches `ProcessMonitor.shared.topProcesses` every 2s
- User can add rules: "if process named X exceeds Y MB, auto-kill it"
- Rules stored in `UserDefaults` as `[AutoKillRule]` (Codable)
- When a rule fires, it sends SIGTERM and records the event in a log visible in Settings
- Respects a cooldown: same process not auto-killed more than once per 60 seconds

**Todo List**:
1. Define `AutoKillRule: Codable, Identifiable` — `id: UUID`, `processName: String`, `thresholdMB: Double`, `enabled: Bool`
2. Define `AutoKillEvent` — `timestamp: Date`, `processName: String`, `rssAtKillMB: Double`
3. `AutoKillManager: ObservableObject` — `@MainActor`, `static let shared`; `@Published var rules: [AutoKillRule]`; `@Published var recentEvents: [AutoKillEvent]` (last 20)
4. Load rules from `UserDefaults` in `init()`; subscribe to `ProcessMonitor.shared.$topProcesses` via `.sink`
5. On each emission: iterate rules where `enabled == true`; find matching process by name; if `rssBytes / 1_048_576 > rule.thresholdMB` and not in `killCooldowns` dict → fire kill
6. `cooldowns: [Int: Date]` — keyed by PID; skip if `Date().timeIntervalSince(cooldowns[pid]) < 60`
7. On kill: `kill(pid_t(pid), SIGTERM)`; append `AutoKillEvent` to `recentEvents`; update `cooldowns[pid]`
8. Persist `rules` to `UserDefaults` (Codable JSON) on any mutation
9. `AutoKillRulesView` in Settings — list of rules with add/delete; `AutoKillLogView` — scrollable list of `recentEvents`

**Relevant Context**:
- `ProcessMonitor` from Sub-Task 3
- `import Darwin` for `kill()`, `SIGTERM`

**Status**: `[ ] pending`

---

### Sub-Task 10 — SettingsView

**Intent**: Build an in-popover settings panel with all configurable options including new advanced features.

**Expected Outcomes**:
- `MemSnapSettings` singleton backed by `@AppStorage`; all settings take effect immediately
- Settings navigated to via gear ⚙ in the popover header

**Settings**:
| Setting | Type | Default |
|---|---|---|
| `iconStyle` | Enum: segmentedBar / sparkline / arcGauge / pieChart | `segmentedBar` |
| `confirmBeforeKill` | Bool | `true` |
| `notifyCritical` | Bool | `true` |
| `notifyRecovery` | Bool | `true` |
| `notificationDurationThreshold` | Int (seconds) | `10` |
| `launchAtLogin` | Bool | `false` |
| `historyWindowMinutes` | Int: 1 / 5 / 15 | `5` |
| `pressureThresholdElevated` | Double (%) | `60` |
| `pressureThresholdWarning` | Double (%) | `80` |
| `pressureThresholdCritical` | Double (%) | `90` |

**Todo List**:
1. `MemSnapSettings: ObservableObject` — `@MainActor`, `static let shared`; each setting as `@AppStorage`-backed var
2. `SettingsView` — SwiftUI Form with sections: Display, Notifications, Kill Behavior, Thresholds, Auto-Kill Rules, Launch
3. `IconStylePicker` — `Picker` with all 4 styles + small preview icon per style
4. `NotificationDurationStepper` — `Stepper("Notify after \(N)s at critical", value: $threshold, in: 0...60, step: 5)`
5. `ThresholdSection` — 3 sliders (elevated/warning/critical %) with live preview of color indicators
6. `AutoKillRulesSection` — embed `AutoKillRulesView` + `AutoKillLogView` from Sub-Task 9
7. `LaunchAtLoginToggle` — reuse `LoginItemManager` from `beeMon`
8. Navigation: `@State var showSettings: Bool` in `PopoverRootView` controls overlay

**Relevant Context**:
- `beeMon/Sources/beeMon/LoginItemManager.swift` — reuse verbatim
- `netBee` `@AppStorage` pattern

**Status**: `[ ] pending`

---

### Sub-Task 11 — About Window

**Intent**: Build a fun, animated About window matching the style of `beeMon` and `netBee` — with multiple animated elements, live data, version display, and the tagline.

**Expected Outcomes**:
- Standalone `NSWindow` (760w × 580h), dark background, no title bar, movable by background
- Animated hero canvas: floating RAM cell particles orbiting a central "brain" node, connected by fading lines (inspired by `netBee`'s star network)
- Animated hex grid background (matching `beeMon`/`beeKey` style)
- Pulsing glow ring around app icon (🧠 emoji or custom memory icon)
- Live pressure sparkline (40 samples, updates every 0.15s with real `MemoryMonitor` data)
- Live memory donut chart (wired / compressed / app / free, real data, animates on value change)
- Version number: "VERSION 1.0.0" (reads from `App.version` constant)
- Feature pills grid (2 cols × 4 rows — 8 key features)
- System info footer capsules: CPU cores / RAM size / macOS version
- Tagline: *"From the minds of Daneyand & IBM Bob"* with 🧠 + 🤖 emojis

**Animated Elements (detailed)**:
1. **RAM Cell Particles** — 10 floating nodes labeled "RAM", "HEAP", "WIRED", "CACHE", etc.; orbit a center point at varying speeds (0.15–0.80 cycles/s); drawn on `TimelineView` canvas; connection lines between nearby nodes fade by distance
2. **Hex Grid Background** — rotates 8s linear, subtle phase drift; opacity 0.06; matches `beeMon` pattern
3. **Pulsing Glow Ring** — 2.0s `.easeOut` repeat; scale 1.0→1.5; opacity fades as it expands
4. **Live Pressure Sparkline** — 300×36 canvas; reads `MemoryMonitor.shared.pressureHistory`; updates every 0.5s; filled area with `pressureLevel.color` gradient
5. **Live Memory Donut** — 80×80 canvas donut; arcs for wired/compressed/app/free; animated arc length changes when proportions shift; center label shows total used %
6. **Animated Counter** — RAM total displayed as a counting-up number on first open (0 → actual GB over 1.5s)
7. **Pressure Level Badge** — capsule showing current level name + color, pulses on level change

**Feature Pills** (8 features, 2-col grid):
- Kernel Pressure API
- Configurable Icon Styles
- Process Kill & Focus
- Smart Notifications
- Memory Trend Prediction
- Auto-Kill Rules
- Hourly Pressure Heatmap
- CSV Export & Purge

**Todo List**:
1. Create `AboutWindowController` — creates and caches `NSWindow` (760×580); `isReleasedWhenClosed = false`; dark background; movable by background
2. Create `AboutView: View` — `@State` animation phases for ring pulse, hex drift, particle orbit; `@StateObject var mem = MemoryMonitor.shared`
3. Implement `ParticleNetworkCanvas` — `TimelineView(.animation)` + `Canvas`; define `RAMParticle` struct (angle, radius, speed, label); draw circles + labels + distance-faded lines
4. Implement `HexGridBackground` — port from `beeMon/AboutView.swift`; use `@State var hexPhase` animated with `withAnimation(.linear(duration: 8).repeatForever(autoreverses: false))`
5. Implement `PulsingRingView` — port from `beeMon/AboutView.swift`; scale+opacity animation
6. Implement `LivePressureSparkline` — `Canvas` over `MemoryMonitor.shared.pressureHistory`; timer updates every 0.5s; filled gradient in `pressureLevel.color`
7. Implement `LiveMemoryDonut` — `Canvas` drawing 4 arc segments; `withAnimation(.spring())` on data change; center `Text` showing used %
8. Implement `AnimatedCounterView` — animates from 0 to `totalGB` over 1.5s using `withAnimation` + `@State var displayed: Double`; shows "X.X GB RAM"
9. Implement `FeaturePillGrid` — 2-col `LazyVGrid` of `Text` pill views in `DS.surface` rounded rects with pressure-level colored dot prefix
10. Footer: `SystemInfoCapsules` — CPU core count via `ProcessInfo.processInfo.processorCount`, RAM via `ProcessInfo.processInfo.physicalMemory`, macOS via `ProcessInfo.processInfo.operatingSystemVersionString`
11. Tagline row: `Text("From the minds of Daneyand & IBM Bob")` with `Text("🧠")` + `Text("🤖")` flanking
12. Version row: `Text("VERSION \(App.version)")` in DS monospace font, muted color
13. Wire "About memSnap…" context menu item in `TrayController` to call `AboutWindowController.shared.show()`

**Relevant Context**:
- `beeMon/Sources/beeMon/Views/AboutView.swift` — hex grid, pulsing ring, live sparkline, system info capsules (port these)
- `netBee/Sources/netBee/Views/AboutView.swift` — `ParticleNetworkCanvas` star orbits + connection lines (adapt node labels to RAM/HEAP/WIRED/CACHE theme)
- `App.version` constant from Sub-Task 1 `AppConstants.swift`
- `netBee` reads version from `Bundle.main.infoDictionary["CFBundleShortVersionString"]` — use `App.version` constant instead to guarantee sync

**Status**: `[ ] pending`

---

### Sub-Task 12 — Build, README & GitHub Release v1.0.0

**Intent**: Produce the release DMG, write the verbose README, and publish the v1.0.0 GitHub release.

**Expected Outcomes**:
- `build.sh` produces code-signed `.app` + `.dmg` named `memSnap-1.0.0.dmg` in `build/`
- README has badges, animated GIF placeholder, feature grid, install instructions, permission notes, tagline
- GitHub release `v1.0.0` created via `gh release create` with DMG attached
- Tagline appears verbatim in README and release body

**Todo List**:
1. Run `./build.sh --local` to verify DMG builds and app launches cleanly
2. Write `README.md`:
   - Badges: macOS 13+, Swift 5.9, License MIT, Version 1.0.0
   - Hero description paragraph
   - Feature grid table (all features from plan)
   - Screenshots/GIF section (placeholder paths)
   - Install: drag to Applications; grant Accessibility in System Settings for Focus action
   - Permissions needed: Accessibility (process focus), Notifications (pressure alerts)
   - Tagline: `> *From the minds of Daneyand & IBM Bob*`
3. Confirm `App.version = "1.0.0"` and `Info.plist CFBundleShortVersionString = "1.0.0"` match `VERSION` in `build.sh`
4. Run `./build.sh` (no flags) — commits build artifact, creates `v1.0.0` tag, publishes GitHub release with DMG asset and release notes including tagline

**Relevant Context**:
- `beeMon/build.sh` — adapt; change `APP_NAME`, `BUNDLE_ID`, `VERSION=1.0.0`
- `beeMon/README.md` — badge format and structure reference
- AGENTS.md project rule: tagline must be `*From the minds of IBM Bob & Daneyand*` — NOTE: user has confirmed the canonical form is **"From the minds of Daneyand & IBM Bob"** for this project

**Status**: `[ ] pending`

---

## Key Decisions Log

| Decision | Choice | Rationale |
|---|---|---|
| Default icon | Segmented bar (wired/compressed/app/free) | Most information-dense |
| Icon styles | All 4, configurable | User preference |
| App icons in process list | Yes, via NSWorkspace | Polished look |
| Kill confirmation | Configurable, default on | Safety first |
| Kill sequence | SIGTERM → 3s poll → offer SIGKILL | Matches macOS Force Quit |
| Notifications | Critical + Recovery, configurable | Actionable, not noisy |
| Notification de-bounce | Duration threshold (default 10s) | Prevents false-alarm spikes |
| Notification action | "Show Top Process" button | Actionable notification |
| Trend prediction | Slope-based "N min until critical" | High UX impact, minimal code |
| Growth indicators | ↑↓— per process, 30s delta | Catches memory leaks live |
| Heatmap | 24-column hourly peak | Spot daily patterns |
| Purge button | `memory_pressure` shell call | No other tool surfaces this |
| CSV export | Desktop dump of full history | Debug chronic issues |
| Auto-kill rules | User-configured name+MB rules | Headless protection |
| App name | memSnap | Fits `proc*` utility family |
| Version | 1.0.0 | First release |
| Tagline | "From the minds of Daneyand & IBM Bob" | User confirmed canonical form |
| About window | 760×580, animated particles + donut + sparkline | Matches beeMon/netBee fun style |
