import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("Cor de destaque (CPU)", selection: $settings.accent) {
                    ForEach(AccentOption.allCases) { option in
                        HStack {
                            Circle().fill(Color(hex: option.rawValue)).frame(width: 12, height: 12)
                            Text(accentLabel(option))
                        }
                        .tag(option)
                    }
                }
                Picker("Formato do item de CPU sozinho", selection: $settings.iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Barra de menu")
            } footer: {
                Text("Não é o ícone do app (Dock/Finder) — isso é fixo. Aqui é só a aparência dos ícones na barra de menu: a cor tinge o ícone de CPU (as outras métricas já têm cor própria — RAM roxo, disco/térmico laranja, rede verde); o formato (número/sparkline/cápsula) só vale quando um item mostra CPU sozinho.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Conteúdo") {
                Picker("Amostragem", selection: $settings.sampleInterval) {
                    ForEach(SampleInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                Toggle("Mostrar maiores consumos (processos)", isOn: $settings.showProcesses)
            }

            Section("Itens na barra de menu") {
                StatusItemsEditorView()
            }

            Section("Ordem do painel") {
                PanelSectionsEditorView()
            }

            Section {
                Picker("Duração", selection: $settings.keepAwakeDuration) {
                    ForEach(KeepAwakeDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
            } header: {
                Text("Café (manter tela acesa)")
            } footer: {
                Text("Quanto tempo o botão de café (☕ na barra de menu) mantém a tela acesa antes de desligar sozinho.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Geral") {
                Toggle("Abrir no login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 560)
    }

    private func accentLabel(_ option: AccentOption) -> String {
        switch option {
        case .cyan: return "Ciano"
        case .blue: return "Azul"
        case .green: return "Verde"
        case .purple: return "Roxo"
        }
    }
}
