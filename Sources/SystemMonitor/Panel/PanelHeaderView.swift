import SwiftUI

struct PanelHeaderView: View {
    var title: String
    /// nil means no alert; otherwise the text to show in place of the
    /// refresh interval (CPU sustained ≥90%, thermal throttling, or both).
    var alertLabel: String?
    var interval: String
    var onOpenSettings: () -> Void

    private var isCritical: Bool { alertLabel != nil }

    var body: some View {
        HStack(spacing: 8) {
            PulsingDot(color: isCritical ? DesignColor.critical : DesignColor.networkHealthy, isCritical: isCritical)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            if let alertLabel {
                Text(alertLabel)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DesignColor.critical)
            } else {
                Text("↻ \(interval)")
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                }
                .glassButton()
                .help(L10n.t("Ajustes", "Settings"))
            }
        }
    }
}
