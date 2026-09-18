# memSnap Changelog

---

## v1.0.2 — 2025-09-18

### Fixed
- **Right-click Settings menu item broken.** The "Settings…" item in the right-click context menu was calling `openPopover()` instead of `SettingsWindowController.shared.show()` — a stale TODO comment from Sub-Task 4 that never got updated. Settings now opens correctly from both the popover gear icon and the context menu.

### Added
- **Original app icon.** Designed a custom 1024×1024 SVG icon: dark circuit-board background, dual-hemisphere brain with gradient (blue → violet → green), RAM chip slots on all four sides, pressure-level colored dots on the brain surface (green/amber/orange/red/violet), and a pressure gauge arc at the bottom. Converted to `.icns` (all sizes 16–1024 + @2x) and bundled into the app. Icon is now visible in the DMG, Dock, Spotlight, and Launchpad.
- **Verbose README.** Rewrote `README.md` with tagline front-and-center at the top, full feature documentation, architecture diagram, install options, permissions table, and changelog summary. Tagline appears at the top and bottom of the document.

---

## v1.0.1 — 2025-09-18

### Fixed
- **About window — tagline no longer clipped.** "From the minds of Daneyand & IBM Bob" was truncated to "From the minds of Daneya…" because it was placed inside a 200px-wide left column. The tagline is now a dedicated full-width footer row spanning the entire 760px window, sitting between the live data strip and the window bottom edge.
- **Settings window — replaced unusable in-popover overlay with a standalone window.** Settings previously rendered inside the 360px popover (effectively ~332px with padding), making segmented pickers, sliders, and toggles extremely cramped. Settings now opens as a proper resizable 500×700 `NSWindow` (same pattern as the About window), giving every control the space it needs. Clicking the ⚙ gear icon in the popover opens the Settings window; it can remain open independently of the popover.
- **Installer DMG — upgraded from bare archive to proper drag-to-install DMG.** The original DMG was a plain `hdiutil create` containing only the `.app`. The new DMG uses the standard macOS installer layout: app icon on the left, `/Applications` symlink on the right, AppleScript-styled Finder window (500×300, icon view, 96px icons), and a `README.txt` with install/uninstall/permissions instructions.

### Changed
- About window height increased from 580px to 610px to accommodate the new full-width tagline footer row.
- Settings is now hosted by `SettingsWindowController` (a `@MainActor` singleton), consistent with `AboutWindowController`.
- `PopoverRootView` simplified — removed `showSettings` / `showAbout` state, removed in-popover conditional branch.

---

## v1.0.0 — 2025-09-18

### Initial Release

**memSnap** is a native macOS menu-bar utility that monitors system memory pressure in real time.

#### Features
- **5-level pressure detection** — Normal / Elevated / Warning / Critical / Swap — computed from both the macOS kernel `kIOResourceMemoryPressureKey` and configurable raw-percentage thresholds, taking the worse of the two signals.
- **4 configurable tray icon styles** — Segmented bar (default, shows wired/compressed/app/free proportions), Sparkline (40-sample pressure trend), Arc gauge (semicircle fill), Pie chart (proportional wedges). All rendered via `NSBitmapImageRep` + `NSBezierPath` at 1 Hz.
- **Memory breakdown popover** — Segmented bar showing wired (blue) / compressed (violet) / app (amber) / free (dark) proportions with GB labels. Trend prediction label shows "~N min until critical" based on linear regression slope over last 60 samples.
- **Pressure history sparkline** — Canvas-drawn filled area with 3 faint threshold lines; 1m / 5m / 15m time-window picker.
- **Swap indicator** — Violet bar rendered only when swap is in use.
- **Top-8 processes by RSS** — App icon (via NSWorkspace), name, memory, CPU%, growth arrow (↑↓—) with MB/min rate, Kill (⚡ SIGTERM → 3s poll → offer SIGKILL) and Focus (⬆ NSRunningApplication.activate) buttons. System processes (PID < 100) are protected.
- **Process memory growth tracking** — RSS delta tracked per-PID over a 30-second rolling window; processes growing > 5 MB/min flagged with red ↑.
- **24-hour hourly pressure heatmap** — 24 color-coded squares showing peak pressure level per hour; current hour pulses; future hours shown as empty surface.
- **Purge cache** — One-click button calls `memory_pressure -S -l warn` to flush disk caches. Shows "✓ Done" confirmation for 2 seconds.
- **Export CSV** — Dumps full pressure history to Desktop as `memSnap-export-YYYY-MM-DD-HH-mm.csv` (timestamp, level, wired_mb, compressed_mb, app_mb, free_mb, swap_mb). Reveals file in Finder on save.
- **Smart notifications** — Critical and recovery alerts via `UNUserNotificationCenter`. Duration-threshold debounce (default 10s) prevents false-alarm spikes. Critical notification includes a "Show Top Process" action button that opens the popover. Both alert types individually configurable.
- **Auto-kill rules** — User-defined rules: process name + RSS threshold in MB. When a matching process exceeds the threshold, `SIGTERM` is sent automatically. 60-second per-PID cooldown prevents re-kill loops. Kill log shows last 20 events with relative timestamps. Rules persisted in `UserDefaults` as Codable JSON.
- **Settings** — All preferences configurable with live effect: icon style, pressure thresholds (elevated/warning/critical %), notification timing, kill confirmation, auto-kill rules, launch at login.
- **Animated About window** — 760×610 dark window with: RAM particle network canvas (10 orbiting nodes: RAM/HEAP/WIRED/CACHE/SWAP/APP/FREE/KERN/DISK/VRAM), animated hex grid background, pulsing glow ring around 🧠 icon, live pressure sparkline, live memory donut chart (spring-animated), animated GB RAM counter (counts up from 0), feature pills grid, system info capsules, tagline footer.
- **macOS 13+ / Swift 5.9 / zero external dependencies.**

---

*From the minds of Daneyand & IBM Bob*
