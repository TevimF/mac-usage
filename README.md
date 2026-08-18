# ⚡ Mac usage

<p align="center">
  <strong>Monitor de recursos nativo e ultraleve para a barra de menu do macOS.</strong><br>
  <em>Swift puro, AppKit + SwiftUI — sem Electron.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple&style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift&style=flat-square" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Idiomas-PT--BR%20%7C%20EN-informational?style=flat-square" alt="Bilingual">
  <img src="https://img.shields.io/badge/License-GPLv3-lightgrey?style=flat-square" alt="GPLv3">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Docs/panel-dark.png">
    <img src="Docs/panel-light.png" width="320" alt="Painel do Mac usage mostrando CPU, memória, disco, rede, swap, térmico, bateria e maiores consumos">
  </picture>
</p>

<p align="center">
  <sub>O painel completo, aberto com um clique na barra de menu. <em>Valores de exemplo.</em></sub>
</p>

---

## Visão geral

CPU, memória, swap, disco, rede, estado térmico e bateria, direto na barra de menu, lendo APIs nativas do kernel (`Mach`, `libproc`, `IOKit`) — sem subprocessos, sem Electron, poucos MB de RAM. Sampling cai para 5s quando o painel está fechado.

Também substitui o Caffeine/Amphetamine: um ícone de xícara na barra impede a tela de apagar, com duração configurável.

---

## Recursos

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Docs/menu-bar-dark.png">
    <img src="Docs/menu-bar-light.png" width="460" alt="Variações do item na barra de menu: numérico, sparkline, cápsula, duas métricas, rede, modos de cor e estado crítico">
  </picture>
</p>

<p align="center">
  <sub>Cada linha é a imagem que o app realmente desenha na barra — gerada pelo próprio código de renderização.</sub>
</p>

- **Barra de menu**: 1–2 métricas por vez, três estilos de ícone (numérico, sparkline, cápsula de vidro), cor neutra / por métrica / por valor. Tooltip com detalhes ao passar o mouse.
- **Painel** (clique no ícone): gráfico de CPU, memória (ativa/presa/comprimida/swap), disco e sua taxa de leitura/gravação, rede, e os processos que mais consomem — ordenável por CPU ou RAM.
- **Manter tela ativa** ☕: 15 min a 4h, ou até desativar.
- **Alerta de sobrecarga**: CPU acima de 90% por 10s seguidos acende o estado crítico — medido em tempo, não em número de leituras, então dispara no mesmo instante com o painel aberto ou fechado.

---

## Métricas

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Docs/icon-family-dark.png">
    <img src="Docs/icon-family-light.png" width="720" alt="Família de ícones: CPU, RAM, Swap, Disco, Disco E/S, Rede, Térmico e Bateria">
  </picture>
</p>

| Métrica | O que mostra | Fonte |
| :--- | :--- | :--- |
| CPU | % total, Usuário/Sistema, histórico | `host_processor_info` |
| RAM | Usada, ativa, presa, comprimida, total (GiB) | `host_statistics64` |
| Swap | Usado / alocado no momento (não é um teto fixo) | `sysctl vm.swapusage` |
| Disco | Espaço ocupado/livre | `getattrlist` |
| E/S de disco | Taxa de leitura/gravação | `IOBlockStorageDriver` |
| Rede | Download/upload | `getifaddrs` |
| Térmico | Nominal → Crítico | `ProcessInfo.thermalState` |
| Bateria | Carga, tempo restante | `IOPowerSources` |
| Processos | Top CPU e RAM | `proc_pidinfo` |

---

## Ajustes

Três abas na janela de Ajustes (ícone de engrenagem no rodapé do painel):

- **Geral** — duração padrão do keep-awake, idioma, iniciar com o login.
- **Barra de menu** — reordenar métricas, quantas aparecem, cor e estilo do ícone.
- **Painel** — ordem das seções, intervalo de amostragem (1s/2s/5s), mostrar maiores consumos.

---

## Instalar e compilar

Requer macOS 14+ e Swift 5.9+ (`swift --version`).

```bash
cd "Mac usage/SystemMonitor"
./Scripts/build_app.sh
open "Mac usage.app"
```

`build_app.sh` compila em Release, gera o ícone se faltar, empacota o `.app` e assina ad-hoc.

Iteração rápida sem empacotar:

```bash
swift build && .build/debug/SystemMonitor
```

Testes:

```bash
swift test
```

As imagens deste README são desenhadas pelo código real de renderização do app (`StatusItemContentRenderer`, `PanelView`), não são montagens. Para regerá-las:

```bash
README_ASSETS_DIR=Docs swift test --filter ReadmeAssetTests
```

---

## Por que não tem temperatura da CPU nem uso de GPU

Ler o sensor SMC direto exige um entitlement privado que a Apple não concede a terceiros — a chamada retorna `kIOReturnNotPrivileged`. Em vez de um número inventado, o app usa `ProcessInfo.thermalState` (Nominal/Razoável/Sério/Crítico), a API pública real. GPU contínua no Apple Silicon exige `root` (`powermetrics`), que o app não pede.

Login automático usa `SMAppService.mainApp`, a API atual da Apple — não o *Legacy Login Items* obsoleto.

---

## Estrutura

```
Sources/SystemMonitor/
  App/       ponto de entrada (LSUIElement, sem Dock)
  Metrics/   samplers + SystemMetricsEngine (timer serial)
  MenuBar/   ícones, tooltips, renderização da barra
  Panel/     painel SwiftUI (popover)
  Settings/  janela de Ajustes
  Model/     AppSettings (persistência)
  Support/   cor, formatação, l10n, keep-awake
Tests/       testes + geração das imagens deste README
Docs/        imagens deste README
```

---

## Licença

Desenvolvido por **[The Lobby](https://thelobby.com.br)** / **Estevão Fonseca**. Distribuído sob **GPLv3** — veja [LICENSE](LICENSE).
