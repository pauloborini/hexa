// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

struct GraphScaleStrings {
    let title: String
    let sectionTitle: String

    static func localized(_ language: AppLanguage) -> GraphScaleStrings {
        switch language {
        case .enUS: return .init(title: "Show scale on all graphs", sectionTitle: "Graphs")
        case .ptBR: return .init(title: "Mostrar escala em todos os gráficos", sectionTitle: "Gráficos")
        case .tr: return .init(title: "Tüm grafiklerde ölçeği göster", sectionTitle: "Grafikler")
        case .ru: return .init(title: "Показывать шкалу на всех графиках", sectionTitle: "Графики")
        case .es: return .init(title: "Mostrar escala en todas las gráficas", sectionTitle: "Gráficas")
        case .sk: return .init(title: "Zobraziť mierku na všetkých grafoch", sectionTitle: "Grafy")
        case .de: return .init(title: "Skala in allen Diagrammen anzeigen", sectionTitle: "Diagramme")
        case .fr: return .init(title: "Afficher l’échelle sur tous les graphiques", sectionTitle: "Graphiques")
        case .it: return .init(title: "Mostra la scala su tutti i grafici", sectionTitle: "Grafici")
        case .ja: return .init(title: "すべてのグラフに上限を表示", sectionTitle: "グラフ")
        case .ko: return .init(title: "모든 그래프에 상한 표시", sectionTitle: "그래프")
        case .uk: return .init(title: "Показувати шкалу на всіх графіках", sectionTitle: "Графіки")
        case .zhHans: return .init(title: "在所有图表中显示上限", sectionTitle: "图表")
        case .zhTW: return .init(title: "在所有圖表中顯示上限", sectionTitle: "圖表")
        case .zhHK: return .init(title: "在所有圖表中顯示上限", sectionTitle: "圖表")
        }
    }
}
