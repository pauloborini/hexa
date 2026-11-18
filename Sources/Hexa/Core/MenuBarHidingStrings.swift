// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Strings for splitting the menu bar into visible and hidden sections.
struct MenuBarHidingStrings {
    let title: String
    let hubDescription: String
    let enableCaption: String
    let visible: String
    let hidden: String
    let rehideDelayTitle: String
    let rehideInstant: String
    let emptySection: String
    let dragHint: String
    let unavailable: String
    let activationFailed: String
    let readFailed: String
    let separatorHint: String
    let rehideHint: String
    let rehideFiveSeconds: String
    let rehideTenSeconds: String
    let toggleShortcutTitle: String
    let toggleShortcutCaption: String
    let shortcutUnavailable: String
}

extension FeatureStrings {
    static func menuBarHiding(_ language: AppLanguage) -> MenuBarHidingStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension MenuBarHidingStrings {
    static let enUS = MenuBarHidingStrings(
        title: "Menu bar icons",
        hubDescription: "Split other apps' menu bar items into visible and hidden sections.",
        enableCaption: "The module adds an arrow to the menu bar. Hold Command and drag icons across it to choose which stay visible. Click the arrow to reveal hidden icons temporarily.",
        visible: "Visible",
        hidden: "Hidden",
        rehideDelayTitle: "Hide again",
        rehideInstant: "Instant",
        emptySection: "No app in this section",
        dragHint: "⌘-drag icons across the arrow to move them between the visible and hidden sections.",
        unavailable: "This build cannot safely hide other apps' menu bar items.",
        activationFailed: "Hiding other apps' menu bar items did not finish in time, so nothing was hidden.",
        readFailed: "Accessibility returned no menu bar item, so nothing was hidden. Grant Accessibility and try again.",
        separatorHint: "Divides the visible items from the hidden ones",
        rehideHint: "Click outside the menu bar or press Escape to hide again. The 5- and 10-second limits restart when you click the menu bar.",
        rehideFiveSeconds: "5 seconds",
        rehideTenSeconds: "10 seconds",
        toggleShortcutTitle: "Toggle shortcut",
        toggleShortcutCaption: "Hide or show the hidden section without leaving the keyboard.",
        shortcutUnavailable: "The shortcut could not be registered. Choose another combination."
    )

    static let ptBR = MenuBarHidingStrings(
        title: "Ícones da menu bar",
        hubDescription: "Separe os itens de outros apps na menu bar em seções visível e oculta.",
        enableCaption: "O módulo adiciona uma seta à menu bar. Segure Command e arraste os ícones através dela para escolher quais ficam visíveis. Clique na seta para revelar temporariamente os ícones ocultos.",
        visible: "Visível",
        hidden: "Oculta",
        rehideDelayTitle: "Recolher após",
        rehideInstant: "Instantâneo",
        emptySection: "Nenhum app nesta seção",
        dragHint: "Arraste ícones com ⌘ através da seta para movê-los entre as seções visível e oculta.",
        unavailable: "Este build não pode ocultar com segurança os itens da menu bar de outros apps.",
        activationFailed: "Esconder os itens da menu bar de outros apps não terminou a tempo, então nada foi escondido.",
        readFailed: "A Acessibilidade não devolveu nenhum item da menu bar, então nada foi escondido. Conceda a Acessibilidade e tente de novo.",
        separatorHint: "Separa os itens visíveis dos ocultos",
        rehideHint: "Clique fora da menu bar ou pressione Escape para recolher. Os limites de 5 e 10 segundos recomeçam ao clicar na barra.",
        rehideFiveSeconds: "5 segundos",
        rehideTenSeconds: "10 segundos",
        toggleShortcutTitle: "Atalho de alternância",
        toggleShortcutCaption: "Oculta ou mostra a seção oculta sem sair do teclado.",
        shortcutUnavailable: "Não foi possível registrar o atalho. Escolha outra combinação."
    )

    static let tr = MenuBarHidingStrings(
        title: "Menü çubuğu simgeleri",
        hubDescription: "Diğer uygulamaların menü çubuğu öğelerini görünür ve gizli bölümlere ayırır.",
        enableCaption: "Modül menü çubuğuna bir ok ekler. Hangilerinin görünür kalacağını seçmek için Command tuşuna basılı tutup simgeleri okun üzerinden sürükleyin. Gizli simgeleri geçici olarak göstermek için oka tıklayın.",
        visible: "Görünür",
        hidden: "Gizli",
        rehideDelayTitle: "Yeniden gizle",
        rehideInstant: "Anında",
        emptySection: "Bu bölümde uygulama yok",
        dragHint: "Simgeleri görünür ve gizli bölümler arasında taşımak için ⌘ ile okun üzerinden sürükleyin.",
        unavailable: "Bu derleme, diğer uygulamaların menü çubuğu öğelerini güvenle gizleyemiyor.",
        activationFailed: "Diğer uygulamaların menü çubuğu öğelerini gizleme zamanında bitmedi, bu yüzden hiçbir şey gizlenmedi.",
        readFailed: "Erişilebilirlik hiçbir menü çubuğu öğesi döndürmedi, bu yüzden hiçbir şey gizlenmedi. Erişilebilirliği verip yeniden deneyin.",
        separatorHint: "Görünür öğeleri gizli olanlardan ayırır",
        rehideHint: "Yeniden gizlemek için menü çubuğunun dışına tıklayın veya Escape tuşuna basın. Menü çubuğuna tıklayınca 5 ve 10 saniyelik süreler yeniden başlar.",
        rehideFiveSeconds: "5 saniye",
        rehideTenSeconds: "10 saniye",
        toggleShortcutTitle: "Geçiş kısayolu",
        toggleShortcutCaption: "Gizli bölümü klavyeden ayrılmadan gizler veya gösterir.",
        shortcutUnavailable: "Kısayol kaydedilemedi. Başka bir kombinasyon seçin."
    )

    static let ru = MenuBarHidingStrings(
        title: "Значки строки меню",
        hubDescription: "Разделяет пункты строки меню других приложений на видимые и скрытые разделы.",
        enableCaption: "Модуль добавляет стрелку в строку меню. Удерживайте Command и перетаскивайте значки через неё, чтобы выбрать, какие оставить видимыми. Нажмите стрелку, чтобы временно показать скрытые значки.",
        visible: "Видимые",
        hidden: "Скрытые",
        rehideDelayTitle: "Скрывать снова",
        rehideInstant: "Мгновенно",
        emptySection: "В этом разделе нет приложений",
        dragHint: "Перетаскивайте значки с ⌘ через стрелку, чтобы перемещать их между видимым и скрытым разделами.",
        unavailable: "Эта сборка не может безопасно скрывать пункты строки меню других приложений.",
        activationFailed: "Скрытие пунктов строки меню других приложений не успело завершиться, поэтому ничего не скрыто.",
        readFailed: "Универсальный доступ не вернул ни одного пункта строки меню, поэтому ничего не скрыто. Разрешите доступ и повторите попытку.",
        separatorHint: "Отделяет видимые пункты от скрытых",
        rehideHint: "Щёлкните за пределами строки меню или нажмите Escape, чтобы скрыть значки. Отсчёт 5 или 10 секунд начинается заново при щелчке по строке меню.",
        rehideFiveSeconds: "5 секунд",
        rehideTenSeconds: "10 секунд",
        toggleShortcutTitle: "Сочетание переключения",
        toggleShortcutCaption: "Скрывает или показывает скрытый раздел, не покидая клавиатуру.",
        shortcutUnavailable: "Не удалось зарегистрировать сочетание. Выберите другое."
    )

    static let es = MenuBarHidingStrings(
        title: "Iconos de la barra de menús",
        hubDescription: "Separa los elementos de la barra de menús de otras apps en secciones visible y oculta.",
        enableCaption: "El módulo añade una flecha a la barra de menús. Mantén Command y arrastra los iconos a través de ella para elegir cuáles quedan visibles. Haz clic en la flecha para mostrar temporalmente los iconos ocultos.",
        visible: "Visibles",
        hidden: "Ocultos",
        rehideDelayTitle: "Volver a ocultar",
        rehideInstant: "Al instante",
        emptySection: "No hay ninguna app en esta sección",
        dragHint: "Arrastra iconos con ⌘ a través de la flecha para moverlos entre las secciones visible y oculta.",
        unavailable: "Esta compilación no puede ocultar de forma segura los elementos de la barra de menús de otras apps.",
        activationFailed: "Ocultar los ítems de la barra de menús de otras apps no terminó a tiempo, así que no se ocultó nada.",
        readFailed: "Accesibilidad no devolvió ningún ítem de la barra de menús, así que no se ocultó nada. Concede Accesibilidad e inténtalo de nuevo.",
        separatorHint: "Separa los ítems visibles de los ocultos",
        rehideHint: "Haz clic fuera de la barra de menús o pulsa Escape para volver a ocultar los iconos. Los límites de 5 y 10 segundos se reinician al hacer clic en la barra.",
        rehideFiveSeconds: "5 segundos",
        rehideTenSeconds: "10 segundos",
        toggleShortcutTitle: "Atajo de alternancia",
        toggleShortcutCaption: "Oculta o muestra la sección oculta sin dejar el teclado.",
        shortcutUnavailable: "No se pudo registrar el atajo. Elige otra combinación."
    )

    static let sk = MenuBarHidingStrings(
        title: "Ikony na paneli ponúk",
        hubDescription: "Rozdeľuje položky panela ponúk iných aplikácií na viditeľné a skryté sekcie.",
        enableCaption: "Modul pridá na panel ponúk šípku. Podržte Command a pretiahnite ikony cez šípku, aby ste vybrali, ktoré zostanú viditeľné. Kliknutím na šípku dočasne zobrazíte skryté ikony.",
        visible: "Viditeľné",
        hidden: "Skryté",
        rehideDelayTitle: "Znova skryť",
        rehideInstant: "Okamžite",
        emptySection: "V tejto sekcii nie je žiadna aplikácia",
        dragHint: "Potiahnutím ikon s ⌘ cez šípku ich presuniete medzi viditeľnou a skrytou sekciou.",
        unavailable: "Toto zostavenie nemôže bezpečne skryť položky panela ponúk iných aplikácií.",
        activationFailed: "Skrývanie položiek panela ponúk iných aplikácií sa nestihlo včas, takže sa nič neskrylo.",
        readFailed: "Prístupnosť nevrátila žiadnu položku panela ponúk, takže sa nič neskrylo. Povoľte Prístupnosť a skúste to znova.",
        separatorHint: "Oddeľuje viditeľné položky od skrytých",
        rehideHint: "Kliknutím mimo panela ponúk alebo stlačením Escape ikony znova skryjete. Limity 5 a 10 sekúnd sa po kliknutí na panel ponúk začnú odznova.",
        rehideFiveSeconds: "5 sekúnd",
        rehideTenSeconds: "10 sekúnd",
        toggleShortcutTitle: "Skratka prepínania",
        toggleShortcutCaption: "Skryje alebo zobrazí skrytú sekciu bez opustenia klávesnice.",
        shortcutUnavailable: "Skratku sa nepodarilo zaregistrovať. Vyberte inú kombináciu."
    )

    static let de = MenuBarHidingStrings(
        title: "Menüleisten-Symbole",
        hubDescription: "Teilt die Menüleisteneinträge anderer Apps in sichtbare und ausgeblendete Bereiche.",
        enableCaption: "Das Modul fügt der Menüleiste einen Pfeil hinzu. Halte Command gedrückt und ziehe Symbole darüber, um festzulegen, welche sichtbar bleiben. Ein Klick auf den Pfeil zeigt ausgeblendete Symbole vorübergehend.",
        visible: "Sichtbar",
        hidden: "Ausgeblendet",
        rehideDelayTitle: "Wieder ausblenden",
        rehideInstant: "Sofort",
        emptySection: "Keine App in diesem Bereich",
        dragHint: "Ziehe Symbole mit ⌘ über den Pfeil, um sie zwischen sichtbar und ausgeblendet zu verschieben.",
        unavailable: "Dieser Build kann Menüleisteneinträge anderer Apps nicht sicher ausblenden.",
        activationFailed: "Das Ausblenden der Menüleisteneinträge anderer Apps wurde nicht rechtzeitig fertig, deshalb wurde nichts ausgeblendet.",
        readFailed: "Bedienungshilfen haben keinen Menüleisteneintrag geliefert, deshalb wurde nichts ausgeblendet. Erlaube die Bedienungshilfen und versuche es erneut.",
        separatorHint: "Trennt die sichtbaren von den ausgeblendeten Einträgen",
        rehideHint: "Klicke außerhalb der Menüleiste oder drücke Escape, um die Symbole wieder auszublenden. Die Fristen von 5 und 10 Sekunden beginnen bei einem Klick auf die Menüleiste erneut.",
        rehideFiveSeconds: "5 Sekunden",
        rehideTenSeconds: "10 Sekunden",
        toggleShortcutTitle: "Umschalt-Tastenkürzel",
        toggleShortcutCaption: "Blendet den ausgeblendeten Bereich aus oder ein, ohne die Tastatur zu verlassen.",
        shortcutUnavailable: "Das Tastenkürzel konnte nicht registriert werden. Wähle eine andere Kombination."
    )

    static let fr = MenuBarHidingStrings(
        title: "Icônes de la barre des menus",
        hubDescription: "Sépare les éléments de la barre des menus des autres apps en sections visible et masquée.",
        enableCaption: "Le module ajoute une flèche à la barre des menus. Maintenez Command et faites glisser les icônes au-delà pour choisir celles qui restent visibles. Cliquez sur la flèche pour afficher temporairement les icônes masquées.",
        visible: "Visibles",
        hidden: "Masqués",
        rehideDelayTitle: "Masquer à nouveau",
        rehideInstant: "Instantanément",
        emptySection: "Aucune app dans cette section",
        dragHint: "Faites glisser les icônes avec ⌘ au-delà de la flèche pour les déplacer entre les sections visible et masquée.",
        unavailable: "Cette version ne peut pas masquer en toute sécurité les éléments de la barre des menus des autres apps.",
        activationFailed: "Le masquage des éléments de la barre des menus des autres apps n’a pas abouti à temps, donc rien n’a été masqué.",
        readFailed: "L’accessibilité n’a renvoyé aucun élément de la barre des menus, donc rien n’a été masqué. Accordez l’accessibilité et réessayez.",
        separatorHint: "Sépare les éléments visibles des éléments masqués",
        rehideHint: "Cliquez hors de la barre des menus ou appuyez sur Échap pour masquer les icônes. Les délais de 5 et 10 secondes recommencent lorsque vous cliquez sur la barre des menus.",
        rehideFiveSeconds: "5 secondes",
        rehideTenSeconds: "10 secondes",
        toggleShortcutTitle: "Raccourci de bascule",
        toggleShortcutCaption: "Masque ou affiche la section masquée sans quitter le clavier.",
        shortcutUnavailable: "Le raccourci n’a pas pu être enregistré. Choisissez une autre combinaison."
    )

    static let it = MenuBarHidingStrings(
        title: "Icone della barra dei menu",
        hubDescription: "Divide gli elementi della barra dei menu delle altre app in sezioni visibile e nascosta.",
        enableCaption: "Il modulo aggiunge una freccia alla barra dei menu. Tieni premuto Command e trascina le icone oltre la freccia per scegliere quali lasciare visibili. Fai clic sulla freccia per mostrare temporaneamente le icone nascoste.",
        visible: "Visibili",
        hidden: "Nascosti",
        rehideDelayTitle: "Nascondi di nuovo",
        rehideInstant: "Subito",
        emptySection: "Nessuna app in questa sezione",
        dragHint: "Trascina le icone con ⌘ oltre la freccia per spostarle tra le sezioni visibile e nascosta.",
        unavailable: "Questa build non può nascondere in modo sicuro gli elementi della barra dei menu delle altre app.",
        activationFailed: "La schermatura degli elementi della barra dei menu delle altre app non è finita in tempo, quindi non è stato nascosto nulla.",
        readFailed: "Accessibilità non ha restituito alcun elemento della barra dei menu, quindi non è stato nascosto nulla. Concedi Accessibilità e riprova.",
        separatorHint: "Separa gli elementi visibili da quelli nascosti",
        rehideHint: "Fai clic fuori dalla barra dei menu o premi Esc per nascondere di nuovo le icone. I limiti di 5 e 10 secondi ripartono quando fai clic sulla barra dei menu.",
        rehideFiveSeconds: "5 secondi",
        rehideTenSeconds: "10 secondi",
        toggleShortcutTitle: "Scorciatoia di commutazione",
        toggleShortcutCaption: "Nasconde o mostra la sezione nascosta senza lasciare la tastiera.",
        shortcutUnavailable: "Non è stato possibile registrare la scorciatoia. Scegli un’altra combinazione."
    )

    static let ja = MenuBarHidingStrings(
        title: "メニューバーのアイコン",
        hubDescription: "ほかのアプリのメニューバー項目を、表示と非表示のセクションに分けます。",
        enableCaption: "メニューバーに矢印を追加します。Command を押しながらアイコンを矢印の向こうへドラッグして、表示するアイコンを選びます。矢印をクリックすると非表示のアイコンが一時的に表示されます。",
        visible: "表示",
        hidden: "非表示",
        rehideDelayTitle: "再び隠すまで",
        rehideInstant: "すぐに",
        emptySection: "このセクションにアプリはありません",
        dragHint: "⌘ を押しながらアイコンを矢印の向こうへドラッグすると、表示と非表示を切り替えられます。",
        unavailable: "このビルドでは、ほかのアプリのメニューバー項目を安全に隠せません。",
        activationFailed: "ほかのアプリのメニューバー項目を隠す処理が時間内に終わらなかったため、何も隠していません。",
        readFailed: "アクセシビリティがメニューバーの項目を返さなかったため、何も隠していません。アクセシビリティを許可して、もう一度お試しください。",
        separatorHint: "表示項目と非表示項目を分けます",
        rehideHint: "メニューバーの外をクリックするか Esc キーを押すと、アイコンを再び隠します。5秒と10秒の制限時間は、メニューバーをクリックすると最初から始まります。",
        rehideFiveSeconds: "5秒",
        rehideTenSeconds: "10秒",
        toggleShortcutTitle: "切り替えショートカット",
        toggleShortcutCaption: "キーボードから離れずに非表示セクションを表示または非表示にします。",
        shortcutUnavailable: "ショートカットを登録できませんでした。別の組み合わせを選んでください。"
    )

    static let ko = MenuBarHidingStrings(
        title: "메뉴 막대 아이콘",
        hubDescription: "다른 앱의 메뉴 막대 항목을 표시 및 숨김 섹션으로 나눕니다.",
        enableCaption: "메뉴 막대에 화살표를 추가합니다. Command를 누른 채 아이콘을 화살표 너머로 드래그해 표시할 항목을 고릅니다. 화살표를 클릭하면 숨긴 아이콘이 잠시 표시됩니다.",
        visible: "표시",
        hidden: "숨김",
        rehideDelayTitle: "다시 숨기기",
        rehideInstant: "즉시",
        emptySection: "이 섹션에 앱이 없습니다",
        dragHint: "⌘를 누른 채 아이콘을 화살표 너머로 드래그하면 표시와 숨김을 옮길 수 있습니다.",
        unavailable: "이 빌드에서는 다른 앱의 메뉴 막대 항목을 안전하게 가릴 수 없습니다.",
        activationFailed: "다른 앱의 메뉴 막대 항목을 숨기는 작업이 제시간에 끝나지 않아 아무것도 숨기지 않았습니다.",
        readFailed: "손쉬운 사용이 메뉴 막대 항목을 반환하지 않아 아무것도 숨기지 않았습니다. 손쉬운 사용을 허용하고 다시 시도하세요.",
        separatorHint: "표시 항목과 숨김 항목을 나눕니다",
        rehideHint: "메뉴 막대 바깥을 클릭하거나 Esc 키를 누르면 아이콘을 다시 숨깁니다. 메뉴 막대를 클릭하면 5초 또는 10초 제한 시간이 다시 시작됩니다.",
        rehideFiveSeconds: "5초",
        rehideTenSeconds: "10초",
        toggleShortcutTitle: "전환 단축키",
        toggleShortcutCaption: "키보드에서 손을 떼지 않고 숨김 섹션을 표시하거나 숨깁니다.",
        shortcutUnavailable: "단축키를 등록할 수 없습니다. 다른 조합을 선택하세요."
    )

    static let uk = MenuBarHidingStrings(
        title: "Значки рядка меню",
        hubDescription: "Розділяє пункти рядка меню інших програм на видимі та приховані розділи.",
        enableCaption: "Модуль додає стрілку в рядок меню. Утримуйте Command і перетягуйте значки через неї, щоб вибрати, які залишити видимими. Натисніть стрілку, щоб тимчасово показати приховані значки.",
        visible: "Видимі",
        hidden: "Приховані",
        rehideDelayTitle: "Приховати знову",
        rehideInstant: "Миттєво",
        emptySection: "У цьому розділі немає програм",
        dragHint: "Перетягуйте значки з ⌘ через стрілку, щоб переміщати їх між видимим і прихованим розділами.",
        unavailable: "Ця збірка не може безпечно приховувати пункти рядка меню інших програм.",
        activationFailed: "Приховування пунктів рядка меню інших програм не встигло завершитися, тому нічого не приховано.",
        readFailed: "Универсальний доступ не повернув жодного пункту рядка меню, тому нічого не приховано. Дозвольте доступ і спробуйте ще раз.",
        separatorHint: "Відділяє видимі пункти від прихованих",
        rehideHint: "Клацніть за межами рядка меню або натисніть Escape, щоб знову приховати значки. Відлік 5 або 10 секунд починається заново після клацання рядка меню.",
        rehideFiveSeconds: "5 секунд",
        rehideTenSeconds: "10 секунд",
        toggleShortcutTitle: "Сполучення перемикання",
        toggleShortcutCaption: "Приховує або показує прихований розділ, не залишаючи клавіатуру.",
        shortcutUnavailable: "Не вдалося зареєструвати сполучення. Виберіть інше."
    )

    static let zhHans = MenuBarHidingStrings(
        title: "菜单栏图标",
        hubDescription: "将其他应用的菜单栏项目分为可见和隐藏两个区域。",
        enableCaption: "该模块会在菜单栏添加一个箭头。按住 Command 拖动图标越过箭头即可选择要保持可见的图标。点击箭头可暂时显示隐藏的图标。",
        visible: "可见",
        hidden: "隐藏",
        rehideDelayTitle: "重新隐藏",
        rehideInstant: "立即",
        emptySection: "此区域没有应用",
        dragHint: "按住 ⌘ 拖动图标越过箭头即可在可见和隐藏之间移动。",
        unavailable: "此构建无法安全隐藏其他应用的菜单栏项目。",
        activationFailed: "隐藏其他应用的菜单栏项目未能及时完成，因此没有隐藏任何内容。",
        readFailed: "辅助功能未返回任何菜单栏项目，因此没有隐藏任何内容。请允许辅助功能后重试。",
        separatorHint: "分隔可见项目与隐藏项目",
        rehideHint: "点击菜单栏外或按下 Escape 可重新隐藏图标。点击菜单栏时，5 秒或 10 秒的时限会重新开始。",
        rehideFiveSeconds: "5 秒",
        rehideTenSeconds: "10 秒",
        toggleShortcutTitle: "切换快捷键",
        toggleShortcutCaption: "无需离开键盘即可显示或隐藏隐藏区域。",
        shortcutUnavailable: "无法注册快捷键。请选择其他组合。"
    )

    static let zhTW = MenuBarHidingStrings(
        title: "選單列圖示",
        hubDescription: "將其他應用程式的選單列項目分為可見與隱藏兩個區域。",
        enableCaption: "此模組會在選單列加入一個箭頭。按住 Command 拖移圖示越過箭頭即可選擇要保持可見的圖示。點擊箭頭可暫時顯示隱藏的圖示。",
        visible: "可見",
        hidden: "隱藏",
        rehideDelayTitle: "重新隱藏",
        rehideInstant: "立即",
        emptySection: "此區域沒有應用程式",
        dragHint: "按住 ⌘ 拖移圖示越過箭頭即可在可見和隱藏之間移動。",
        unavailable: "此版本無法安全隱藏其他應用程式的選單列項目。",
        activationFailed: "隱藏其他應用程式的選單列項目未能及時完成，因此沒有隱藏任何內容。",
        readFailed: "輔助使用未傳回任何選單列項目，因此沒有隱藏任何內容。請允許輔助使用後再試一次。",
        separatorHint: "分隔可見項目與隱藏項目",
        rehideHint: "點擊選單列外或按下 Escape 可重新隱藏圖示。點擊選單列時，5 秒或 10 秒的時限會重新開始。",
        rehideFiveSeconds: "5 秒",
        rehideTenSeconds: "10 秒",
        toggleShortcutTitle: "切換快速鍵",
        toggleShortcutCaption: "不必離開鍵盤即可顯示或隱藏隱藏區域。",
        shortcutUnavailable: "無法註冊快速鍵。請選擇其他組合。"
    )

    static let zhHK = MenuBarHidingStrings(
        title: "選單列圖示",
        hubDescription: "將其他應用程式的選單列項目分為可見與隱藏兩個區域。",
        enableCaption: "此模組會在選單列加入一個箭頭。按住 Command 拖移圖示越過箭頭即可選擇要保持可見的圖示。點擊箭頭可暫時顯示隱藏的圖示。",
        visible: "可見",
        hidden: "隱藏",
        rehideDelayTitle: "重新隱藏",
        rehideInstant: "立即",
        emptySection: "此區域沒有應用程式",
        dragHint: "按住 ⌘ 拖移圖示越過箭頭即可在可見和隱藏之間移動。",
        unavailable: "此版本無法安全隱藏其他應用程式的選單列項目。",
        activationFailed: "隱藏其他應用程式的選單列項目未能及時完成，因此沒有隱藏任何內容。",
        readFailed: "輔助使用未傳回任何選單列項目，因此沒有隱藏任何內容。請允許輔助使用後再試一次。",
        separatorHint: "分隔可見項目與隱藏項目",
        rehideHint: "點擊選單列外或按下 Escape 可重新隱藏圖示。點擊選單列時，5 秒或 10 秒的時限會重新開始。",
        rehideFiveSeconds: "5 秒",
        rehideTenSeconds: "10 秒",
        toggleShortcutTitle: "切換快速鍵",
        toggleShortcutCaption: "不必離開鍵盤即可顯示或隱藏隱藏區域。",
        shortcutUnavailable: "無法註冊快速鍵。請選擇其他組合。"
    )
}
