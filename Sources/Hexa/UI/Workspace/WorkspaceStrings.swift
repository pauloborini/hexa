// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

struct WorkspaceStrings {
    let title: String
    let search: String
    let open: String
    let quick: String
    let viewUpdates: String
    let operation: String
    let capture: String
    let history: String
    let system: String
    let general: String
    let features: String
    let about: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .ptBR:
            return Self(
                title: "Recursos", search: "Buscar recurso ou ajuste", open: "Abrir hexa",
                quick: "Acesso rápido", viewUpdates: "Ver atualizações",
                operation: "Operação",
                capture: "Captura", history: "Histórico",
                system: "Preferências", general: "Geral", features: "Recursos", about: "Sobre"
            )
        case .enUS:
            return Self(
                title: "Resources", search: "Search resources or settings", open: "Open hexa",
                quick: "Quick access", viewUpdates: "View updates",
                operation: "Operation",
                capture: "Capture", history: "History",
                system: "Preferences", general: "General", features: "Features", about: "About"
            )
        case .tr:
            return Self(
                title: "Kaynaklar", search: "Kaynak veya ayar ara", open: "hexa’yı aç",
                quick: "Hızlı erişim", viewUpdates: "Güncellemeleri gör",
                operation: "İşlem",
                capture: "Yakalama", history: "Geçmiş",
                system: "Tercihler", general: "Genel", features: "Özellikler", about: "Hakkında"
            )
        case .ru:
            return Self(
                title: "Ресурсы", search: "Поиск ресурсов или настроек", open: "Открыть hexa",
                quick: "Быстрый доступ", viewUpdates: "Посмотреть обновления",
                operation: "Операция",
                capture: "Захват", history: "История",
                system: "Настройки", general: "Основные", features: "Функции", about: "О программе"
            )
        case .es:
            return Self(
                title: "Recursos", search: "Buscar recurso o ajuste", open: "Abrir hexa",
                quick: "Acceso rápido", viewUpdates: "Ver actualizaciones",
                operation: "Operación",
                capture: "Captura", history: "Historial",
                system: "Preferencias", general: "General", features: "Funciones", about: "Acerca de"
            )
        case .sk:
            return Self(
                title: "Zdroje", search: "Hľadať zdroj alebo nastavenie", open: "Otvoriť hexa",
                quick: "Rýchly prístup", viewUpdates: "Zobraziť aktualizácie",
                operation: "Operácia",
                capture: "Zachytenie", history: "História",
                system: "Predvoľby", general: "Všeobecné", features: "Funkcie", about: "O aplikácii"
            )
        case .de:
            return Self(
                title: "Ressourcen", search: "Ressource oder Einstellung suchen", open: "hexa öffnen",
                quick: "Schnellzugriff", viewUpdates: "Updates anzeigen",
                operation: "Bedienung",
                capture: "Aufnahme", history: "Verlauf",
                system: "Einstellungen", general: "Allgemein", features: "Funktionen", about: "Über"
            )
        case .fr:
            return Self(
                title: "Ressources", search: "Rechercher une ressource ou un réglage", open: "Ouvrir hexa",
                quick: "Accès rapide", viewUpdates: "Voir les mises à jour",
                operation: "Opération",
                capture: "Capture", history: "Historique",
                system: "Préférences", general: "Général", features: "Fonctionnalités", about: "À propos"
            )
        case .it:
            return Self(
                title: "Risorse", search: "Cerca risorsa o impostazione", open: "Apri hexa",
                quick: "Accesso rapido", viewUpdates: "Vedi aggiornamenti",
                operation: "Operazione",
                capture: "Cattura", history: "Cronologia",
                system: "Preferenze", general: "Generali", features: "Funzionalità", about: "Info"
            )
        case .ja:
            return Self(
                title: "リソース", search: "リソースまたは設定を検索", open: "hexaを開く",
                quick: "クイックアクセス", viewUpdates: "アップデートを表示",
                operation: "操作",
                capture: "キャプチャ", history: "履歴",
                system: "環境設定", general: "一般", features: "機能", about: "情報"
            )
        case .ko:
            return Self(
                title: "리소스", search: "리소스 또는 설정 검색", open: "hexa 열기",
                quick: "빠른 접근", viewUpdates: "업데이트 보기",
                operation: "작업",
                capture: "캡처", history: "기록",
                system: "환경설정", general: "일반", features: "기능", about: "정보"
            )
        case .uk:
            return Self(
                title: "Ресурси", search: "Пошук ресурсів або налаштувань", open: "Відкрити hexa",
                quick: "Швидкий доступ", viewUpdates: "Переглянути оновлення",
                operation: "Операція",
                capture: "Захоплення", history: "Історія",
                system: "Налаштування", general: "Загальні", features: "Функції", about: "Про програму"
            )
        case .zhHans:
            return Self(
                title: "资源", search: "搜索资源或设置", open: "打开 hexa",
                quick: "快捷访问", viewUpdates: "查看更新",
                operation: "操作",
                capture: "截取", history: "历史",
                system: "偏好设置", general: "通用", features: "功能", about: "关于"
            )
        case .zhTW:
            return Self(
                title: "資源", search: "搜尋資源或設定", open: "開啟 hexa",
                quick: "快速存取", viewUpdates: "查看更新",
                operation: "操作",
                capture: "擷取", history: "歷史",
                system: "偏好設定", general: "一般", features: "功能", about: "關於"
            )
        case .zhHK:
            return Self(
                title: "資源", search: "搜尋資源或設定", open: "開啟 hexa",
                quick: "快速存取", viewUpdates: "查看更新",
                operation: "操作",
                capture: "擷取", history: "歷史",
                system: "偏好設定", general: "一般", features: "功能", about: "關於"
            )
        }
    }
}
