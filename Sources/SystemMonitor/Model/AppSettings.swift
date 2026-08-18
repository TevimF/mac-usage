import Foundation
import Combine

enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case numeric = "Numérico"
    case sparkline = "Sparkline"
    case capsule = "Cápsula de vidro"

    var id: String { rawValue }
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

/// A group of 1–2 metrics rendered together as a single NSStatusItem,
/// per the design's "no máximo duas métricas por item" rule.
struct StatusItemSlot: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var metrics: [MetricKind]
}

/// The four accent options from the design spec's "Aparência" section.
enum AccentOption: String, Codable, CaseIterable, Identifiable {
    case cyan = "#64D2FF"
    case blue = "#0A84FF"
    case green = "#30D158"
    case purple = "#BF5AF2"

    var id: String { rawValue }
}

private struct PersistedSettings: Codable {
    var accent: AccentOption
    var iconStyle: IconStyle
    var sampleInterval: SampleInterval
    var showProcesses: Bool
    var launchAtLogin: Bool
    var statusItemSlots: [StatusItemSlot]
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
    @Published var statusItemSlots: [StatusItemSlot] { didSet { persist() } }

    private static let defaultsKey = "com.estevaofonseca.systemmonitor.settings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(PersistedSettings.self, from: data) {
            accent = decoded.accent
            iconStyle = decoded.iconStyle
            sampleInterval = decoded.sampleInterval
            showProcesses = decoded.showProcesses
            launchAtLogin = decoded.launchAtLogin
            statusItemSlots = decoded.statusItemSlots
        } else {
            accent = .cyan
            iconStyle = .capsule
            sampleInterval = .twoSeconds
            showProcesses = true
            launchAtLogin = false
            statusItemSlots = [StatusItemSlot(metrics: [.cpu])]
        }
        // didSet doesn't fire for this initializer's own assignment above,
        // so a persisted `true` is never pushed to SMAppService just by
        // launching. Reconcile explicitly — registration can silently drop
        // (e.g. a rebuild re-signing the .app in place) with nothing else
        // to notice or restore it.
        LoginItem.setEnabled(launchAtLogin)
    }

    private func persist() {
        let snapshot = PersistedSettings(
            accent: accent,
            iconStyle: iconStyle,
            sampleInterval: sampleInterval,
            showProcesses: showProcesses,
            launchAtLogin: launchAtLogin,
            statusItemSlots: statusItemSlots
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
