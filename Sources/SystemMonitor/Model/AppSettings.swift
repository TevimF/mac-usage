import Combine
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum IconStyle: String, Codable, CaseIterable, Identifiable {
    // Raw values are what old installs persisted — they stay Portuguese
    // even though they read like labels; display goes through `label`.
    case numeric = "Numérico"
    case sparkline = "Sparkline"
    case capsule = "Cápsula de vidro"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .numeric: return L10n.t("Numérico", "Numeric")
        case .sparkline: return "Sparkline"
        case .capsule: return L10n.t("Cápsula de vidro", "Glass capsule")
        }
    }
}

enum SampleInterval: Double, Codable, CaseIterable, Identifiable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5

    var id: Double { rawValue }
    var label: String {
        switch self {
        case .oneSecond: return "1 s"
        case .twoSeconds: return "2 s"
        case .fiveSeconds: return "5 s"
        }
    }
}

/// The four accent options from the design spec's "Aparência" section.
enum AccentOption: String, Codable, CaseIterable, Identifiable {
    case cyan = "#64D2FF"
    case blue = "#0A84FF"
    case green = "#30D158"
    case purple = "#BF5AF2"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cyan: return L10n.t("Ciano", "Cyan")
        case .blue: return L10n.t("Azul", "Blue")
        case .green: return L10n.t("Verde", "Green")
        case .purple: return L10n.t("Roxo", "Purple")
        }
    }
}

/// How long a keep-awake activation lasts before switching itself back off.
/// `.indefinite` behaves like the plain on/off toggle this started as —
/// stays on until you click it again.
enum KeepAwakeDuration: Double, Codable, CaseIterable, Identifiable {
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400
    case indefinite = 0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        case .oneHour: return "1 h"
        case .twoHours: return "2 h"
        case .fourHours: return "4 h"
        case .indefinite: return L10n.t("Até desativar", "Until turned off")
        }
    }
}

/// How the menu bar icons pick up color.
enum IconColorMode: String, Codable, CaseIterable, Identifiable {
    /// Always the plain white/black that matches the menu bar's own text —
    /// only the global critical state (CPU stuck above 90%) overrides it.
    case neutral
    /// One fixed color per metric (CPU takes the accent, RAM/swap indigo,
    /// disk/thermal orange, network green) — always on, regardless of the
    /// reading.
    case perMetric
    /// Neutral at rest, sliding toward orange then red as that metric's own
    /// value climbs — RAM at 40% is white, RAM at 95% is red. Thermal keeps
    /// its own state-based color in every mode; network/disk throughput
    /// don't have a "too high is bad" reading, so they stay neutral here.
    case byValue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .neutral: return L10n.t("Neutro", "Neutral")
        case .perMetric: return L10n.t("Uma cor por métrica", "One color per metric")
        case .byValue: return L10n.t("Muda com o uso", "Changes with usage")
        }
    }
}

/// One block of the popover panel. Header, keep-awake and footer always
/// stay put; these are the middle sections the user can reorder.
enum PanelSection: String, Codable, CaseIterable, Identifiable {
    case cpu, grid, processes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .grid: return L10n.t("Métricas", "Metrics")
        case .processes: return L10n.t("Maiores consumos", "Top consumers")
        }
    }
}

extension PanelSection: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .systemMonitorPanelSection)
    }
}

/// Migration-only shape of the old "status item slot" model (one
/// NSStatusItem per slot, up to 4 metrics each). Superseded by
/// `metricOrder` — a single reorderable list where only the first two
/// entries show in the menu bar and the rest live in the panel. Kept here
/// so existing installs decode instead of silently resetting every other
/// setting; never written back once `metricOrder` exists.
private struct LegacyStatusItemSlot: Codable {
    var metrics: [MetricKind]
}

private struct PersistedSettings: Codable {
    var accent: AccentOption
    var iconStyle: IconStyle
    var sampleInterval: SampleInterval
    var showProcesses: Bool
    var launchAtLogin: Bool
    // Optional so decoding a settings blob saved before this field existed
    // doesn't throw and silently reset every other setting back to
    // defaults — Codable synthesis treats a missing key on an Optional
    // property as nil rather than a decode failure.
    var keepAwakeDuration: KeepAwakeDuration?
    // Raw strings, not [PanelSection]: a stored section that no longer
    // exists (e.g. "memoryDisk", merged into the grid) must degrade to
    // "ignore that entry", not fail the decode and reset every setting.
    var panelSectionOrder: [String]?
    var iconColorMode: IconColorMode?
    var metricOrder: [MetricKind]?
    var barMetricCount: Int?
    var language: AppLanguage?
    var statusItemSlots: [LegacyStatusItemSlot]?
}

/// Single source of truth for user-configurable behavior. Persisted as one
/// JSON blob in UserDefaults — simpler than N separate keys and atomic to
/// read/write.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var accent: AccentOption { didSet { persist() } }
    @Published var iconStyle: IconStyle { didSet { persist() } }
    @Published var sampleInterval: SampleInterval { didSet { persist() } }
    @Published var showProcesses: Bool { didSet { persist() } }
    @Published var launchAtLogin: Bool {
        didSet {
            persist()
            LoginItem.setEnabled(launchAtLogin)
        }
    }
    @Published var keepAwakeDuration: KeepAwakeDuration { didSet { persist() } }
    @Published var panelSectionOrder: [PanelSection] { didSet { persist() } }
    @Published var iconColorMode: IconColorMode { didSet { persist() } }
    /// Every available metric, in priority order. Only the front slice —
    /// `barMetricCount` entries — shows in the menu bar (as one combined
    /// status item); the rest are panel-only. Reordering here is what the
    /// drag list in Settings edits.
    @Published var metricOrder: [MetricKind] { didSet { persist() } }
    /// How many entries from the front of `metricOrder` fit in the bar.
    /// Kept as a setting (not a fixed 2) because at 1 the bar item is a
    /// single non-dual-value metric, which is the only case `iconStyle`
    /// (numeric/sparkline/capsule) has any effect on — pinning this to 2
    /// would make that whole setting permanently dead.
    @Published var barMetricCount: Int { didSet { persist() } }
    @Published var language: AppLanguage { didSet { persist() } }

    private static let defaultsKey = "com.estevaofonseca.systemmonitor.settings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(PersistedSettings.self, from: data) {
            accent = decoded.accent
            iconStyle = decoded.iconStyle
            sampleInterval = decoded.sampleInterval
            showProcesses = decoded.showProcesses
            launchAtLogin = decoded.launchAtLogin
            keepAwakeDuration = decoded.keepAwakeDuration ?? .thirtyMinutes
            panelSectionOrder = Self.resolveSectionOrder(decoded.panelSectionOrder)
            iconColorMode = decoded.iconColorMode ?? .neutral
            metricOrder = Self.resolveMetricOrder(decoded: decoded)
            barMetricCount = Self.resolveBarMetricCount(decoded: decoded)
            language = decoded.language ?? .portuguese
        } else {
            accent = .cyan
            iconStyle = .capsule
            sampleInterval = .twoSeconds
            showProcesses = true
            launchAtLogin = false
            keepAwakeDuration = .thirtyMinutes
            panelSectionOrder = PanelSection.allCases
            iconColorMode = .neutral
            metricOrder = MetricKind.allCases.filter(\.isAvailable)
            barMetricCount = 1
            language = .portuguese
        }
        // didSet doesn't fire for this initializer's own assignment above,
        // so a persisted `true` is never pushed to SMAppService just by
        // launching. Reconcile explicitly — registration can silently drop
        // (e.g. a rebuild re-signing the .app in place) with nothing else
        // to notice or restore it.
        LoginItem.setEnabled(launchAtLogin)
    }

    /// Maps stored section names to today's sections — the old
    /// "memoryDisk" (its tiles merged into the grid) folds into `.grid`,
    /// anything unknown is dropped, and any section missing from the
    /// stored order is appended so new sections always show up.
    private static func resolveSectionOrder(_ stored: [String]?) -> [PanelSection] {
        let mapped = (stored ?? []).compactMap { raw -> PanelSection? in
            raw == "memoryDisk" ? .grid : PanelSection(rawValue: raw)
        }
        var seen = Set<PanelSection>()
        let unique = mapped.filter { seen.insert($0).inserted }
        return unique + PanelSection.allCases.filter { !unique.contains($0) }
    }

    /// Prefers the current `metricOrder` field; falls back to flattening
    /// the old per-slot model; backfills either with any available metric
    /// missing from the stored order (e.g. one added in a later version).
    private static func resolveMetricOrder(decoded: PersistedSettings) -> [MetricKind] {
        let available = MetricKind.allCases.filter(\.isAvailable)
        if let stored = decoded.metricOrder {
            let known = stored.filter(available.contains)
            return known + available.filter { !known.contains($0) }
        }
        if let legacySlots = decoded.statusItemSlots {
            var seen = Set<MetricKind>()
            let flattened = legacySlots.flatMap(\.metrics)
                .filter(available.contains)
                .filter { seen.insert($0).inserted }
            return flattened + available.filter { !flattened.contains($0) }
        }
        return available
    }

    /// Prefers the current `barMetricCount`; falls back to however many
    /// metrics were in the first legacy slot (clamped to 1–2, since that's
    /// all a single combined item can hold); defaults to 1 — the same
    /// single-metric bar a fresh install always started with.
    private static func resolveBarMetricCount(decoded: PersistedSettings) -> Int {
        if let stored = decoded.barMetricCount {
            return min(max(stored, 1), 2)
        }
        if let firstSlotCount = decoded.statusItemSlots?.first?.metrics.count {
            return min(max(firstSlotCount, 1), 2)
        }
        return 1
    }

    private func persist() {
        let snapshot = PersistedSettings(
            accent: accent,
            iconStyle: iconStyle,
            sampleInterval: sampleInterval,
            showProcesses: showProcesses,
            launchAtLogin: launchAtLogin,
            keepAwakeDuration: keepAwakeDuration,
            panelSectionOrder: panelSectionOrder.map(\.rawValue),
            iconColorMode: iconColorMode,
            metricOrder: metricOrder,
            barMetricCount: barMetricCount,
            language: language,
            statusItemSlots: nil
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
