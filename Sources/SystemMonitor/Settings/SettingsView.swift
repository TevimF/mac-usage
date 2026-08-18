import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Aparência") {
                Picker("Cor de destaque", selection: $settings.accent) {
                    ForEach(AccentOption.allCases) { option in
                        HStack {
                            Circle().fill(Color(hex: option.rawValue)).frame(width: 12, height: 12)
                            Text(accentLabel(option))
                        }
                        .tag(option)
                    }
                }
                Picker("Estilo do ícone", selection: $settings.iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
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
