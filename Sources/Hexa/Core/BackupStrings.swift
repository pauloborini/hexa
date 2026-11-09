// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Strings for the settings backup (export and import on the Advanced page).
/// Same contract as the other FeatureStrings structs: memberwise init in
/// declaration order, one static per language, all in this file.
struct BackupFeatureStrings {
    let title: String
    let description: String
    let exportButton: String
    let importButton: String
    let restorePrevious: String
    let exported: String
    let exportFailed: String
    let importConfirmTitle: String
    let importConfirmBody: String
    let importMissingIslandBody: String
    let importAction: String
    let invalidFile: String
    let copyNotSaved: String
    let restartFailed: String
}

extension FeatureStrings {
    static func backup(_ language: AppLanguage) -> BackupFeatureStrings {
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

extension BackupFeatureStrings {
    static let ko = BackupFeatureStrings(
        title: "백업",
        description: "설정을 다른 Mac으로 옮기세요. 모든 환경설정을 파일로 내보낸 뒤 그곳에서 가져올 수 있습니다. 시스템 권한, ‘로그인 시 실행’, Hexa가 가져온 macOS 단축키는 각 Mac에 그대로 남습니다.",
        exportButton: "설정 내보내기…",
        importButton: "설정 가져오기…",
        restorePrevious: "이전 설정 복원…",
        exported: "백업을 저장했습니다",
        exportFailed: "백업을 저장하지 못했습니다.",
        importConfirmTitle: "이 설정을 가져올까요?",
        importConfirmBody: "현재 설정이 파일의 설정으로 바뀌고 앱이 다시 시작됩니다. 현재 설정의 사본이 보관되며 ‘이전 설정 복원’으로 되돌릴 수 있습니다. ‘로그인 시 실행’은 이 Mac의 상태 그대로 유지되고, Hexa가 가져온 macOS 단축키는 macOS로 돌아갑니다.",
        importMissingIslandBody: "이 백업에는 Dynamic Island 설정이 없으므로 이 Mac의 설정이 유지됩니다. 다른 Mac의 설정을 복사하려면 그 Mac에서 다시 내보내세요. 나머지 설정을 가져오고 현재 설정의 사본을 보관한 뒤 앱이 다시 시작됩니다. ‘로그인 시 실행’은 그대로 유지되고, Hexa가 가져온 macOS 단축키는 macOS로 돌아갑니다.",
        importAction: "가져오고 다시 시작",
        invalidFile: "이 파일은 유효한 Hexa 백업이 아닙니다.",
        copyNotSaved: "현재 설정의 사본을 보관하지 못해 아무것도 가져오지 않았습니다.",
        restartFailed: "설정을 가져왔지만 앱을 다시 시작하지 못했습니다. 적용하려면 Hexa를 종료한 뒤 다시 여세요."
    )
    static let uk = BackupFeatureStrings(
        title: "Резервна копія",
        description: "Перенесіть свої налаштування на інший Mac: експортуйте всі параметри у файл та імпортуйте їх там. Системні дозволи, «Запускати під час входу в систему» і сполучення клавіш macOS, перехоплені Hexa, залишаються на кожному Mac.",
        exportButton: "Експортувати налаштування…",
        importButton: "Імпортувати налаштування…",
        restorePrevious: "Відновити попередні налаштування…",
        exported: "Резервну копію збережено",
        exportFailed: "Не вдалося зберегти резервну копію.",
        importConfirmTitle: "Імпортувати ці налаштування?",
        importConfirmBody: "Ваші поточні налаштування замінюються файлом, і програма перезапускається. Копія поточних налаштувань зберігається, і «Відновити попередні налаштування» поверне їх. «Запускати під час входу в систему» залишається як є на цьому Mac, а сполучення клавіш macOS, перехоплені Hexa, повертаються macOS.",
        importMissingIslandBody: "У цій резервній копії немає налаштувань Dynamic Island, тож налаштування на цьому Mac залишаться без змін. Щоб перенести їх з іншого Mac, експортуйте копію там ще раз. Решту налаштувань буде імпортовано, копію поточних збережено, а програму перезапущено. «Запускати під час входу в систему» залишається як є, а сполучення клавіш macOS, перехоплені Hexa, повертаються macOS.",
        importAction: "Імпортувати та перезапустити",
        invalidFile: "Цей файл не є коректною резервною копією Hexa.",
        copyNotSaved: "Не вдалося зберегти копію поточних налаштувань, тому нічого не імпортовано.",
        restartFailed: "Налаштування імпортовано, але програму не вдалося перезапустити. Закрийте Hexa і відкрийте знову, щоб застосувати їх."
    )
}

extension BackupFeatureStrings {
    static let enUS = BackupFeatureStrings(
        title: "Backup",
        description: "Take your setup to another Mac: export every preference to a file and import it there. System permissions, “Launch at login” and macOS shortcuts taken over by Hexa stay with each Mac.",
        exportButton: "Export settings…",
        importButton: "Import settings…",
        restorePrevious: "Restore previous settings…",
        exported: "Backup saved",
        exportFailed: "Could not save the backup.",
        importConfirmTitle: "Import these settings?",
        importConfirmBody: "Your current settings are replaced by the file’s and the app restarts. A copy of the current ones is kept, and “Restore previous settings” brings them back. “Launch at login” stays as it is on this Mac, and macOS shortcuts taken over by Hexa are given back to macOS.",
        importMissingIslandBody: "This backup has no Dynamic Island settings, so this Mac’s island settings are kept. Export again on the other Mac to copy them. The other settings are imported, a copy of the current ones is kept and the app restarts. “Launch at login” stays as it is, and macOS shortcuts taken over by Hexa are given back to macOS.",
        importAction: "Import and restart",
        invalidFile: "This file is not a valid Hexa backup.",
        copyNotSaved: "Could not keep a copy of the current settings, so nothing was imported.",
        restartFailed: "The settings were imported, but the app could not restart. Quit Hexa and open it again to apply them."
    )

    static let ptBR = BackupFeatureStrings(
        title: "Backup",
        description: "Leve sua configuração para outro Mac: exporte todas as preferências para um arquivo e importe lá. As permissões do sistema, “Iniciar junto com o Mac” e os atalhos do macOS assumidos pelo Hexa ficam em cada Mac.",
        exportButton: "Exportar configurações…",
        importButton: "Importar configurações…",
        restorePrevious: "Restaurar configurações anteriores…",
        exported: "Backup salvo",
        exportFailed: "Não foi possível salvar o backup.",
        importConfirmTitle: "Importar estas configurações?",
        importConfirmBody: "As configurações atuais são substituídas pelas do arquivo e o app reinicia. Uma cópia das atuais fica guardada, e “Restaurar configurações anteriores” as traz de volta. “Iniciar junto com o Mac” continua como está neste Mac, e os atalhos do macOS assumidos pelo Hexa voltam para o macOS.",
        importMissingIslandBody: "Este backup não contém configurações da Dynamic Island, então as deste Mac são mantidas. Para copiá-las do outro Mac, exporte novamente nele. As demais configurações são importadas, uma cópia das atuais fica guardada e o app reinicia. “Iniciar junto com o Mac” continua como está, e os atalhos do macOS assumidos pelo Hexa voltam para o macOS.",
        importAction: "Importar e reiniciar",
        invalidFile: "Este arquivo não é um backup válido do Hexa.",
        copyNotSaved: "Não foi possível guardar uma cópia das configurações atuais, então nada foi importado.",
        restartFailed: "As configurações foram importadas, mas o app não conseguiu reiniciar. Saia do Hexa e abra de novo para aplicá-las."
    )

    static let tr = BackupFeatureStrings(
        title: "Yedek",
        description: "Kurulumunuzu başka bir Mac’e taşıyın: tüm tercihleri bir dosyaya aktarın ve orada içe aktarın. Sistem izinleri, “Oturum açınca başlat” ve Hexa’nın devraldığı macOS kısayolları her Mac’te kalır.",
        exportButton: "Ayarları dışa aktar…",
        importButton: "Ayarları içe aktar…",
        restorePrevious: "Önceki ayarları geri yükle…",
        exported: "Yedek kaydedildi",
        exportFailed: "Yedek kaydedilemedi.",
        importConfirmTitle: "Bu ayarlar içe aktarılsın mı?",
        importConfirmBody: "Mevcut ayarlar dosyadakilerle değiştirilir ve uygulama yeniden başlar. Mevcut ayarların bir kopyası saklanır ve “Önceki ayarları geri yükle” onları geri getirir. “Oturum açınca başlat” bu Mac’te olduğu gibi kalır ve Hexa’nın devraldığı macOS kısayolları macOS’a geri verilir.",
        importMissingIslandBody: "Bu yedekte Dynamic Island ayarları olmadığı için bu Mac’teki ada ayarları korunur. Diğer Mac’ten kopyalamak için orada yeniden dışa aktarın. Diğer ayarlar içe aktarılır, mevcut ayarların bir kopyası saklanır ve uygulama yeniden başlar. “Oturum açınca başlat” olduğu gibi kalır ve Hexa’nın devraldığı macOS kısayolları macOS’a geri verilir.",
        importAction: "İçe aktar ve yeniden başlat",
        invalidFile: "Bu dosya geçerli bir Hexa yedeği değil.",
        copyNotSaved: "Mevcut ayarların bir kopyası saklanamadığı için hiçbir şey içe aktarılmadı.",
        restartFailed: "Ayarlar içe aktarıldı ancak uygulama yeniden başlatılamadı. Uygulamak için Hexa’dan çıkıp yeniden açın."
    )

    static let ru = BackupFeatureStrings(
        title: "Резервная копия",
        description: "Перенесите настройки на другой Mac: экспортируйте все параметры в файл и импортируйте его там. Системные разрешения, «Запускать при входе» и сочетания клавиш macOS, перехваченные Hexa, остаются на каждом Mac.",
        exportButton: "Экспортировать настройки…",
        importButton: "Импортировать настройки…",
        restorePrevious: "Восстановить прежние настройки…",
        exported: "Копия сохранена",
        exportFailed: "Не удалось сохранить копию.",
        importConfirmTitle: "Импортировать эти настройки?",
        importConfirmBody: "Текущие настройки заменяются настройками из файла, и приложение перезапускается. Копия текущих настроек сохраняется, и «Восстановить прежние настройки» вернёт их. «Запускать при входе» остаётся как есть на этом Mac, а сочетания клавиш macOS, перехваченные Hexa, возвращаются macOS.",
        importMissingIslandBody: "В этой копии нет настроек Dynamic Island, поэтому настройки на этом Mac сохранятся. Чтобы перенести их с другого Mac, экспортируйте копию там заново. Остальные настройки импортируются, копия текущих сохраняется, затем приложение перезапускается. «Запускать при входе» остаётся как есть, а сочетания клавиш macOS, перехваченные Hexa, возвращаются macOS.",
        importAction: "Импортировать и перезапустить",
        invalidFile: "Этот файл не является корректной резервной копией Hexa.",
        copyNotSaved: "Не удалось сохранить копию текущих настроек, поэтому ничего не импортировано.",
        restartFailed: "Настройки импортированы, но приложение не удалось перезапустить. Закройте Hexa и откройте снова, чтобы применить их."
    )

    static let es = BackupFeatureStrings(
        title: "Copia de seguridad",
        description: "Lleva tu configuración a otro Mac: exporta todas las preferencias a un archivo e impórtalo allí. Los permisos del sistema, «Abrir al iniciar sesión» y los atajos de macOS que Hexa toma se quedan en cada Mac.",
        exportButton: "Exportar ajustes…",
        importButton: "Importar ajustes…",
        restorePrevious: "Restaurar ajustes anteriores…",
        exported: "Copia guardada",
        exportFailed: "No se pudo guardar la copia.",
        importConfirmTitle: "¿Importar estos ajustes?",
        importConfirmBody: "Los ajustes actuales se sustituyen por los del archivo y la app se reinicia. Se guarda una copia de los actuales, y «Restaurar ajustes anteriores» los recupera. «Abrir al iniciar sesión» sigue como está en este Mac, y los atajos de macOS que Hexa toma vuelven a macOS.",
        importMissingIslandBody: "Esta copia no contiene ajustes de Dynamic Island, así que se conservan los de este Mac. Para copiarlos desde el otro Mac, exporta de nuevo allí. Se importan los demás ajustes, se guarda una copia de los actuales y la app se reinicia. «Abrir al iniciar sesión» sigue como está, y los atajos de macOS que Hexa toma vuelven a macOS.",
        importAction: "Importar y reiniciar",
        invalidFile: "Este archivo no es una copia de seguridad válida de Hexa.",
        copyNotSaved: "No se pudo guardar una copia de los ajustes actuales, así que no se importó nada.",
        restartFailed: "Los ajustes se importaron, pero la app no pudo reiniciarse. Sal de Hexa y vuelve a abrirlo para aplicarlos."
    )

    static let sk = BackupFeatureStrings(
        title: "Záloha",
        description: "Preneste svoje nastavenie na iný Mac: exportujte všetky predvoľby do súboru a importujte ich tam. Systémové oprávnenia, „Spustiť po prihlásení“ a skratky macOS prevzaté aplikáciou Hexa zostávajú na každom Macu.",
        exportButton: "Exportovať nastavenia…",
        importButton: "Importovať nastavenia…",
        restorePrevious: "Obnoviť predchádzajúce nastavenia…",
        exported: "Záloha uložená",
        exportFailed: "Zálohu sa nepodarilo uložiť.",
        importConfirmTitle: "Importovať tieto nastavenia?",
        importConfirmBody: "Vaše aktuálne nastavenia sa nahradia nastaveniami zo súboru a aplikácia sa reštartuje. Kópia aktuálnych nastavení sa uchová a „Obnoviť predchádzajúce nastavenia“ ich vráti. „Spustiť po prihlásení“ zostane na tomto Macu tak, ako je, a skratky macOS prevzaté aplikáciou Hexa sa vrátia macOS.",
        importMissingIslandBody: "Táto záloha neobsahuje nastavenia Dynamic Island, preto nastavenia na tomto Macu zostanú zachované. Ak ich chcete preniesť z druhého Macu, exportujte tam zálohu znova. Ostatné nastavenia sa importujú, kópia aktuálnych sa uchová a aplikácia sa reštartuje. „Spustiť po prihlásení“ zostane tak, ako je, a skratky macOS prevzaté aplikáciou Hexa sa vrátia macOS.",
        importAction: "Importovať a reštartovať",
        invalidFile: "Tento súbor nie je platná záloha Hexa.",
        copyNotSaved: "Kópiu aktuálnych nastavení sa nepodarilo uchovať, preto sa nič neimportovalo.",
        restartFailed: "Nastavenia sa importovali, ale aplikáciu sa nepodarilo reštartovať. Ukončite Hexa a znova ho otvorte, aby sa použili."
    )

    static let de = BackupFeatureStrings(
        title: "Backup",
        description: "Nimm deine Einrichtung mit auf einen anderen Mac: exportiere alle Einstellungen in eine Datei und importiere sie dort. Systemberechtigungen, „Beim Anmelden öffnen“ und von Hexa übernommene macOS-Kurzbefehle bleiben auf dem jeweiligen Mac.",
        exportButton: "Einstellungen exportieren…",
        importButton: "Einstellungen importieren…",
        restorePrevious: "Vorherige Einstellungen wiederherstellen…",
        exported: "Backup gesichert",
        exportFailed: "Backup konnte nicht gesichert werden.",
        importConfirmTitle: "Diese Einstellungen importieren?",
        importConfirmBody: "Die aktuellen Einstellungen werden durch die der Datei ersetzt und die App startet neu. Eine Kopie der aktuellen bleibt erhalten, und „Vorherige Einstellungen wiederherstellen“ holt sie zurück. „Beim Anmelden öffnen“ bleibt auf diesem Mac, wie es ist, und von Hexa übernommene macOS-Kurzbefehle gehen an macOS zurück.",
        importMissingIslandBody: "Dieses Backup enthält keine Dynamic-Island-Einstellungen, daher bleiben die dieses Mac erhalten. Um sie vom anderen Mac zu übernehmen, exportiere dort erneut. Die übrigen Einstellungen werden importiert, eine Kopie der aktuellen bleibt erhalten und die App startet neu. „Beim Anmelden öffnen“ bleibt, wie es ist, und von Hexa übernommene macOS-Kurzbefehle gehen an macOS zurück.",
        importAction: "Importieren und neu starten",
        invalidFile: "Diese Datei ist kein gültiges Hexa-Backup.",
        copyNotSaved: "Es konnte keine Kopie der aktuellen Einstellungen gesichert werden, daher wurde nichts importiert.",
        restartFailed: "Die Einstellungen wurden importiert, aber die App konnte nicht neu starten. Beende Hexa und öffne es erneut, um sie anzuwenden."
    )

    static let fr = BackupFeatureStrings(
        title: "Sauvegarde",
        description: "Emportez votre configuration sur un autre Mac\u{00A0}: exportez toutes les préférences dans un fichier et importez-le là-bas. Les autorisations système, «\u{00A0}Ouvrir à l’ouverture de session\u{00A0}» et les raccourcis macOS repris par Hexa restent propres à chaque Mac.",
        exportButton: "Exporter les réglages…",
        importButton: "Importer les réglages…",
        restorePrevious: "Restaurer les réglages précédents…",
        exported: "Sauvegarde enregistrée",
        exportFailed: "Impossible d’enregistrer la sauvegarde.",
        importConfirmTitle: "Importer ces réglages\u{00A0}?",
        importConfirmBody: "Les réglages actuels sont remplacés par ceux du fichier et l’app redémarre. Une copie des réglages actuels est conservée, et «\u{00A0}Restaurer les réglages précédents\u{00A0}» les rétablit. «\u{00A0}Ouvrir à l’ouverture de session\u{00A0}» reste tel quel sur ce Mac, et les raccourcis macOS repris par Hexa sont rendus à macOS.",
        importMissingIslandBody: "Cette sauvegarde ne contient aucun réglage de Dynamic Island, donc ceux de ce Mac sont conservés. Pour les copier depuis l’autre Mac, exportez à nouveau depuis celui-ci. Les autres réglages sont importés, une copie des réglages actuels est conservée et l’app redémarre. «\u{00A0}Ouvrir à l’ouverture de session\u{00A0}» reste tel quel, et les raccourcis macOS repris par Hexa sont rendus à macOS.",
        importAction: "Importer et redémarrer",
        invalidFile: "Ce fichier n’est pas une sauvegarde Hexa valide.",
        copyNotSaved: "Impossible de conserver une copie des réglages actuels, donc rien n’a été importé.",
        restartFailed: "Les réglages ont été importés, mais l’app n’a pas pu redémarrer. Quittez Hexa et rouvrez-le pour les appliquer."
    )

    static let it = BackupFeatureStrings(
        title: "Backup",
        description: "Porta la tua configurazione su un altro Mac: esporta tutte le preferenze in un file e importalo lì. I permessi di sistema, «Apri al login» e le scorciatoie di macOS prese da Hexa restano su ciascun Mac.",
        exportButton: "Esporta impostazioni…",
        importButton: "Importa impostazioni…",
        restorePrevious: "Ripristina impostazioni precedenti…",
        exported: "Backup salvato",
        exportFailed: "Impossibile salvare il backup.",
        importConfirmTitle: "Importare queste impostazioni?",
        importConfirmBody: "Le impostazioni attuali vengono sostituite da quelle del file e l’app si riavvia. Una copia di quelle attuali viene conservata e «Ripristina impostazioni precedenti» le riporta indietro. «Apri al login» resta com’è su questo Mac e le scorciatoie di macOS prese da Hexa tornano a macOS.",
        importMissingIslandBody: "Questo backup non contiene le impostazioni di Dynamic Island, quindi quelle di questo Mac vengono mantenute. Per copiarle dall’altro Mac, esporta di nuovo da lì. Le altre impostazioni vengono importate, una copia di quelle attuali viene conservata e l’app si riavvia. «Apri al login» resta com’è e le scorciatoie di macOS prese da Hexa tornano a macOS.",
        importAction: "Importa e riavvia",
        invalidFile: "Questo file non è un backup Hexa valido.",
        copyNotSaved: "Impossibile conservare una copia delle impostazioni attuali, quindi non è stato importato nulla.",
        restartFailed: "Le impostazioni sono state importate, ma l’app non è riuscita a riavviarsi. Esci da Hexa e riaprilo per applicarle."
    )

    static let ja = BackupFeatureStrings(
        title: "バックアップ",
        description: "設定を別のMacに移せます。すべての環境設定をファイルに書き出し、移行先で読み込んでください。システムの権限、「ログイン時に起動」、Hexaが引き継いだmacOSのショートカットは各Macに残ります。",
        exportButton: "設定を書き出す…",
        importButton: "設定を読み込む…",
        restorePrevious: "以前の設定に戻す…",
        exported: "バックアップを保存しました",
        exportFailed: "バックアップを保存できませんでした。",
        importConfirmTitle: "この設定を読み込みますか?",
        importConfirmBody: "現在の設定はファイルの内容に置き換えられ、アプリが再起動します。現在の設定のコピーが保存され、「以前の設定に戻す」で元に戻せます。「ログイン時に起動」はこのMacの状態のままで、Hexaが引き継いだmacOSのショートカットはmacOSに戻ります。",
        importMissingIslandBody: "このバックアップにはDynamic Islandの設定がないため、このMacの設定は維持されます。別のMacからコピーするには、そのMacで再度書き出してください。その他の設定が読み込まれ、現在の設定のコピーが保存されてからアプリが再起動します。「ログイン時に起動」はそのままで、Hexaが引き継いだmacOSのショートカットはmacOSに戻ります。",
        importAction: "読み込んで再起動",
        invalidFile: "このファイルは有効なHexaのバックアップではありません。",
        copyNotSaved: "現在の設定のコピーを保存できなかったため、何も読み込まれませんでした。",
        restartFailed: "設定は読み込まれましたが、アプリを再起動できませんでした。Hexaを終了してもう一度開くと反映されます。"
    )

    static let zhHans = BackupFeatureStrings(
        title: "备份",
        description: "将你的设置带到另一台 Mac：把所有偏好设置导出为文件，然后在那里导入。系统权限、“登录时启动”以及 Hexa 接管的 macOS 快捷键会留在各自的 Mac 上。",
        exportButton: "导出设置…",
        importButton: "导入设置…",
        restorePrevious: "恢复之前的设置…",
        exported: "备份已存储",
        exportFailed: "无法存储备份。",
        importConfirmTitle: "导入这些设置？",
        importConfirmBody: "当前设置将被文件中的设置替换，App 会重启。当前设置会保留一份副本，可通过“恢复之前的设置”找回。“登录时启动”在这台 Mac 上保持不变，Hexa 接管的 macOS 快捷键会交还给 macOS。",
        importMissingIslandBody: "此备份不包含 Dynamic Island 设置，因此这台 Mac 上的相关设置将保留。要从另一台 Mac 复制这些设置，请在那台 Mac 上重新导出。其他设置将被导入，当前设置会保留一份副本，然后 App 会重启。“登录时启动”保持不变，Hexa 接管的 macOS 快捷键会交还给 macOS。",
        importAction: "导入并重启",
        invalidFile: "该文件不是有效的 Hexa 备份。",
        copyNotSaved: "无法保留当前设置的副本，因此未导入任何内容。",
        restartFailed: "设置已导入，但 App 无法重启。请退出 Hexa 后重新打开以应用这些设置。"
    )

    static let zhTW = BackupFeatureStrings(
        title: "備份",
        description: "將你的設定帶到另一台 Mac：把所有偏好設定匯出為檔案，再在那裡匯入。系統權限、「登入時啟動」以及 Hexa 接管的 macOS 快速鍵會留在各自的 Mac 上。",
        exportButton: "匯出設定…",
        importButton: "匯入設定…",
        restorePrevious: "還原先前的設定…",
        exported: "備份已儲存",
        exportFailed: "無法儲存備份。",
        importConfirmTitle: "匯入這些設定?",
        importConfirmBody: "目前設定將被檔案中的設定取代，App 會重新啟動。目前設定會保留一份副本，可透過「還原先前的設定」找回。「登入時啟動」在這台 Mac 上維持不變，Hexa 接管的 macOS 快速鍵會交還給 macOS。",
        importMissingIslandBody: "此備份不包含 Dynamic Island 設定，因此這台 Mac 上的相關設定會保留。若要從另一台 Mac 複製這些設定，請在那台 Mac 上重新匯出。其他設定會匯入，目前設定會保留一份副本，然後 App 會重新啟動。「登入時啟動」維持不變，Hexa 接管的 macOS 快速鍵會交還給 macOS。",
        importAction: "匯入並重新啟動",
        invalidFile: "此檔案不是有效的 Hexa 備份。",
        copyNotSaved: "無法保留目前設定的副本，因此未匯入任何內容。",
        restartFailed: "設定已匯入，但 App 無法重新啟動。請結束 Hexa 後重新開啟以套用這些設定。"
    )

    static let zhHK = BackupFeatureStrings(
        title: "備份",
        description: "將你嘅設定帶到另一部 Mac：將所有偏好設定匯出成檔案，再喺嗰度匯入。系統權限、「登入時啟動」同埋 Hexa 接管嘅 macOS 快速鍵會留喺各自嘅 Mac 上。",
        exportButton: "匯出設定…",
        importButton: "匯入設定…",
        restorePrevious: "還原之前嘅設定…",
        exported: "備份已儲存",
        exportFailed: "儲存唔到備份。",
        importConfirmTitle: "匯入這些設定?",
        importConfirmBody: "目前設定會被檔案入面嘅設定取代，App 會重新啟動。目前設定會保留一份副本，可以用「還原之前嘅設定」攞返。「登入時啟動」喺呢部 Mac 上維持不變，Hexa 接管嘅 macOS 快速鍵會交返俾 macOS。",
        importMissingIslandBody: "呢份備份冇 Dynamic Island 設定，所以呢部 Mac 上嘅相關設定會保留。想從另一部 Mac 複製呢啲設定，請喺嗰部 Mac 重新匯出。其他設定會匯入，目前設定會保留一份副本，之後 App 會重新啟動。「登入時啟動」維持不變，Hexa 接管嘅 macOS 快速鍵會交返俾 macOS。",
        importAction: "匯入並重新啟動",
        invalidFile: "此檔案不是有效嘅 Hexa 備份。",
        copyNotSaved: "未能保留目前設定嘅副本，所以冇匯入任何內容。",
        restartFailed: "設定已經匯入，但 App 未能重新啟動。請結束 Hexa 再重新開啟嚟套用呢啲設定。"
    )
}
