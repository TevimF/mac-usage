import Foundation

/// UI language, chosen in Ajustes → Geral. Independent from the system
/// language on purpose — the app ships two languages and switching should
/// take effect immediately, without relaunching or touching System
/// Settings.
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case portuguese, english

    var id: String { rawValue }

    /// Shown in its own language so each option is readable to the person
    /// who wants it.
    var label: String {
        switch self {
        case .portuguese: return "Português (Brasil)"
        case .english: return "English"
        }
    }
}

/// Two-language string helper. With exactly two shipped languages, an
/// inline `L10n.t("…", "…")` at each call site keeps the pt/en pair
/// side by side — easier to keep in sync than a string catalog two files
/// away. Views re-render on change because they observe AppSettings.
enum L10n {
    static func t(_ portuguese: String, _ english: String) -> String {
        AppSettings.shared.language == .english ? english : portuguese
    }
}
