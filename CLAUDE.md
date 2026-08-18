# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Mac usage" — a native macOS menu bar app (AppKit + SwiftUI) that shows system
resources (CPU, memory, swap, disk, network, thermal, battery) without an
Electron wrapper. Metrics come straight from Mach/libproc/IOKit — no
subprocess spawning, no polling faster than necessary (sampling backs off to
5s while the panel is closed).

## Commands

Build and run (release, packaged as a real `.app`):

```bash
./Scripts/build_app.sh
open "Mac usage.app"
```

`build_app.sh` runs `swift build -c release`, generates the app icon if
missing (`Scripts/build_icon.sh`), assembles `Mac usage.app`, and ad-hoc
codesigns it so Gatekeeper doesn't complain locally.

For local iteration without repackaging:

```bash
swift build && .build/debug/SystemMonitor
```

No test target exists in `Package.swift` — there is no `swift test` command
to run.

There is no `.xcodeproj`; it's a plain Swift Package (`swift-tools-version:5.9`,
macOS 14+ minimum, Liquid Glass panel material needs macOS 26).

## Architecture

**Single source of truth for metrics.** `SystemMetricsEngine.shared`
(`Metrics/SystemMetricsEngine.swift`) owns one `DispatchSourceTimer` and
publishes one `@Published var sample: MetricSample`. Every status item and
the panel observe that same sample — nothing samples twice per tick. The
timer runs on a dedicated serial queue (not `.global(qos:)`) specifically so
overlapping ticks can't race on the samplers' internal mutable state
(`previousLoad`, `previousTimes`, `lastBytesIn`, etc). `tick()` must only
ever run on that queue — anything that wants an immediate re-sample hops
there (`timerQueue.async`) or reschedules the timer with
`fireImmediately: true`; never call it from the main thread.

**One metrics status item, fed by a reorderable metric list.**
`AppSettings.metricOrder` holds every available `MetricKind` in priority
order; only the first `barMetricCount` (1–2) render in the menu bar, as a
single combined `NSStatusItem` owned by `MenuBarController`. The item count
never changes — reordering or resizing just redraws the same item's image.
The keep-awake coffee cup is a second, fixed status item
(`KeepAwakeStatusItemController`) that toggles the assertion directly and
never opens the panel.

**Status item width must stay stable between ticks.** The panel is an
NSPopover anchored to the metrics button, so any width change while it's
open slides the panel around on screen. `StatusItemContentRenderer` draws
each value right-aligned inside a slot sized by
`reservedValueTemplate(for:)` (the metric's widest plausible reading, e.g.
"100%") instead of by today's digits. Keep that property when touching the
renderer.

**Icon rendering only reacts to style for a lone CPU-only bar.**
`StatusItemContentRenderer.render` branches on metric count: a single
non-dual-value metric goes through `renderSingle`, everything else
(multiple metrics, or one dual-value metric like network/diskIO) goes
through `renderRow`. `IconStyle` (numeric / sparkline / capsule) is only
consulted inside `renderSingle`, and the sparkline sub-path additionally
requires `metric == .cpu`. `renderRow` does not take a `style` parameter at
all — which is why the Settings picker for icon style only appears when the
bar shows CPU alone.

**Settings persistence.** `AppSettings` (`Model/AppSettings.swift`) is an
`ObservableObject` singleton (`AppSettings.shared`) backed by `UserDefaults`,
encoding/decoding itself as one JSON blob under
`com.estevaofonseca.systemmonitor.settings`. Every `@Published` property's
`didSet` calls `persist()`. `MenuBarController` and `SystemMetricsEngine`
both subscribe to individual `$property` publishers (with `.dropFirst()` to
skip the initial replay) rather than re-reading `AppSettings.shared`
imperatively.

**Login item** goes through `ServiceManagement.SMAppService.mainApp`
(`Support/LoginItem.swift`), the macOS 13+ replacement for the legacy
`SMLoginItemSetEnabled`. It only registers the current app bundle — if the
raw debug binary (`.build/.../debug/SystemMonitor`) ever gets launched
outside the `.app` wrapper while a login-item toggle fires, macOS registers
*that* bare executable as a separate login item, which then opens a Terminal
window at login to run it. Stale entries like that have to be removed by
hand from System Settings → Login Items; the app has no way to see or clean
up login items it didn't create itself.

**Directory layout** (see `README.md` for the full feature list):

```
Sources/SystemMonitor/
  App/       entry point (LSUIElement, no Dock icon)
  Metrics/   samplers (CPU, memory, disk, network, thermal, battery, processes)
             + SystemMetricsEngine, the polling engine that owns them
  MenuBar/   status item icon rendering, tooltips, the SF Symbol icon family
  Panel/     the SwiftUI popover shown on click
  Settings/  the Settings window
  Model/     AppSettings (persisted user settings)
  Support/   formatting, color, and login-item helpers
```

## Notes specific to this codebase

- Images drawn for status items are **non-template** (explicit colors), not
  auto-tinted — deliberate, so accent/critical colors render as real color in
  the menu bar instead of system monochrome. This is the one place the code
  diverges from the usual "mark as template image" convention.
- Status item image padding is kept at zero on purpose
  (`StatusItemContentRenderer.sidePadding`) — macOS already pads each status
  item itself (and wraps it in a glass capsule on macOS 26), so baked-in
  padding stacks on top of the system's and doubles up between adjacent
  items.
- Real CPU temperature and GPU utilization are intentionally not implemented
  — see the "What's not in here" section of `README.md` for why (private
  entitlement / root requirements that don't work for a third-party app).
