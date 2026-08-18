import AppKit
import SwiftUI

/// Design v2, section 09: mark, app name and version, a divider, then the
/// Lobby credit and copyright. Reached by clicking the credit in the
/// panel's footer.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Button(action: openSite) {
                LobbyMarkImage()
                    .frame(width: 44, height: 42)
            }
            .buttonStyle(.plain)
            .help("thelobby.com.br")

            VStack(spacing: 3) {
                Text("Mac usage")
                    .font(.system(size: 14, weight: .semibold))
                Text(versionString)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                (Text(L10n.t("Feito pela ", "Made by ")) + Text("The Lobby").fontWeight(.semibold))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Button(action: openSite) {
                    Text("© 2026 · thelobby.com.br")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(width: 260)
    }

    private func openSite() {
        NSWorkspace.shared.open(LobbyBrand.siteURL)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(L10n.t("Versão", "Version")) \(short) (\(build))"
    }
}
