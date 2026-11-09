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
        rehideHint: "Instant hides again when you click outside the menu bar or press Escape. The other choices hide after the selected delay."
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
        rehideHint: "Instantâneo recolhe ao clicar fora da menu bar ou pressionar Escape. As outras opções recolhem após o prazo selecionado."
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
        rehideHint: "Anında seçeneği, menü çubuğunun dışına tıklayınca veya Escape tuşuna basınca gizler. Diğer seçenekler seçilen süreden sonra gizler."
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
        rehideHint: "«Мгновенно» скрывает значки после щелчка за пределами строки меню или нажатия Escape. Другие варианты скрывают их по истечении выбранного времени."
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
        rehideHint: "Al instante vuelve a ocultar los iconos al hacer clic fuera de la barra de menús o pulsar Escape. Las otras opciones esperan el tiempo seleccionado."
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
        rehideHint: "Možnosť Okamžite znova skryje ikony po kliknutí mimo panela ponúk alebo stlačení Escape. Ostatné možnosti ich skryjú po zvolenom čase."
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
        rehideHint: "Sofort blendet die Symbole wieder aus, wenn du außerhalb der Menüleiste klickst oder Escape drückst. Die anderen Optionen warten die gewählte Zeit."
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
        rehideHint: "Instantanément masque les icônes lorsque vous cliquez hors de la barre des menus ou appuyez sur Échap. Les autres options attendent le délai choisi."
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
        rehideHint: "Subito nasconde di nuovo le icone quando fai clic fuori dalla barra dei menu o premi Esc. Le altre opzioni attendono il tempo selezionato."
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
        rehideHint: "「すぐに」はメニューバーの外をクリックするか Esc キーを押すとアイコンを再び隠します。ほかの選択肢では指定した時間後に隠します。"
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
        rehideHint: "즉시는 메뉴 막대 바깥을 클릭하거나 Esc 키를 누르면 아이콘을 다시 숨깁니다. 다른 옵션은 선택한 시간이 지나면 숨깁니다."
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
        rehideHint: "«Миттєво» знову приховує значки після клацання за межами рядка меню або натискання Escape. Інші варіанти чекають вибраний час."
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
        rehideHint: "选择“立即”时，点击菜单栏外或按下 Escape 会重新隐藏图标。其他选项会在所选时间后隐藏。"
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
        rehideHint: "選擇「立即」時，點擊選單列外或按下 Escape 會重新隱藏圖示。其他選項會在所選時間後隱藏。"
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
        rehideHint: "選擇「立即」時，點擊選單列外或按下 Escape 會重新隱藏圖示。其他選項會在所選時間後隱藏。"
    )
}
