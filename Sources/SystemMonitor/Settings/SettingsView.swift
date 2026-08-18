import AppKit
import SwiftUI

/// Three tabs instead of one long scroll: what shows in the menu bar, what
/// shows in the panel, and everything else. Each tab holds one screen's
/// worth of controls so nothing needs scrolling to be found.
struct SettingsView: View {
    // Observed here (not just in the tabs) so a language change rebuilds
    // the tab labels too.
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            MenuBarSettingsTab()
                .tabItem { Label(L10n.t("Barra de menu", "Menu bar"), systemImage: "menubar.rectangle") }
            PanelSettingsTab()
                .tabItem { Label(L10n.t("Painel", "Panel"), systemImage: "square.grid.2x2") }
            GeneralSettingsTab()
                .tabItem { Label(L10n.t("Geral", "General"), systemImage: "gearshape") }
        }
        .frame(width: 470, height: 500)
    }
}

private struct MenuBarSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared

    /// The one configuration where `iconStyle` changes anything —
    /// `renderSingle` in StatusItemContentRenderer is the only path that
    /// reads it, and only a lone CPU slot goes through there.
    private var barShowsOnlyCPU: Bool {
        settings.barMetricCount == 1 && settings.metricOrder.first == .cpu
    }

    var body: some View {
        Form {
            Section {
                MetricOrderEditorView()
            } header: {
                Text(L10n.t("Itens", "Items"))
            }

            Section {
                Picker(L10n.t("Cor dos ícones", "Icon color"), selection: $settings.iconColorMode) {
                    ForEach(IconColorMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                LabeledContent(L10n.t("Cor de destaque", "Accent color")) {
                    AccentSwatchRow(selection: $settings.accent)
                }

                // Rather than show a control that quietly does nothing in
                // every other configuration, the style picker only appears
                // when it has an effect.
                if barShowsOnlyCPU {
                    Picker(L10n.t("Estilo do ícone", "Icon style"), selection: $settings.iconStyle) {
                        ForEach(IconStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                }
            } header: {
                Text(L10n.t("Aparência", "Appearance"))
            } footer: {
                SettingsHelp(L10n.t(
                    "“Muda com o uso” começa neutro e vai para laranja/vermelho conforme o valor sobe — bateria é ao contrário. A cor de destaque tinge o ícone de CPU e o gráfico de CPU no painel; ela não muda o ícone do app no Dock.",
                    "“Changes with usage” starts neutral and slides to orange/red as the value climbs — battery is the other way around. The accent color tints the CPU icon and the CPU chart in the panel; it doesn't change the app icon in the Dock."
                ))
            }
        }
        .formStyle(.grouped)
    }
}

private struct PanelSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(L10n.t("Conteúdo", "Content")) {
                Picker(L10n.t("Atualizar a cada", "Update every"), selection: $settings.sampleInterval) {
                    ForEach(SampleInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                Toggle(L10n.t("Mostrar maiores consumos", "Show top consumers"), isOn: $settings.showProcesses)
            }

            Section {
                PanelSectionsEditorView()
            } header: {
                Text(L10n.t("Ordem das seções", "Section order"))
            } footer: {
                SettingsHelp(L10n.t(
                    "O cabeçalho, a linha de manter tela ativa e o rodapé ficam sempre no lugar. Arraste uma linha pra mudar a ordem.",
                    "The header, the keep-awake row and the footer always stay put. Drag a row to change the order."
                ))
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker(L10n.t("Duração", "Duration"), selection: $settings.keepAwakeDuration) {
                    ForEach(KeepAwakeDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
            } header: {
                Text(L10n.t("Manter tela acesa", "Keep screen awake"))
            } footer: {
                SettingsHelp(L10n.t(
                    "Quanto tempo a xícara na barra de menu segura a tela antes de desligar sozinha.",
                    "How long the cup in the menu bar holds the screen before switching itself off."
                ))
            }

            Section(L10n.t("Idioma", "Language")) {
                Picker(L10n.t("Idioma", "Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
            }

            Section(L10n.t("Sistema", "System")) {
                Toggle(L10n.t("Abrir no login", "Open at login"), isOn: $settings.launchAtLogin)
                // The panel has no quit button (by request) and an
                // LSUIElement app has no Dock icon — this is the one way
                // out besides the panel's right-click menu.
                Button(L10n.t("Sair do Mac usage", "Quit Mac usage")) { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
    }
}

/// Four colors is few enough to show them all at once — a pop-up menu
/// collapses to the color's *name*, which is a worse way to pick a color
/// than seeing the colors.
private struct AccentSwatchRow: View {
    @Binding var selection: AccentOption

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AccentOption.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Circle()
                        .fill(Color(hex: option.rawValue))
                        .frame(width: 15, height: 15)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(selection == option ? 0.75 : 0), lineWidth: 1.5)
                                .padding(-3.5)
                        )
                }
                .buttonStyle(.plain)
                .help(option.label)
                .accessibilityLabel(option.label)
            }
        }
        .padding(.vertical, 2)
    }
}

/// One style for every explanatory line under a section, so they all read
/// the same weight instead of each spot picking its own font.
struct SettingsHelp: View {
    private let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
