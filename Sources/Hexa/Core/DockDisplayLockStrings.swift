// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Strings for keeping the Dock on one display. Same contract as the other
/// FeatureStrings structs: memberwise init with labeled arguments in
/// declaration order, one static per language, all in this file.
struct DockDisplayLockStrings {
    let title: String
    let hubDescription: String
    let enableCaption: String
    let displayPicker: String
    let mainDisplay: String
    let builtInDisplay: String
    let disconnectedDisplay: String
    let fallbackNote: String
    let dockLocationFormat: String
    let moveButton: String
    let returnsToggle: String
    let returnsCaption: String
    let singleDisplay: String
    let spacesOff: String
    let needsAccessibility: String
    let runningFormat: String
    let dockUnknown: String
}

extension FeatureStrings {
    static func dockDisplayLock(_ language: AppLanguage) -> DockDisplayLockStrings {
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

extension DockDisplayLockStrings {
    static let enUS = DockDisplayLockStrings(
        title: "Dock on one display",
        hubDescription: "Stops the Dock from moving to another display when the pointer reaches that display's edge.",
        enableCaption: "The last few points of another display’s Dock edge stay out of reach, so the push macOS reads as a request to move the Dock never arrives, for drags as well as moves. Everywhere else the pointer moves freely. Hold Option to reach that edge and move the Dock on purpose.",
        displayPicker: "Display",
        mainDisplay: "Main display",
        builtInDisplay: "Built-in display",
        disconnectedDisplay: "Chosen display (not connected)",
        fallbackNote: "While the chosen display is not connected, the Dock stays on the main display.",
        dockLocationFormat: "The Dock is on %@.",
        moveButton: "Move the Dock there",
        returnsToggle: "Bring the Dock back after sleep and display changes",
        returnsCaption: "macOS puts the Dock on the main display after sleep. With this on, the pointer briefly presses on the chosen display's Dock edge to call it back, only while the Mac is unlocked.",
        singleDisplay: "Only one display is connected, so the Dock has nowhere else to go.",
        spacesOff: "\u{201C}Displays have separate Spaces\u{201D} is off, so macOS keeps the Dock on the main display by itself. Turn that option on to choose another display; macOS asks for a logout.",
        needsAccessibility: "Accessibility is needed to read where the Dock is and to nudge the pointer before it reaches the edge.",
        runningFormat: "Watching %d displays.",
        dockUnknown: "The Dock could not be located right now."
    )

    static let ptBR = DockDisplayLockStrings(
        title: "Dock em uma tela",
        hubDescription: "Impede que o Dock vá para outra tela quando o ponteiro chega à borda dessa tela.",
        enableCaption: "Os últimos pontos da borda do Dock de outra tela ficam fora de alcance, para a pressão que o macOS entende como pedido para mover o Dock nunca chegar, tanto ao arrastar quanto ao mover. No resto da tela o ponteiro anda livremente. Segure Option para alcançar essa borda e mover o Dock de propósito.",
        displayPicker: "Tela",
        mainDisplay: "Tela principal",
        builtInDisplay: "Tela integrada",
        disconnectedDisplay: "Tela escolhida (não conectada)",
        fallbackNote: "Enquanto a tela escolhida não estiver conectada, o Dock fica na tela principal.",
        dockLocationFormat: "O Dock está em %@.",
        moveButton: "Mover o Dock para lá",
        returnsToggle: "Trazer o Dock de volta após repouso e mudanças de tela",
        returnsCaption: "O macOS coloca o Dock na tela principal após o repouso. Com isto ligado, o ponteiro pressiona por um instante a borda do Dock da tela escolhida para trazê-lo de volta, só com o Mac desbloqueado.",
        singleDisplay: "Só uma tela está conectada, então o Dock não tem para onde ir.",
        spacesOff: "\u{201C}As telas têm Espaços separados\u{201D} está desligado, então o macOS mantém o Dock na tela principal por conta própria. Ligue essa opção para escolher outra tela; o macOS pede para sair da conta.",
        needsAccessibility: "A Acessibilidade é necessária para ler onde o Dock está e recuar o ponteiro antes que ele alcance a borda.",
        runningFormat: "Vigiando %d telas.",
        dockUnknown: "Não foi possível localizar o Dock agora."
    )

    static let tr = DockDisplayLockStrings(
        title: "Dock’u tek ekranda tut",
        hubDescription: "İşaretçi başka bir ekranın kenarına ulaştığında Dock’un o ekrana geçmesini engeller.",
        enableCaption: "Başka bir ekranın Dock kenarının son birkaç noktası erişilemez kalır; böylece macOS’in Dock’u taşıma isteği olarak okuduğu bastırma hiç ulaşmaz, sürüklerken de taşırken de. Ekranın geri kalanında işaretçi serbestçe dolaşır. O kenara ulaşıp Dock’u bilerek taşımak için Option tuşuna basılı tutun.",
        displayPicker: "Ekran",
        mainDisplay: "Ana ekran",
        builtInDisplay: "Dahili ekran",
        disconnectedDisplay: "Seçilen ekran (bağlı değil)",
        fallbackNote: "Seçilen ekran bağlı değilken Dock ana ekranda kalır.",
        dockLocationFormat: "Dock şu ekranda: %@.",
        moveButton: "Dock’u oraya taşı",
        returnsToggle: "Uyku ve ekran değişikliklerinden sonra Dock’u geri getir",
        returnsCaption: "macOS uykudan sonra Dock’u ana ekrana koyar. Bu açıkken işaretçi, Dock’u geri çağırmak için seçilen ekranın Dock kenarına kısa bir an bastırır; yalnızca Mac’in kilidi açıkken.",
        singleDisplay: "Yalnızca bir ekran bağlı, bu yüzden Dock’un gidebileceği başka bir yer yok.",
        spacesOff: "“Ekranların ayrı Spaces alanları var” kapalı, bu yüzden macOS Dock’u kendiliğinden ana ekranda tutar. Başka bir ekran seçmek için bu seçeneği açın; macOS oturumu kapatmanızı ister.",
        needsAccessibility: "Dock’un nerede olduğunu okumak ve işaretçiyi kenara ulaşmadan geri itmek için Erişilebilirlik gerekir.",
        runningFormat: "%d ekran izleniyor.",
        dockUnknown: "Dock şu anda bulunamadı."
    )

    static let ru = DockDisplayLockStrings(
        title: "Dock на одном дисплее",
        hubDescription: "Не даёт Dock переехать на другой дисплей, когда указатель доходит до его края.",
        enableCaption: "Последние точки края Dock на другом дисплее остаются недоступными, чтобы упор, который macOS считает просьбой перенести Dock, не доходил до него: и при перетаскивании, и при обычном движении. На остальной части экрана указатель движется свободно. Удерживайте Option, чтобы добраться до этого края и перенести Dock намеренно.",
        displayPicker: "Дисплей",
        mainDisplay: "Основной дисплей",
        builtInDisplay: "Встроенный дисплей",
        disconnectedDisplay: "Выбранный дисплей (не подключён)",
        fallbackNote: "Пока выбранный дисплей не подключён, Dock остаётся на основном дисплее.",
        dockLocationFormat: "Dock сейчас на дисплее %@.",
        moveButton: "Перенести Dock туда",
        returnsToggle: "Возвращать Dock после сна и смены дисплеев",
        returnsCaption: "После сна macOS ставит Dock на основной дисплей. Когда это включено, указатель на мгновение упирается в край Dock на выбранном дисплее, чтобы вернуть его, и только когда Mac разблокирован.",
        singleDisplay: "Подключён только один дисплей, так что Dock некуда переезжать.",
        spacesOff: "Параметр «Мониторы с отдельными пространствами Spaces» выключен, поэтому macOS сам держит Dock на основном дисплее. Включите его, чтобы выбрать другой дисплей; macOS попросит выйти из системы.",
        needsAccessibility: "Универсальный доступ нужен, чтобы читать положение Dock и отталкивать указатель до края.",
        runningFormat: "Отслеживается дисплеев: %d.",
        dockUnknown: "Не удалось определить, где сейчас Dock."
    )

    static let es = DockDisplayLockStrings(
        title: "Dock en una pantalla",
        hubDescription: "Evita que el Dock pase a otra pantalla cuando el puntero llega al borde de esa pantalla.",
        enableCaption: "Los últimos puntos del borde del Dock de otra pantalla quedan fuera de alcance, para que la presión que macOS entiende como petición para mover el Dock nunca llegue, al arrastrar y al mover. En el resto de la pantalla el puntero se mueve con libertad. Mantén Option para alcanzar ese borde y mover el Dock a propósito.",
        displayPicker: "Pantalla",
        mainDisplay: "Pantalla principal",
        builtInDisplay: "Pantalla integrada",
        disconnectedDisplay: "Pantalla elegida (no conectada)",
        fallbackNote: "Mientras la pantalla elegida no esté conectada, el Dock se queda en la pantalla principal.",
        dockLocationFormat: "El Dock está en %@.",
        moveButton: "Mover el Dock allí",
        returnsToggle: "Devolver el Dock tras el reposo y los cambios de pantalla",
        returnsCaption: "macOS pone el Dock en la pantalla principal tras el reposo. Con esto activado, el puntero presiona un instante el borde del Dock de la pantalla elegida para traerlo de vuelta, solo con el Mac desbloqueado.",
        singleDisplay: "Solo hay una pantalla conectada, así que el Dock no tiene adónde ir.",
        spacesOff: "«Las pantallas tienen espacios independientes» está desactivado, así que macOS mantiene el Dock en la pantalla principal por su cuenta. Actívalo para elegir otra pantalla; macOS pedirá cerrar sesión.",
        needsAccessibility: "Se necesita Accesibilidad para leer dónde está el Dock y retirar el puntero antes de que llegue al borde.",
        runningFormat: "Vigilando %d pantallas.",
        dockUnknown: "No se pudo localizar el Dock ahora."
    )

    static let sk = DockDisplayLockStrings(
        title: "Dock na jednom displeji",
        hubDescription: "Zabráni, aby sa Dock presunul na iný displej, keď ukazovateľ dosiahne jeho okraj.",
        enableCaption: "Posledné body okraja Docku iného displeja zostávajú nedostupné, aby sa zatlačenie, ktoré macOS chápe ako žiadosť o presun Docku, nikdy nedostalo k nemu, pri ťahaní aj pri pohybe. Na zvyšku obrazovky sa ukazovateľ pohybuje voľne. Podržte Option, ak chcete dosiahnuť ten okraj a presunúť Dock zámerne.",
        displayPicker: "Displej",
        mainDisplay: "Hlavný displej",
        builtInDisplay: "Vstavaný displej",
        disconnectedDisplay: "Vybraný displej (nepripojený)",
        fallbackNote: "Kým vybraný displej nie je pripojený, Dock zostane na hlavnom displeji.",
        dockLocationFormat: "Dock je na displeji %@.",
        moveButton: "Presunúť Dock tam",
        returnsToggle: "Vrátiť Dock po spánku a zmene displejov",
        returnsCaption: "Po spánku macOS presunie Dock na hlavný displej. Keď je toto zapnuté, ukazovateľ na okamih zatlačí na okraj Docku vybraného displeja, aby ho vrátil, iba keď je Mac odomknutý.",
        singleDisplay: "Pripojený je iba jeden displej, takže Dock sa nemá kam presunúť.",
        spacesOff: "Voľba „Displeje majú samostatné plochy Spaces“ je vypnutá, takže macOS drží Dock na hlavnom displeji sám. Zapnite ju, ak chcete vybrať iný displej; macOS požiada o odhlásenie.",
        needsAccessibility: "Prístupnosť je potrebná na čítanie polohy Docku a na odstrčenie ukazovateľa pred okrajom.",
        runningFormat: "Sleduje sa displejov: %d.",
        dockUnknown: "Dock sa teraz nepodarilo nájsť."
    )

    static let de = DockDisplayLockStrings(
        title: "Dock auf einem Display",
        hubDescription: "Verhindert, dass das Dock auf ein anderes Display wechselt, wenn der Zeiger dessen Rand erreicht.",
        enableCaption: "Die letzten Punkte des Dock-Rands eines anderen Displays bleiben unerreichbar, damit das Drücken, das macOS als Wunsch liest, das Dock zu verschieben, dort nie ankommt, beim Ziehen wie beim Bewegen. Auf dem Rest des Displays bewegt sich der Zeiger frei. Mit Option erreichst du diesen Rand und verschiebst das Dock absichtlich.",
        displayPicker: "Display",
        mainDisplay: "Hauptdisplay",
        builtInDisplay: "Integriertes Display",
        disconnectedDisplay: "Gewähltes Display (nicht verbunden)",
        fallbackNote: "Solange das gewählte Display nicht verbunden ist, bleibt das Dock auf dem Hauptdisplay.",
        dockLocationFormat: "Das Dock ist auf %@.",
        moveButton: "Dock dorthin bewegen",
        returnsToggle: "Dock nach dem Ruhezustand und Display-Änderungen zurückholen",
        returnsCaption: "Nach dem Ruhezustand setzt macOS das Dock auf das Hauptdisplay. Ist dies an, drückt der Zeiger kurz gegen den Dock-Rand des gewählten Displays, um es zurückzuholen, nur während der Mac entsperrt ist.",
        singleDisplay: "Es ist nur ein Display verbunden, das Dock kann also nirgendwo anders hin.",
        spacesOff: "„Monitore verwenden verschiedene Spaces“ ist aus, daher hält macOS das Dock selbst auf dem Hauptdisplay. Schalte die Option ein, um ein anderes Display zu wählen; macOS verlangt eine Abmeldung.",
        needsAccessibility: "Bedienungshilfen werden gebraucht, um die Position des Docks zu lesen und den Zeiger vor dem Rand zurückzuschieben.",
        runningFormat: "%d Displays werden überwacht.",
        dockUnknown: "Das Dock war gerade nicht zu finden."
    )

    static let fr = DockDisplayLockStrings(
        title: "Dock sur un seul écran",
        hubDescription: "Empêche le Dock de passer sur un autre écran quand le pointeur atteint le bord de cet écran.",
        enableCaption: "Les derniers points du bord du Dock d’un autre écran restent hors d’atteinte, pour que la pression que macOS interprète comme une demande de déplacer le Dock n’arrive jamais, en glissant comme en déplaçant. Ailleurs, le pointeur se déplace librement. Maintenez Option pour atteindre ce bord et déplacer le Dock volontairement.",
        displayPicker: "Écran",
        mainDisplay: "Écran principal",
        builtInDisplay: "Écran intégré",
        disconnectedDisplay: "Écran choisi (non connecté)",
        fallbackNote: "Tant que l’écran choisi n’est pas connecté, le Dock reste sur l’écran principal.",
        dockLocationFormat: "Le Dock est sur %@.",
        moveButton: "Y déplacer le Dock",
        returnsToggle: "Ramener le Dock après la suspension et les changements d’écran",
        returnsCaption: "Après la suspension, macOS place le Dock sur l’écran principal. Avec cette option, le pointeur appuie un instant sur le bord du Dock de l’écran choisi pour le rappeler, seulement quand le Mac est déverrouillé.",
        singleDisplay: "Un seul écran est connecté, le Dock n’a donc nulle part où aller.",
        spacesOff: "«\u{00A0}Les écrans disposent d’espaces distincts\u{00A0}» est désactivé, donc macOS garde le Dock sur l’écran principal de lui-même. Activez-le pour choisir un autre écran ; macOS demande une déconnexion.",
        needsAccessibility: "L’accessibilité est nécessaire pour lire la position du Dock et repousser le pointeur avant le bord.",
        runningFormat: "%d écrans surveillés.",
        dockUnknown: "Le Dock est introuvable pour le moment."
    )

    static let it = DockDisplayLockStrings(
        title: "Dock su un solo schermo",
        hubDescription: "Impedisce al Dock di passare a un altro schermo quando il puntatore raggiunge il bordo di quello schermo.",
        enableCaption: "Gli ultimi punti del bordo del Dock di un altro schermo restano fuori portata, così la pressione che macOS legge come richiesta di spostare il Dock non arriva mai, sia trascinando sia muovendo. Nel resto dello schermo il puntatore si muove liberamente. Tieni premuto Option per raggiungere quel bordo e spostare il Dock di proposito.",
        displayPicker: "Schermo",
        mainDisplay: "Schermo principale",
        builtInDisplay: "Schermo integrato",
        disconnectedDisplay: "Schermo scelto (non collegato)",
        fallbackNote: "Finché lo schermo scelto non è collegato, il Dock resta sullo schermo principale.",
        dockLocationFormat: "Il Dock è su %@.",
        moveButton: "Sposta lì il Dock",
        returnsToggle: "Riporta il Dock dopo lo stop e i cambi di schermo",
        returnsCaption: "Dopo lo stop macOS mette il Dock sullo schermo principale. Con questa opzione il puntatore preme per un istante sul bordo del Dock dello schermo scelto per richiamarlo, solo con il Mac sbloccato.",
        singleDisplay: "È collegato un solo schermo, quindi il Dock non ha altro posto dove andare.",
        spacesOff: "«Gli schermi hanno spazi separati» è disattivato, quindi macOS tiene il Dock sullo schermo principale da solo. Attivalo per scegliere un altro schermo; macOS chiede di uscire dal sistema.",
        needsAccessibility: "Serve Accessibilità per leggere dove si trova il Dock e respingere il puntatore prima del bordo.",
        runningFormat: "%d schermi sotto controllo.",
        dockUnknown: "Non è stato possibile trovare il Dock ora."
    )

    static let ja = DockDisplayLockStrings(
        title: "Dock を 1 台のディスプレイに固定",
        hubDescription: "ポインタがほかのディスプレイの端に達したときに、Dock がそのディスプレイへ移らないようにします。",
        enableCaption: "ほかのディスプレイの Dock の端の数ポイントには届かなくなり、macOS が Dock を移す合図と受け取る押し込みがそこに届きません。移動中もドラッグ中も同じです。画面のほかの場所ではポインタは自由に動きます。その端に届いて意図的に Dock を移すには Option を押したままにします。",
        displayPicker: "ディスプレイ",
        mainDisplay: "メインディスプレイ",
        builtInDisplay: "内蔵ディスプレイ",
        disconnectedDisplay: "選択したディスプレイ（未接続）",
        fallbackNote: "選択したディスプレイが接続されていない間、Dock はメインディスプレイにとどまります。",
        dockLocationFormat: "Dock は %@ にあります。",
        moveButton: "Dock をそこへ移動",
        returnsToggle: "スリープやディスプレイの変更後に Dock を戻す",
        returnsCaption: "スリープ後、macOS は Dock をメインディスプレイに置きます。オンにすると、Mac のロックが解除されているときだけ、ポインタが選択したディスプレイの Dock の端を一瞬押して Dock を呼び戻します。",
        singleDisplay: "接続されているディスプレイは 1 台だけなので、Dock の移動先はありません。",
        spacesOff: "「ディスプレイごとに個別の操作スペース」がオフなので、macOS が Dock をメインディスプレイに留めています。別のディスプレイを選ぶにはこのオプションをオンにしてください。macOS はログアウトを求めます。",
        needsAccessibility: "Dock の位置を読み取り、ポインタが端に届く前に押し戻すにはアクセシビリティが必要です。",
        runningFormat: "%d 台のディスプレイを監視中。",
        dockUnknown: "現在 Dock の位置を特定できませんでした。"
    )

    static let ko = DockDisplayLockStrings(
        title: "Dock을 한 디스플레이에 고정",
        hubDescription: "포인터가 다른 디스플레이의 가장자리에 닿을 때 Dock이 그 디스플레이로 옮겨 가지 않게 합니다.",
        enableCaption: "다른 디스플레이의 Dock 가장자리 마지막 몇 포인트에는 닿지 않으므로, macOS가 Dock 이동 요청으로 읽는 미는 동작이 거기까지 전달되지 않습니다. 이동할 때와 드래그할 때 모두 같습니다. 화면의 나머지에서는 포인터가 자유롭게 움직입니다. 그 가장자리에 닿아 일부러 Dock을 옮기려면 Option을 누른 채로 움직이세요.",
        displayPicker: "디스플레이",
        mainDisplay: "주 디스플레이",
        builtInDisplay: "내장 디스플레이",
        disconnectedDisplay: "선택한 디스플레이(연결되지 않음)",
        fallbackNote: "선택한 디스플레이가 연결되지 않은 동안에는 Dock이 주 디스플레이에 머뭅니다.",
        dockLocationFormat: "Dock이 %@에 있습니다.",
        moveButton: "Dock을 그곳으로 이동",
        returnsToggle: "잠자기 및 디스플레이 변경 후 Dock 되돌리기",
        returnsCaption: "잠자기 후 macOS는 Dock을 주 디스플레이에 둡니다. 이 옵션을 켜면 Mac 잠금이 해제된 동안에만 포인터가 선택한 디스플레이의 Dock 가장자리를 잠깐 밀어 Dock을 다시 불러옵니다.",
        singleDisplay: "연결된 디스플레이가 하나뿐이라 Dock이 옮겨 갈 곳이 없습니다.",
        spacesOff: "‘디스플레이마다 개별 Spaces 사용’이 꺼져 있어 macOS가 Dock을 주 디스플레이에 스스로 붙잡아 둡니다. 다른 디스플레이를 선택하려면 이 옵션을 켜세요. macOS가 로그아웃을 요구합니다.",
        needsAccessibility: "Dock의 위치를 읽고 포인터가 가장자리에 닿기 전에 밀어내려면 손쉬운 사용 권한이 필요합니다.",
        runningFormat: "디스플레이 %d개를 감시 중.",
        dockUnknown: "지금은 Dock의 위치를 찾을 수 없습니다."
    )

    static let uk = DockDisplayLockStrings(
        title: "Dock на одному дисплеї",
        hubDescription: "Не дає Dock переїхати на інший дисплей, коли вказівник доходить до його краю.",
        enableCaption: "Останні точки краю Dock на іншому дисплеї залишаються недосяжними, щоб натиск, який macOS вважає проханням перенести Dock, ніколи не доходив до нього: і під час перетягування, і під час руху. На решті екрана вказівник рухається вільно. Утримуйте Option, щоб дістатися до цього краю й перенести Dock навмисно.",
        displayPicker: "Дисплей",
        mainDisplay: "Основний дисплей",
        builtInDisplay: "Вбудований дисплей",
        disconnectedDisplay: "Вибраний дисплей (не підключено)",
        fallbackNote: "Поки вибраний дисплей не підключено, Dock залишається на основному дисплеї.",
        dockLocationFormat: "Dock зараз на дисплеї %@.",
        moveButton: "Перенести Dock туди",
        returnsToggle: "Повертати Dock після сну та зміни дисплеїв",
        returnsCaption: "Після сну macOS ставить Dock на основний дисплей. Коли це ввімкнено, вказівник на мить упирається в край Dock на вибраному дисплеї, щоб повернути його, лише коли Mac розблоковано.",
        singleDisplay: "Підключено лише один дисплей, тож Dock нікуди переїжджати.",
        spacesOff: "Параметр «Дисплеї мають окремі простори Spaces» вимкнено, тому macOS сам утримує Dock на основному дисплеї. Увімкніть його, щоб вибрати інший дисплей; macOS попросить вийти з облікового запису.",
        needsAccessibility: "Універсальний доступ потрібен, щоб читати положення Dock і відштовхувати вказівник до краю.",
        runningFormat: "Відстежується дисплеїв: %d.",
        dockUnknown: "Не вдалося визначити, де зараз Dock."
    )

    static let zhHans = DockDisplayLockStrings(
        title: "将程序坞保留在一个显示器上",
        hubDescription: "指针到达其他显示器的边缘时，阻止程序坞移到那个显示器。",
        enableCaption: "其他显示器程序坞边缘的最后几个点无法到达，macOS 当作移动程序坞请求的那个抵住动作因此不会传过去；移动和拖移时都一样。屏幕其余部分指针可自由移动。按住 Option 可到达该边缘并有意移动程序坞。",
        displayPicker: "显示器",
        mainDisplay: "主显示器",
        builtInDisplay: "内建显示器",
        disconnectedDisplay: "所选显示器（未连接）",
        fallbackNote: "所选显示器未连接期间，程序坞会留在主显示器上。",
        dockLocationFormat: "程序坞位于 %@。",
        moveButton: "将程序坞移到那里",
        returnsToggle: "睡眠和显示器变化后将程序坞移回",
        returnsCaption: "睡眠后 macOS 会把程序坞放到主显示器上。打开此项后，仅在 Mac 已解锁时，指针会短暂抵住所选显示器的程序坞边缘，把程序坞叫回来。",
        singleDisplay: "只连接了一个显示器，程序坞没有其他地方可去。",
        spacesOff: "“显示器具有单独的空间”已关闭，因此 macOS 会自行把程序坞留在主显示器上。打开该选项才能选择其他显示器；macOS 会要求注销。",
        needsAccessibility: "需要辅助功能权限来读取程序坞的位置，并在指针到达边缘前将其推回。",
        runningFormat: "正在监视 %d 个显示器。",
        dockUnknown: "目前无法定位程序坞。"
    )

    static let zhTW = DockDisplayLockStrings(
        title: "將 Dock 保留在一個顯示器上",
        hubDescription: "指標到達其他顯示器的邊緣時，避免 Dock 移到那個顯示器。",
        enableCaption: "其他顯示器 Dock 邊緣的最後幾個點無法到達，macOS 當作移動 Dock 要求的抵住動作因此不會傳過去；拖移和移動時都一樣。螢幕其餘部分指標可自由移動。按住 Option 可到達該邊緣並刻意移動 Dock。",
        displayPicker: "顯示器",
        mainDisplay: "主顯示器",
        builtInDisplay: "內建顯示器",
        disconnectedDisplay: "所選顯示器（未連接）",
        fallbackNote: "所選顯示器未連接期間，Dock 會留在主顯示器上。",
        dockLocationFormat: "Dock 位於 %@。",
        moveButton: "將 Dock 移到那裡",
        returnsToggle: "睡眠和顯示器變化後將 Dock 移回",
        returnsCaption: "睡眠後 macOS 會把 Dock 放到主顯示器上。開啟此項後，僅在 Mac 已解鎖時，指標會短暫抵住所選顯示器的 Dock 邊緣，把 Dock 叫回來。",
        singleDisplay: "只連接了一個顯示器，Dock 沒有其他地方可去。",
        spacesOff: "「顯示器具有個別的空間」已關閉，因此 macOS 會自行把 Dock 留在主顯示器上。開啟該選項才能選擇其他顯示器；macOS 會要求登出。",
        needsAccessibility: "需要輔助使用權限來讀取 Dock 的位置，並在指標到達邊緣前將其推回。",
        runningFormat: "正在監視 %d 個顯示器。",
        dockUnknown: "目前無法定位 Dock。"
    )

    static let zhHK = DockDisplayLockStrings(
        title: "將 Dock 保留在一個顯示器上",
        hubDescription: "指標到達其他顯示器的邊緣時，避免 Dock 移到那個顯示器。",
        enableCaption: "其他顯示器 Dock 邊緣的最後幾個點無法到達，macOS 當作移動 Dock 要求的抵住動作因此不會傳過去；拖移和移動時都一樣。螢幕其餘部分指標可自由移動。按住 Option 可到達該邊緣並刻意移動 Dock。",
        displayPicker: "顯示器",
        mainDisplay: "主顯示器",
        builtInDisplay: "內建顯示器",
        disconnectedDisplay: "所選顯示器（未連接）",
        fallbackNote: "所選顯示器未連接期間，Dock 會留在主顯示器上。",
        dockLocationFormat: "Dock 位於 %@。",
        moveButton: "將 Dock 移到那裡",
        returnsToggle: "睡眠和顯示器變化後將 Dock 移回",
        returnsCaption: "睡眠後 macOS 會把 Dock 放到主顯示器上。開啟此項後，僅在 Mac 已解鎖時，指標會短暫抵住所選顯示器的 Dock 邊緣，把 Dock 叫回來。",
        singleDisplay: "只連接了一個顯示器，Dock 沒有其他地方可去。",
        spacesOff: "「顯示器具有個別的空間」已關閉，因此 macOS 會自行把 Dock 留在主顯示器上。開啟該選項才能選擇其他顯示器；macOS 會要求登出。",
        needsAccessibility: "需要輔助使用權限來讀取 Dock 的位置，並在指標到達邊緣前將其推回。",
        runningFormat: "正在監視 %d 個顯示器。",
        dockUnknown: "目前無法定位 Dock。"
    )
}
