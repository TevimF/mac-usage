import AppKit
import SwiftUI

struct PanelFooterView: View {
    var isCritical: Bool
    var onOpenActivityMonitor: () -> Void
    var onOpenSettings: () -> Void
    var onOpenAbout: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            // One centered capsule group holding every action — no lone
            // button hanging off to the side.
            GlassGroup(spacing: 6) {
                if isCritical {
                    Button(L10n.t("Abrir Monitor de Atividade", "Open Activity Monitor"), action: onOpenActivityMonitor)
                        .font(.system(size: 11.5, weight: .semibold))
                        .glassProminentButton(tint: DesignColor.critical)
                } else {
                    Button(L10n.t("Monitor de Atividade", "Activity Monitor"), action: onOpenActivityMonitor)
                        .font(.system(size: 11.5))
                        .glassButton()
                    Button(L10n.t("Ajustes", "Settings"), action: onOpenSettings)
                        .font(.system(size: 11.5))
                        .glassButton()
                    Button(L10n.t("Sobre", "About"), action: onOpenAbout)
                        .font(.system(size: 11.5))
                        .glassButton()
                }
            }
            .frame(maxWidth: .infinity)

            // The Lobby credit (design v2, section 09) — 15px mark at 75%
            // opacity, never colored so it doesn't compete with the
            // metrics. Clicking it goes straight to the site; the About
            // window has its own button above.
            Button(action: openLobbySite) {
                HStack(spacing: 6) {
                    LobbyMarkImage()
                        .frame(width: 15, height: 14)
                        .opacity(0.75)
                    Text(L10n.t("Feito pela The Lobby", "Made by The Lobby"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
        }
    }

    private func openLobbySite() {
        NSWorkspace.shared.open(LobbyBrand.siteURL)
    }
}
