// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Labels the Dynamic Island settings page needs beyond the editor vocabulary:
/// the shortcut bar, the resting preview, the closed-island states and the
/// Appearance controls. Settings-only: the in-island UI keeps `NotchStrings`.
struct NotchExperienceStrings {
    let shortcutBar: String
    let restingPreview: String
    let alwaysAvailable: String
    let captureControlsLabel: String
    let displayPlacement: String
    let displayResolvedFormat: String
    let surface: String
    let appearanceHint: String
    let sizePreset: String
    let openingMode: String
    let included: String
    let notIncluded: String
    let moveUp: String
    let moveDown: String
    let pointsFormat: String
}

extension FeatureStrings {
    static func notchExperience(_ language: AppLanguage) -> NotchExperienceStrings {
        switch language {
        case .enUS: return NotchExperienceStrings(
            shortcutBar: "Shortcut bar",
            restingPreview: "Closed island",
            alwaysAvailable: "Controls is always available.",
            captureControlsLabel: "Capture controls",
            displayPlacement: "Placement",
            displayResolvedFormat: "Currently on %@",
            surface: "Surface",
            appearanceHint: "Size, surface and the displays without a notch.",
            sizePreset: "Preset",
            openingMode: "Opening behavior",
            included: "Included",
            notIncluded: "Not included",
            moveUp: "Move up",
            moveDown: "Move down",
            pointsFormat: "%d pt"
        )
        case .ptBR: return NotchExperienceStrings(
            shortcutBar: "Barra de atalhos",
            restingPreview: "Ilha fechada",
            alwaysAvailable: "Controles está sempre disponível.",
            captureControlsLabel: "Controles de captura",
            displayPlacement: "Posição",
            displayResolvedFormat: "Agora em %@",
            surface: "Superfície",
            appearanceHint: "Tamanho, superfície e as telas sem notch.",
            sizePreset: "Preset",
            openingMode: "Como abre",
            included: "Incluída",
            notIncluded: "Não incluída",
            moveUp: "Mover para cima",
            moveDown: "Mover para baixo",
            pointsFormat: "%d pt"
        )
        case .es: return NotchExperienceStrings(
            shortcutBar: "Barra de atajos",
            restingPreview: "Isla cerrada",
            alwaysAvailable: "Controles siempre está disponible.",
            captureControlsLabel: "Controles de captura",
            displayPlacement: "Posición",
            displayResolvedFormat: "Ahora en %@",
            surface: "Superficie",
            appearanceHint: "Tamaño, superficie y las pantallas sin notch.",
            sizePreset: "Preajuste",
            openingMode: "Cómo abre",
            included: "Incluida",
            notIncluded: "No incluida",
            moveUp: "Mover hacia arriba",
            moveDown: "Mover hacia abajo",
            pointsFormat: "%d pt"
        )
        case .sk: return NotchExperienceStrings(
            shortcutBar: "Panel skratiek",
            restingPreview: "Zatvorený ostrov",
            alwaysAvailable: "Ovládanie je vždy dostupné.",
            captureControlsLabel: "Ovládanie snímania",
            displayPlacement: "Umiestnenie",
            displayResolvedFormat: "Teraz na %@",
            surface: "Povrch",
            appearanceHint: "Veľkosť, povrch a displeje bez výrezu.",
            sizePreset: "Predvoľba",
            openingMode: "Ako sa otvára",
            included: "Zahrnuté",
            notIncluded: "Nezahrnuté",
            moveUp: "Presunúť nahor",
            moveDown: "Presunúť nadol",
            pointsFormat: "%d pt"
        )
        case .de: return NotchExperienceStrings(
            shortcutBar: "Kurzbefehlsleiste",
            restingPreview: "Geschlossene Insel",
            alwaysAvailable: "Steuerung ist immer verfügbar.",
            captureControlsLabel: "Aufnahmesteuerung",
            displayPlacement: "Platzierung",
            displayResolvedFormat: "Aktuell auf %@",
            surface: "Oberfläche",
            appearanceHint: "Größe, Oberfläche und die Bildschirme ohne Notch.",
            sizePreset: "Voreinstellung",
            openingMode: "Öffnungsverhalten",
            included: "Enthalten",
            notIncluded: "Nicht enthalten",
            moveUp: "Nach oben",
            moveDown: "Nach unten",
            pointsFormat: "%d pt"
        )
        case .fr: return NotchExperienceStrings(
            shortcutBar: "Barre de raccourcis",
            restingPreview: "Îlot fermé",
            alwaysAvailable: "Commandes est toujours disponible.",
            captureControlsLabel: "Commandes de capture",
            displayPlacement: "Emplacement",
            displayResolvedFormat: "Actuellement sur %@",
            surface: "Surface",
            appearanceHint: "Taille, surface et les écrans sans encoche.",
            sizePreset: "Préréglage",
            openingMode: "Mode d’ouverture",
            included: "Incluse",
            notIncluded: "Non incluse",
            moveUp: "Monter",
            moveDown: "Descendre",
            pointsFormat: "%d pt"
        )
        case .it: return NotchExperienceStrings(
            shortcutBar: "Barra delle scorciatoie",
            restingPreview: "Isola chiusa",
            alwaysAvailable: "Controlli è sempre disponibile.",
            captureControlsLabel: "Controlli di cattura",
            displayPlacement: "Posizione",
            displayResolvedFormat: "Ora su %@",
            surface: "Superficie",
            appearanceHint: "Dimensioni, superficie e gli schermi senza notch.",
            sizePreset: "Preimpostazione",
            openingMode: "Come si apre",
            included: "Inclusa",
            notIncluded: "Non inclusa",
            moveUp: "Sposta su",
            moveDown: "Sposta giù",
            pointsFormat: "%d pt"
        )
        case .ru: return NotchExperienceStrings(
            shortcutBar: "Панель ярлыков",
            restingPreview: "Закрытый остров",
            alwaysAvailable: "Управление доступно всегда.",
            captureControlsLabel: "Управление захватом",
            displayPlacement: "Размещение",
            displayResolvedFormat: "Сейчас на %@",
            surface: "Поверхность",
            appearanceHint: "Размер, поверхность и экраны без выреза.",
            sizePreset: "Пресет",
            openingMode: "Как открывается",
            included: "Включено",
            notIncluded: "Не включено",
            moveUp: "Переместить вверх",
            moveDown: "Переместить вниз",
            pointsFormat: "%d pt"
        )
        case .tr: return NotchExperienceStrings(
            shortcutBar: "Kısayol çubuğu",
            restingPreview: "Kapalı ada",
            alwaysAvailable: "Denetimler her zaman kullanılabilir.",
            captureControlsLabel: "Yakalama kontrolleri",
            displayPlacement: "Konum",
            displayResolvedFormat: "Şu anda %@",
            surface: "Yüzey",
            appearanceHint: "Boyut, yüzey ve çentiği olmayan ekranlar.",
            sizePreset: "Ön ayar",
            openingMode: "Açılma biçimi",
            included: "Dahil",
            notIncluded: "Dahil değil",
            moveUp: "Yukarı taşı",
            moveDown: "Aşağı taşı",
            pointsFormat: "%d pt"
        )
        case .ja: return NotchExperienceStrings(
            shortcutBar: "ショートカットバー",
            restingPreview: "閉じた島",
            alwaysAvailable: "コントロールは常に利用できます。",
            captureControlsLabel: "キャプチャの操作",
            displayPlacement: "配置",
            displayResolvedFormat: "現在は%@",
            surface: "表面",
            appearanceHint: "サイズ、表面、ノッチのないディスプレイ。",
            sizePreset: "プリセット",
            openingMode: "開く動作",
            included: "含む",
            notIncluded: "含まない",
            moveUp: "上へ移動",
            moveDown: "下へ移動",
            pointsFormat: "%d pt"
        )
        case .ko: return NotchExperienceStrings(
            shortcutBar: "단축키 막대",
            restingPreview: "닫힌 섬",
            alwaysAvailable: "제어는 항상 사용할 수 있습니다.",
            captureControlsLabel: "캡처 제어",
            displayPlacement: "배치",
            displayResolvedFormat: "현재 %@",
            surface: "표면",
            appearanceHint: "크기, 표면, 노치가 없는 디스플레이.",
            sizePreset: "프리셋",
            openingMode: "여는 방식",
            included: "포함",
            notIncluded: "포함 안 함",
            moveUp: "위로 이동",
            moveDown: "아래로 이동",
            pointsFormat: "%d pt"
        )
        case .zhHans: return NotchExperienceStrings(
            shortcutBar: "快捷操作栏",
            restingPreview: "收起的岛",
            alwaysAvailable: "控制始终可用。",
            captureControlsLabel: "捕获控制",
            displayPlacement: "位置",
            displayResolvedFormat: "当前在 %@",
            surface: "表面",
            appearanceHint: "大小、表面和无刘海的显示器。",
            sizePreset: "预设",
            openingMode: "打开行为",
            included: "已包含",
            notIncluded: "未包含",
            moveUp: "上移",
            moveDown: "下移",
            pointsFormat: "%d pt"
        )
        case .zhTW: return NotchExperienceStrings(
            shortcutBar: "快捷操作列",
            restingPreview: "收合的島",
            alwaysAvailable: "控制項永遠可用。",
            captureControlsLabel: "擷取控制項",
            displayPlacement: "位置",
            displayResolvedFormat: "目前在 %@",
            surface: "表面",
            appearanceHint: "大小、表面和無瀏海的顯示器。",
            sizePreset: "預設組",
            openingMode: "開啟行為",
            included: "已包含",
            notIncluded: "未包含",
            moveUp: "上移",
            moveDown: "下移",
            pointsFormat: "%d pt"
        )
        case .zhHK: return NotchExperienceStrings(
            shortcutBar: "快捷操作列",
            restingPreview: "收合的島",
            alwaysAvailable: "控制項永遠可用。",
            captureControlsLabel: "擷取控制項",
            displayPlacement: "位置",
            displayResolvedFormat: "目前在 %@",
            surface: "表面",
            appearanceHint: "大小、表面和無瀏海的顯示器。",
            sizePreset: "預設組",
            openingMode: "開啟行為",
            included: "已包含",
            notIncluded: "未包含",
            moveUp: "上移",
            moveDown: "下移",
            pointsFormat: "%d pt"
        )
        case .uk: return NotchExperienceStrings(
            shortcutBar: "Панель ярликів",
            restingPreview: "Закритий острівець",
            alwaysAvailable: "Керування доступне завжди.",
            captureControlsLabel: "Керування захопленням",
            displayPlacement: "Розміщення",
            displayResolvedFormat: "Зараз на %@",
            surface: "Поверхня",
            appearanceHint: "Розмір, поверхня й дисплеї без вирізу.",
            sizePreset: "Пресет",
            openingMode: "Як відкривається",
            included: "Включено",
            notIncluded: "Не включено",
            moveUp: "Вгору",
            moveDown: "Вниз",
            pointsFormat: "%d pt"
        )
        }
    }
}
