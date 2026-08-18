import SwiftUI

/// The "manter tela ativa" switch, mirrored inside the panel — the menu
/// bar's own cup item toggles the same assertion; this makes it reachable
/// without hunting for that separate status item. Always shown, not part
/// of the reorderable `panelSectionOrder` — same fixed-position treatment
/// as the header/footer.
///
/// Two rows on purpose: title + switch above, status + duration below.
/// Cramming everything into one row inside the 320pt panel forced the
/// title and subtitle to wrap into a word ladder.
struct KeepAwakeRowView: View {
    @ObservedObject private var controller = KeepAwakeController.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 14))
                    .foregroundStyle(controller.isActive ? DesignColor.diskThermalWarn : Color.secondary)
                    .frame(width: 18)

                Text(L10n.t("Manter tela ativa", "Keep screen awake"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Toggle(L10n.t("Manter tela ativa", "Keep screen awake"), isOn: Binding(
                    get: { controller.isActive },
                    set: { _ in controller.toggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Text(statusLine)
                    .detailStyle()
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer(minLength: 8)

                Picker("", selection: $settings.keepAwakeDuration) {
                    ForEach(KeepAwakeDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    /// Left side of the bottom row: what the switch is doing right now —
    /// the remaining time while counting down, or the plain duration label
    /// when off.
    private var statusLine: String {
        guard controller.isActive else { return L10n.t("Duração", "Duration") }
        guard let remaining = controller.remainingSeconds else {
            return L10n.t("tela não vai escurecer", "screen will stay on")
        }
        let time = Formatting.duration(minutes: max(1, Int(remaining / 60)))
        return L10n.t("\(time) restantes", "\(time) remaining")
    }
}
