import SwiftUI

enum LobbyBrand {
    static let siteURL = URL(string: "https://www.thelobby.com.br/")!
}

/// The Lobby brand mark, loaded from the bundled SVG. Only resolves inside
/// the packaged `Mac usage.app` — like `AppIcon.icns`, `Scripts/build_app.sh`
/// copies it into `Contents/Resources` at packaging time, so the raw debug
/// binary (`swift build && .build/debug/SystemMonitor`) has no bundle to
/// find it in. Falls back to a plain glyph there rather than showing
/// nothing.
struct LobbyMarkImage: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "lobby-mark", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "cup.and.saucer.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
    }
}
