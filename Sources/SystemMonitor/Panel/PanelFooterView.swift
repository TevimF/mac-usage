import SwiftUI

struct PanelFooterView: View {
    var isCritical: Bool
    var onOpenActivityMonitor: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            GlassGroup(spacing: 6) {
                if isCritical {
                    Button("Abrir Monitor de Atividade", action: onOpenActivityMonitor)
                        .font(.system(size: 11.5, weight: .semibold))
                        .glassProminentButton(tint: DesignColor.critical)
                } else {
                    Button("Monitor de Atividade", action: onOpenActivityMonitor)
                        .font(.system(size: 11.5))
                        .glassButton()
                    Button("Ajustes", action: onOpenSettings)
                        .font(.system(size: 11.5))
                        .glassButton()
                }
            }
            Spacer()
            Button(action: onQuit) {
                Text("Sair ⌘Q")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
        }
    }
}
