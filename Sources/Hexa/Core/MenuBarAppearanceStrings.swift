// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

struct MenuBarAppearanceStrings {
    let tabMenuBar: String
    let tabCommandCenter: String
    let commandCenterCaption: String
    let barReadingsSection: String
    let monitoringCardsSection: String
    let quickActionsSection: String
    let islandPanelSection: String
    let ambientDomain: String
    let label: String
    let values: String
    let bars: String
    let caption: String
    let customize: String
    let normalColor: String
    let mediumColor: String
    let highColor: String
    let mediumFrom: String
    let highFrom: String
}

extension FeatureStrings {
    static func menuBarAppearance(_ language: AppLanguage) -> MenuBarAppearanceStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension MenuBarAppearanceStrings {
    static let enUS = MenuBarAppearanceStrings(
        tabMenuBar: "Menu Bar",
        tabCommandCenter: "Command Center",
        commandCenterCaption: "These switches hide cards and quick actions in the command center and sections in the Dynamic Island panel. The module stays in the app until you turn it off in Features.",
        barReadingsSection: "Bar readings",
        monitoringCardsSection: "Monitoring cards",
        quickActionsSection: "Quick actions",
        islandPanelSection: "Dynamic Island panel",
        ambientDomain: "Ambient & audio",
        label: "Usage display",
        values: "Values",
        bars: "Bars",
        caption: "Bars apply to CPU, GPU, memory and disk usage. Other readings stay numeric.",
        customize: "Bar colors and limits",
        normalColor: "Normal color",
        mediumColor: "Medium color",
        highColor: "High color",
        mediumFrom: "Medium from",
        highFrom: "High from"
    )

    static let ptBR = MenuBarAppearanceStrings(
        tabMenuBar: "Barra de menus",
        tabCommandCenter: "Central de comando",
        commandCenterCaption: "Estes interruptores ocultam cards e ações rápidas na central de comando e seções no painel da ilha. O módulo permanece no aplicativo até ser desativado em Recursos.",
        barReadingsSection: "Leituras na barra",
        monitoringCardsSection: "Cards de monitoramento",
        quickActionsSection: "Ações rápidas",
        islandPanelSection: "Painel da ilha",
        ambientDomain: "Ambiente e áudio",
        label: "Exibição de uso",
        values: "Valores",
        bars: "Barras",
        caption: "As barras mostram o uso de CPU, GPU, memória e disco. As outras leituras continuam numéricas.",
        customize: "Cores e limites das barras",
        normalColor: "Cor normal",
        mediumColor: "Cor média",
        highColor: "Cor alta",
        mediumFrom: "Médio a partir de",
        highFrom: "Alto a partir de"
    )

    static let tr = MenuBarAppearanceStrings(
        tabMenuBar: "Menü çubuğu",
        tabCommandCenter: "Komut merkezi",
        commandCenterCaption: "Bu anahtarlar komut merkezindeki kartları ve hızlı eylemleri, Dinamik Ada paneli içindeki bölümleri gizler. Modül, Özellikler’de kapatılana kadar uygulamada kalır.",
        barReadingsSection: "Çubuk ölçümleri",
        monitoringCardsSection: "İzleme kartları",
        quickActionsSection: "Hızlı eylemler",
        islandPanelSection: "Dinamik Ada paneli",
        ambientDomain: "Ortam ve ses",
        label: "Kullanım görünümü",
        values: "Değerler",
        bars: "Çubuklar",
        caption: "Çubuklar CPU, GPU, bellek ve disk kullanımını gösterir. Diğer ölçümler sayısal kalır.",
        customize: "Çubuk renkleri ve sınırları",
        normalColor: "Normal renk",
        mediumColor: "Orta renk",
        highColor: "Yüksek renk",
        mediumFrom: "Orta başlangıcı",
        highFrom: "Yüksek başlangıcı"
    )

    static let ru = MenuBarAppearanceStrings(
        tabMenuBar: "Строка меню",
        tabCommandCenter: "Командный центр",
        commandCenterCaption: "Эти переключатели скрывают карточки и быстрые действия в командном центре и разделы в панели Dynamic Island. Модуль остаётся в приложении, пока вы не отключите его в Функции.",
        barReadingsSection: "Показатели в строке",
        monitoringCardsSection: "Карточки мониторинга",
        quickActionsSection: "Быстрые действия",
        islandPanelSection: "Панель Dynamic Island",
        ambientDomain: "Среда и звук",
        label: "Отображение нагрузки",
        values: "Значения",
        bars: "Шкалы",
        caption: "Шкалы показывают загрузку CPU, GPU, памяти и диска. Остальные показатели остаются числовыми.",
        customize: "Цвета и пороги шкал",
        normalColor: "Обычный цвет",
        mediumColor: "Средний цвет",
        highColor: "Высокий цвет",
        mediumFrom: "Средний от",
        highFrom: "Высокий от"
    )

    static let es = MenuBarAppearanceStrings(
        tabMenuBar: "Barra de menús",
        tabCommandCenter: "Centro de comando",
        commandCenterCaption: "Estos interruptores ocultan tarjetas y acciones rápidas en el centro de comando y secciones en el panel de la isla dinámica. El módulo sigue en la app hasta que lo desactives en Funciones.",
        barReadingsSection: "Lecturas en la barra",
        monitoringCardsSection: "Tarjetas de monitoreo",
        quickActionsSection: "Acciones rápidas",
        islandPanelSection: "Panel de la isla dinámica",
        ambientDomain: "Ambiente y audio",
        label: "Vista de uso",
        values: "Valores",
        bars: "Barras",
        caption: "Las barras muestran el uso de CPU, GPU, memoria y disco. Las demás lecturas siguen siendo numéricas.",
        customize: "Colores y límites de las barras",
        normalColor: "Color normal",
        mediumColor: "Color medio",
        highColor: "Color alto",
        mediumFrom: "Medio desde",
        highFrom: "Alto desde"
    )

    static let sk = MenuBarAppearanceStrings(
        tabMenuBar: "Lišta",
        tabCommandCenter: "Ovládacie centrum",
        commandCenterCaption: "Tieto prepínače skryjú karty a rýchle akcie v ovládacom centre a sekcie v paneli Dynamic Island. Modul ostáva v aplikácii, kým ho nevypnete vo Funkcie.",
        barReadingsSection: "Hodnoty v lište",
        monitoringCardsSection: "Karty monitorovania",
        quickActionsSection: "Rýchle akcie",
        islandPanelSection: "Panel Dynamic Island",
        ambientDomain: "Prostredie a zvuk",
        label: "Zobrazenie vyťaženia",
        values: "Hodnoty",
        bars: "Pruhy",
        caption: "Pruhy platia pre vyťaženie CPU, GPU, pamäte a disku. Ostatné hodnoty zostávajú číselné.",
        customize: "Farby a limity pruhov",
        normalColor: "Bežná farba",
        mediumColor: "Stredná farba",
        highColor: "Vysoká farba",
        mediumFrom: "Stredná od",
        highFrom: "Vysoká od"
    )

    static let de = MenuBarAppearanceStrings(
        tabMenuBar: "Menüleiste",
        tabCommandCenter: "Kommandozentrale",
        commandCenterCaption: "Diese Schalter blenden Karten und Schnellaktionen in der Kommandozentrale sowie Abschnitte im Dynamic-Island-Panel aus. Das Modul bleibt in der App, bis du es unter Funktionen ausschaltest.",
        barReadingsSection: "Messwerte in der Leiste",
        monitoringCardsSection: "Überwachungskarten",
        quickActionsSection: "Schnellaktionen",
        islandPanelSection: "Dynamic-Island-Panel",
        ambientDomain: "Umgebung & Audio",
        label: "Auslastungsanzeige",
        values: "Werte",
        bars: "Balken",
        caption: "Balken zeigen die Auslastung von CPU, GPU, Speicher und Festplatte. Andere Messwerte bleiben numerisch.",
        customize: "Balkenfarben und Grenzwerte",
        normalColor: "Normale Farbe",
        mediumColor: "Mittlere Farbe",
        highColor: "Hohe Farbe",
        mediumFrom: "Mittel ab",
        highFrom: "Hoch ab"
    )

    static let fr = MenuBarAppearanceStrings(
        tabMenuBar: "Barre des menus",
        tabCommandCenter: "Centre de commande",
        commandCenterCaption: "Ces interrupteurs masquent les cartes et actions rapides du centre de commande ainsi que des sections du panneau Dynamic Island. Le module reste dans l’app jusqu’à ce que vous le désactiviez dans Fonctions.",
        barReadingsSection: "Mesures dans la barre",
        monitoringCardsSection: "Cartes de suivi",
        quickActionsSection: "Actions rapides",
        islandPanelSection: "Panneau Dynamic Island",
        ambientDomain: "Ambiance et audio",
        label: "Affichage de l’utilisation",
        values: "Valeurs",
        bars: "Barres",
        caption: "Les barres indiquent l’utilisation du CPU, du GPU, de la mémoire et du disque. Les autres mesures restent numériques.",
        customize: "Couleurs et seuils des barres",
        normalColor: "Couleur normale",
        mediumColor: "Couleur moyenne",
        highColor: "Couleur élevée",
        mediumFrom: "Moyen à partir de",
        highFrom: "Élevé à partir de"
    )

    static let it = MenuBarAppearanceStrings(
        tabMenuBar: "Barra dei menu",
        tabCommandCenter: "Centro di comando",
        commandCenterCaption: "Questi interruttori nascondono schede e azioni rapide nel centro di comando e sezioni nel pannello Dynamic Island. Il modulo resta nell’app finché non lo disattivi in Funzioni.",
        barReadingsSection: "Letture nella barra",
        monitoringCardsSection: "Schede di monitoraggio",
        quickActionsSection: "Azioni rapide",
        islandPanelSection: "Pannello Dynamic Island",
        ambientDomain: "Ambiente e audio",
        label: "Visualizzazione utilizzo",
        values: "Valori",
        bars: "Barre",
        caption: "Le barre mostrano l’utilizzo di CPU, GPU, memoria e disco. Le altre letture restano numeriche.",
        customize: "Colori e soglie delle barre",
        normalColor: "Colore normale",
        mediumColor: "Colore medio",
        highColor: "Colore alto",
        mediumFrom: "Medio da",
        highFrom: "Alto da"
    )

    static let ja = MenuBarAppearanceStrings(
        tabMenuBar: "メニューバー",
        tabCommandCenter: "コマンドセンター",
        commandCenterCaption: "これらのスイッチは、コマンドセンターのカードとクイックアクション、および Dynamic Island パネルのセクションを隠します。モジュールは機能でオフにするまでアプリ内に残ります。",
        barReadingsSection: "バーの表示項目",
        monitoringCardsSection: "モニタリングカード",
        quickActionsSection: "クイックアクション",
        islandPanelSection: "Dynamic Island パネル",
        ambientDomain: "環境とオーディオ",
        label: "使用率の表示",
        values: "数値",
        bars: "バー",
        caption: "CPU、GPU、メモリ、ディスクの使用率をバーで表示します。その他の測定値は数値のままです。",
        customize: "バーの色としきい値",
        normalColor: "通常の色",
        mediumColor: "中程度の色",
        highColor: "高負荷の色",
        mediumFrom: "中程度の開始",
        highFrom: "高負荷の開始"
    )

    static let ko = MenuBarAppearanceStrings(
        tabMenuBar: "메뉴 막대",
        tabCommandCenter: "명령 센터",
        commandCenterCaption: "이 스위치는 명령 센터의 카드와 빠른 작업, 그리고 다이나믹 아일랜드 패널의 섹션을 숨깁니다. 모듈은 기능에서 끌 때까지 앱에 남아 있습니다.",
        barReadingsSection: "막대 표시 항목",
        monitoringCardsSection: "모니터링 카드",
        quickActionsSection: "빠른 작업",
        islandPanelSection: "다이나믹 아일랜드 패널",
        ambientDomain: "환경 및 오디오",
        label: "사용량 표시",
        values: "값",
        bars: "막대",
        caption: "CPU, GPU, 메모리 및 디스크 사용량을 막대로 표시합니다. 다른 측정값은 숫자로 유지됩니다.",
        customize: "막대 색상 및 기준",
        normalColor: "보통 색상",
        mediumColor: "중간 색상",
        highColor: "높음 색상",
        mediumFrom: "중간 시작",
        highFrom: "높음 시작"
    )

    static let zhHans = MenuBarAppearanceStrings(
        tabMenuBar: "菜单栏",
        tabCommandCenter: "命令中心",
        commandCenterCaption: "这些开关会隐藏命令中心中的卡片和快捷操作，以及灵动岛面板中的分区。模块会留在 App 中，直到你在功能里关闭它。",
        barReadingsSection: "栏内读数",
        monitoringCardsSection: "监控卡片",
        quickActionsSection: "快捷操作",
        islandPanelSection: "灵动岛面板",
        ambientDomain: "环境与音频",
        label: "使用率显示",
        values: "数值",
        bars: "条形",
        caption: "CPU、GPU、内存和磁盘使用率以条形显示。其他读数保持数字显示。",
        customize: "条形颜色和阈值",
        normalColor: "正常颜色",
        mediumColor: "中等颜色",
        highColor: "高负载颜色",
        mediumFrom: "中等起点",
        highFrom: "高负载起点"
    )

    static let zhTW = MenuBarAppearanceStrings(
        tabMenuBar: "選單列",
        tabCommandCenter: "命令中心",
        commandCenterCaption: "這些開關會隱藏命令中心中的卡片與快速動作，以及動態島面板中的分區。模組會留在 App 中，直到你在功能裡關閉它。",
        barReadingsSection: "列內讀數",
        monitoringCardsSection: "監控卡片",
        quickActionsSection: "快速動作",
        islandPanelSection: "動態島面板",
        ambientDomain: "環境與音訊",
        label: "使用率顯示",
        values: "數值",
        bars: "長條",
        caption: "CPU、GPU、記憶體和磁碟使用率以長條顯示。其他讀數維持數字顯示。",
        customize: "長條顏色和門檻",
        normalColor: "正常顏色",
        mediumColor: "中等顏色",
        highColor: "高負載顏色",
        mediumFrom: "中等起點",
        highFrom: "高負載起點"
    )

    static let zhHK = MenuBarAppearanceStrings(
        tabMenuBar: "選單列",
        tabCommandCenter: "命令中心",
        commandCenterCaption: "這些開關會隱藏命令中心中的卡片與快速動作，以及動態島面板中的分區。模組會留在 App 中，直到你在功能裡關閉它。",
        barReadingsSection: "列內讀數",
        monitoringCardsSection: "監控卡片",
        quickActionsSection: "快速動作",
        islandPanelSection: "動態島面板",
        ambientDomain: "環境與音訊",
        label: "使用率顯示",
        values: "數值",
        bars: "長條",
        caption: "CPU、GPU、記憶體及磁碟使用率以長條顯示。其他讀數維持數字顯示。",
        customize: "長條顏色及門檻",
        normalColor: "正常顏色",
        mediumColor: "中等顏色",
        highColor: "高負載顏色",
        mediumFrom: "中等起點",
        highFrom: "高負載起點"
    )

    static let uk = MenuBarAppearanceStrings(
        tabMenuBar: "Смуга меню",
        tabCommandCenter: "Командний центр",
        commandCenterCaption: "Ці перемикачі ховають картки та швидкі дії в командному центрі, а також розділи в панелі Dynamic Island. Модуль лишається в програмі, доки ви не вимкнете його у Функції.",
        barReadingsSection: "Показники у смузі",
        monitoringCardsSection: "Картки моніторингу",
        quickActionsSection: "Швидкі дії",
        islandPanelSection: "Панель Dynamic Island",
        ambientDomain: "Середовище та аудіо",
        label: "Відображення використання",
        values: "Значення",
        bars: "Смуги",
        caption: "Смуги застосовуються до використання CPU, GPU, пам’яті та диска. Інші показники залишаються числовими.",
        customize: "Кольори та ліміти смуг",
        normalColor: "Звичайний колір",
        mediumColor: "Середній колір",
        highColor: "Високий колір",
        mediumFrom: "Середній від",
        highFrom: "Високий від"
    )
}
