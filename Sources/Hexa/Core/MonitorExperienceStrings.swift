// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

struct MonitorExperienceStrings {
    let usageByApp: String
    let noApps: String
    let noLocalAddress: String
    let graphWindowFormat: String
    let accessories: String
    let diskEject: String
    let diskCapacity: String
    let bluetoothDenied: String

    static func localized(_ language: AppLanguage) -> MonitorExperienceStrings {
        switch language {
        case .enUS: return .init(
            usageByApp: "Usage by app",
            noApps: "No app is using this now",
            noLocalAddress: "No local address",
            graphWindowFormat: "Last %@",
            accessories: "Accessories",
            diskEject: "Safe eject",
            diskCapacity: "Capacity",
            bluetoothDenied: "Bluetooth is off for Hexa, so accessory batteries cannot appear."
        )
        case .ptBR: return .init(
            usageByApp: "Uso por app",
            noApps: "Nenhum app usando agora",
            noLocalAddress: "Sem endereço local",
            graphWindowFormat: "Últimos %@",
            accessories: "Acessórios",
            diskEject: "Ejeção segura",
            diskCapacity: "Capacidade",
            bluetoothDenied: "O Bluetooth está desligado para o Hexa, então as baterias dos acessórios não aparecem."
        )
        case .tr: return .init(
            usageByApp: "Uygulama başına kullanım",
            noApps: "Şu anda kullanan uygulama yok",
            noLocalAddress: "Yerel adres yok",
            graphWindowFormat: "Son %@",
            accessories: "Aksesuarlar",
            diskEject: "Güvenli çıkarma",
            diskCapacity: "Kapasite",
            bluetoothDenied: "Hexa için Bluetooth kapalı, bu yüzden aksesuar pilleri görünemez."
        )
        case .ru: return .init(
            usageByApp: "Использование по приложениям",
            noApps: "Сейчас нет приложений с нагрузкой",
            noLocalAddress: "Нет локального адреса",
            graphWindowFormat: "Последние %@",
            accessories: "Аксессуары",
            diskEject: "Безопасное извлечение",
            diskCapacity: "Ёмкость",
            bluetoothDenied: "Bluetooth для Hexa выключен, поэтому батареи аксессуаров не отображаются."
        )
        case .es: return .init(
            usageByApp: "Uso por app",
            noApps: "Ninguna app lo está usando ahora",
            noLocalAddress: "Sin dirección local",
            graphWindowFormat: "Últimos %@",
            accessories: "Accesorios",
            diskEject: "Expulsión segura",
            diskCapacity: "Capacidad",
            bluetoothDenied: "Bluetooth está desactivado para Hexa, así que las baterías de accesorios no aparecen."
        )
        case .sk: return .init(
            usageByApp: "Využitie podľa aplikácií",
            noApps: "Teraz to nepoužíva žiadna aplikácia",
            noLocalAddress: "Žiadna lokálna adresa",
            graphWindowFormat: "Posledných %@",
            accessories: "Príslušenstvo",
            diskEject: "Bezpečné vysunutie",
            diskCapacity: "Kapacita",
            bluetoothDenied: "Bluetooth je pre Hexa vypnuté, preto sa batérie príslušenstva nezobrazia."
        )
        case .de: return .init(
            usageByApp: "Verbrauch nach App",
            noApps: "Keine App nutzt es gerade",
            noLocalAddress: "Keine lokale Adresse",
            graphWindowFormat: "Letzte %@",
            accessories: "Zubehör",
            diskEject: "Sicher auswerfen",
            diskCapacity: "Kapazität",
            bluetoothDenied: "Bluetooth ist für Hexa aus, daher erscheinen keine Zubehörakkus."
        )
        case .fr: return .init(
            usageByApp: "Utilisation par app",
            noApps: "Aucune app ne l’utilise maintenant",
            noLocalAddress: "Aucune adresse locale",
            graphWindowFormat: "Derniers %@",
            accessories: "Accessoires",
            diskEject: "Éjection sécurisée",
            diskCapacity: "Capacité",
            bluetoothDenied: "Bluetooth est désactivé pour Hexa, donc les batteries des accessoires n’apparaissent pas."
        )
        case .it: return .init(
            usageByApp: "Utilizzo per app",
            noApps: "Nessuna app lo sta usando ora",
            noLocalAddress: "Nessun indirizzo locale",
            graphWindowFormat: "Ultimi %@",
            accessories: "Accessori",
            diskEject: "Espulsione sicura",
            diskCapacity: "Capacità",
            bluetoothDenied: "Bluetooth è disattivato per Hexa, quindi le batterie degli accessori non compaiono."
        )
        case .ja: return .init(
            usageByApp: "アプリ別の使用量",
            noApps: "現在使用中のアプリはありません",
            noLocalAddress: "ローカルアドレスなし",
            graphWindowFormat: "直近 %@",
            accessories: "アクセサリ",
            diskEject: "安全な取り出し",
            diskCapacity: "容量",
            bluetoothDenied: "Hexa では Bluetooth がオフのため、アクセサリのバッテリーは表示されません。"
        )
        case .ko: return .init(
            usageByApp: "앱별 사용량",
            noApps: "지금 사용 중인 앱이 없습니다",
            noLocalAddress: "로컬 주소 없음",
            graphWindowFormat: "최근 %@",
            accessories: "액세서리",
            diskEject: "안전하게 추출",
            diskCapacity: "용량",
            bluetoothDenied: "Hexa에서 Bluetooth가 꺼져 있어 액세서리 배터리가 표시되지 않습니다."
        )
        case .uk: return .init(
            usageByApp: "Використання за застосунками",
            noApps: "Зараз жоден застосунок не використовується",
            noLocalAddress: "Немає локальної адреси",
            graphWindowFormat: "Останні %@",
            accessories: "Аксесуари",
            diskEject: "Безпечне вилучення",
            diskCapacity: "Ємність",
            bluetoothDenied: "Bluetooth для Hexa вимкнено, тому батареї аксесуарів не показуються."
        )
        case .zhHans: return .init(
            usageByApp: "各应用用量",
            noApps: "当前没有应用在使用",
            noLocalAddress: "无本地地址",
            graphWindowFormat: "最近 %@",
            accessories: "配件",
            diskEject: "安全弹出",
            diskCapacity: "容量",
            bluetoothDenied: "Hexa 的蓝牙已关闭，因此不会显示配件电量。"
        )
        case .zhTW: return .init(
            usageByApp: "各應用程式用量",
            noApps: "目前沒有應用程式在使用",
            noLocalAddress: "無本地位址",
            graphWindowFormat: "最近 %@",
            accessories: "配件",
            diskEject: "安全退出",
            diskCapacity: "容量",
            bluetoothDenied: "Hexa 的藍牙已關閉，因此不會顯示配件電量。"
        )
        case .zhHK: return .init(
            usageByApp: "各應用程式用量",
            noApps: "目前沒有應用程式在使用",
            noLocalAddress: "無本機位址",
            graphWindowFormat: "最近 %@",
            accessories: "配件",
            diskEject: "安全退出",
            diskCapacity: "容量",
            bluetoothDenied: "Hexa 的藍牙已關閉，因此不會顯示配件電量。"
        )
        }
    }
}
