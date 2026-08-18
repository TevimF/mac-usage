# Mac usage

A native macOS menu bar app for watching your Mac's resources — CPU, memory,
swap, disk, network, thermal state and battery — without the overhead of an
Electron wrapper.

Built with AppKit + SwiftUI. No subprocess spawning, no polling loops faster
than necessary: metrics come straight from Mach/libproc/IOKit, sampling backs
off to once every 5 seconds while the panel is closed, and the menu bar icons
only redraw when a new sample actually lands.

## Features

- One or more menu bar items, each showing 1–2 metrics you pick in Settings
  (network always gets its own item — it already carries both a download and
  an upload number)
- Three icon styles: plain number, sparkline, or a value inside a glass
  capsule (Liquid Glass on macOS 26, `NSVisualEffectView` fallback below that)
- Hover a status item for a live tooltip with the detail behind the number
- Click any item to open the same panel — CPU trend chart, memory breakdown
  (active/wired/compressed), disk, network, thermal state, battery, and a
  ranked list of the processes eating the most CPU
- A critical state (red, faster pulse, collapsed footer) kicks in when CPU
  stays above 90% for a few consecutive samples — with hysteresis, so it
  doesn't flicker right at the threshold
- Configurable accent color, sampling interval, and an optional "open at
  login" toggle (via `SMAppService`, the current API — no legacy login items)

### What's not in here

Raw CPU temperature isn't shown. `IOConnectCallStructMethod` against
`AppleSMC` returns `kIOReturnNotPrivileged` for third-party processes on
current macOS — reading real SMC sensor keys needs a private entitlement
Apple doesn't grant outside its own apps. The thermal card instead uses
`ProcessInfo.thermalState`, the public API, which gives you a qualitative
nominal/fair/serious/critical reading rather than a fabricated number.

GPU has an icon reserved in the metric family but no data source — reliable
GPU utilization on Apple Silicon isn't available through public APIs without
`powermetrics`, which requires root.

## Requirements

- macOS 14+ (Liquid Glass panel material requires macOS 26; everything else
  works down to 14)
- Xcode / Swift toolchain to build

## Building

```bash
./Scripts/build_app.sh
```

This runs `swift build -c release`, generates the app icon if it isn't
already built, assembles `Mac usage.app`, and ad-hoc codesigns it so
Gatekeeper doesn't complain on your own machine. Then:

```bash
open "Mac usage.app"
```

For local development without repackaging every time:

```bash
swift build && .build/debug/SystemMonitor
```

## Project layout

```
Sources/SystemMonitor/
  App/       entry point (LSUIElement, no Dock icon)
  Metrics/   samplers (CPU, memory, disk, network, thermal, battery, processes)
             + the polling engine that owns them
  MenuBar/   status item icon rendering, tooltips, the SF Symbol icon family
  Panel/     the SwiftUI popover shown on click
  Settings/  the Settings window
  Model/     persisted user settings
  Support/   formatting, color, and login-item helpers
Scripts/     build_app.sh, build_icon.sh, generate_app_icon.swift
```

No `.xcodeproj` — it's a plain Swift Package with a shell script that
assembles the `.app` bundle, so the whole thing builds from the command line.

## License

GPLv3 — see [LICENSE](LICENSE).
