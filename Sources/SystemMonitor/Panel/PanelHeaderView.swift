import SwiftUI

struct PanelHeaderView: View {
    var title: String
    var isCritical: Bool
    var interval: String
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            PulsingDot(color: isCritical ? DesignColor.critical : DesignColor.networkHealthy, isCritical: isCritical)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            if isCritical {
                Text("Pressão alta")
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
                .help("Ajustes")
            }
        }
    }
}
