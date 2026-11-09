// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// Plain-language copy for the General page: one short line per control and
/// one per panel section, so the page explains itself without paragraphs.
struct GeneralSettingsStrings {
    let pageDescription: String
    let advancedPageDescription: String
    let aboutPageDescription: String
    let appearanceCaption: String
    let launchAtLoginCaption: String
    let panelIntro: String
    let panelReorderHint: String
    let menuBarIconTitle: String
    let iconMissingTitle: String
    let iconMissingCaption: String
    let sectionKeepAwake: String
    let sectionDisplays: String
    let sectionMixer: String
    let sectionSystem: String
    let sectionNetwork: String
    let sectionDisks: String
    let sectionPower: String
    let sectionFanControl: String
    let sectionUtilities: String
    let sectionControls: String
    let sectionToggles: String
}

extension FeatureStrings {
    static func generalSettings(_ language: AppLanguage) -> GeneralSettingsStrings {
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

extension GeneralSettingsStrings {
    static func startupLabel(_ language: AppLanguage) -> String {
        switch language {
        case .ptBR: return "Inicialização"
        case .es: return "Inicio"
        case .de: return "Start"
        case .fr: return "Démarrage"
        case .it: return "Avvio"
        case .ru: return "Запуск"
        case .tr: return "Başlangıç"
        case .sk: return "Spustenie"
        case .uk: return "Запуск"
        case .ja: return "起動"
        case .ko: return "시작"
        case .zhHans: return "启动"
        case .zhTW, .zhHK: return "啟動"
        case .enUS: return "Startup"
        }
    }

    var startupLabel: String {
        Self.startupLabel(L10n.shared.language)
    }
}

extension GeneralSettingsStrings {
    static let uk = GeneralSettingsStrings(
        pageDescription: "Запуск і вигляд Hexa.",
        advancedPageDescription: "Резервне копіювання та відновлення налаштувань.",
        aboutPageDescription: "Версія, вихідний код і підтримка.",
        appearanceCaption: "Стосується лише вікон і панелей Hexa, а не всього Mac.",
        launchAtLoginCaption: "Автоматично відкривається щоразу після запуску Mac.",
        panelIntro: "Натисніть значок Hexa на смузі меню, щоб відкрити панель. Вкладки розташовані в такому порядку.",
        panelReorderHint: "Перетягуйте, щоб змінити порядок. Вимкніть те, що вам не потрібно.",
        menuBarIconTitle: "Значок на смузі меню",
        iconMissingTitle: "Не можете знайти значок?",
        iconMissingCaption: "Переповнена смуга меню може його приховати, особливо на Mac із вирізом.",
        sectionKeepAwake: "Не дає Mac заснути стільки, скільки потрібно.",
        sectionDisplays: "Яскравість екранів.",
        sectionMixer: "Гучність кожної програми на окремому повзунку.",
        sectionSystem: "Процесор, графіка й пам’ять з першого погляду.",
        sectionNetwork: "Швидкість інтернету та програми, що ним користуються.",
        sectionDisks: "Вільне місце й активність дисків.",
        sectionPower: "Акумулятор, заряджання та споживання енергії.",
        sectionFanControl: "Швидкість вентиляторів і власна крива їхньої роботи.",
        sectionUtilities: "Знімки екрана, очищення, оновлення та інші інструменти.",
        sectionControls: "Перемикачі функцій миші, клавіатури й вікон.",
        sectionToggles: "Дії одним натисканням, як-от темний режим і вимкнення мікрофона."
    )

    static let enUS = GeneralSettingsStrings(
        pageDescription: "Startup and Hexa appearance.",
        advancedPageDescription: "Settings backup and restore.",
        aboutPageDescription: "Version, source code and support.",
        appearanceCaption: "Configuration applied exclusively to Hexa interfaces and windows.",
        launchAtLoginCaption: "Launch automatically during system startup.",
        panelIntro: "Section order and visibility in the menu bar panel.",
        panelReorderHint: "Drag to reorder sections or disable unneeded components.",
        menuBarIconTitle: "Menu bar icon",
        iconMissingTitle: "Item not visible in menu bar",
        iconMissingCaption: "Limited menu bar space in macOS may hide items on compact displays or screens with a notch.",
        sectionKeepAwake: "Prevent system sleep and display timeout on demand.",
        sectionDisplays: "Integrated display brightness controls.",
        sectionMixer: "Independent volume management per application.",
        sectionSystem: "Processing, graphics, and memory telemetry.",
        sectionNetwork: "Real-time transfer rates and per-app traffic.",
        sectionDisks: "Disk capacity and read/write activity.",
        sectionPower: "Battery charge state, health, and power consumption.",
        sectionFanControl: "Fan RPM monitoring and custom thermal curves.",
        sectionUtilities: "Screen capture, keyboard cleaning lockout, and maintenance.",
        sectionControls: "Quick toggles for window and input features.",
        sectionToggles: "Direct toggle actions and microphone muting."
    )

    static let ptBR = GeneralSettingsStrings(
        pageDescription: "Inicialização e aparência do Hexa.",
        advancedPageDescription: "Backup e restauração dos ajustes.",
        aboutPageDescription: "Versão, código e apoio.",
        appearanceCaption: "Configuração aplicada exclusivamente às janelas e interfaces do Hexa.",
        launchAtLoginCaption: "Iniciar automaticamente na inicialização do sistema operacional.",
        panelIntro: "Ordem e visibilidade das seções apresentadas no painel da barra de menus.",
        panelReorderHint: "Reordene arrastando os elementos ou desative seções conforme sua preferência.",
        menuBarIconTitle: "Ícone da barra de menus",
        iconMissingTitle: "Item não visível na barra de menus",
        iconMissingCaption: "O espaço restrito na barra de menus do macOS pode ocultar itens em telas compactas ou com notch.",
        sectionKeepAwake: "Prevenção de suspensão e bloqueio de tela sob demanda.",
        sectionDisplays: "Controle integrado de brilho dos monitores conectados.",
        sectionMixer: "Controle independente de volume por aplicativo.",
        sectionSystem: "Telemetria de processamento, gráficos e memória.",
        sectionNetwork: "Taxa de transferência e tráfego por app.",
        sectionDisks: "Utilização de espaço e atividade de leitura e escrita em disco.",
        sectionPower: "Status de carga, integridade da bateria e consumo elétrico.",
        sectionFanControl: "Monitoramento de rotação das ventoinhas e curva térmica personalizada.",
        sectionUtilities: "Ferramentas de captura, higienização de teclado e manutenção.",
        sectionControls: "Comandos rápidos de janelas e dispositivos de entrada.",
        sectionToggles: "Ações diretas de alternância de estado e silenciamento."
    )

    static let tr = GeneralSettingsStrings(
        pageDescription: "Başlangıç ve Hexa görünümü.",
        advancedPageDescription: "Ayarların yedeklenmesi ve geri yüklenmesi.",
        aboutPageDescription: "Sürüm, kaynak kodu ve destek.",
        appearanceCaption: "Yalnızca Hexa’in kendi pencereleri ve panelleri için geçerlidir, tüm Mac için değil.",
        launchAtLoginCaption: "Mac’i her açtığınızda kendiliğinden açılır.",
        panelIntro: "Paneli açmak için menü çubuğundaki Hexa simgesine tıklayın. Sekmeler bu sırayla görünür.",
        panelReorderHint: "Sıralamak için sürükleyin. İhtiyaç duymadıklarınızı kapatın.",
        menuBarIconTitle: "Menü çubuğu simgesi",
        iconMissingTitle: "Simgeyi bulamıyor musunuz?",
        iconMissingCaption: "Dolu bir menü çubuğu simgeyi gizleyebilir; özellikle çentikli Mac’lerde.",
        sectionKeepAwake: "Mac’i istediğiniz süre boyunca uyanık tutar.",
        sectionDisplays: "Ekranlarınızın parlaklığı.",
        sectionMixer: "Her uygulamanın sesi, her biri için ayrı bir sürgü.",
        sectionSystem: "İşlemci, grafik ve bellek bir bakışta.",
        sectionNetwork: "İnternet hızı ve hangi uygulamaların kullandığı.",
        sectionDisks: "Boş alan ve disk etkinliği.",
        sectionPower: "Pil, şarj ve güç kullanımı.",
        sectionFanControl: "Fan hızları ve kendi fan eğriniz.",
        sectionUtilities: "Ekran görüntüleri, temizleyici, güncellemeler ve diğer araçlar.",
        sectionControls: "Fare, klavye ve pencere özellikleri için anahtarlar.",
        sectionToggles: "Karanlık mod ve mikrofonu sessize alma gibi tek tıklık eylemler."
    )

    static let ru = GeneralSettingsStrings(
        pageDescription: "Запуск и внешний вид Hexa.",
        advancedPageDescription: "Резервное копирование и восстановление настроек.",
        aboutPageDescription: "Версия, исходный код и поддержка.",
        appearanceCaption: "Действует только на окна и панели Hexa, а не на весь Mac.",
        launchAtLoginCaption: "Открывается сам при каждом включении Mac.",
        panelIntro: "Нажмите значок Hexa в строке меню, чтобы открыть панель. Вкладки идут в этом порядке.",
        panelReorderHint: "Перетаскивайте, чтобы изменить порядок. Выключите то, что вам не нужно.",
        menuBarIconTitle: "Значок в строке меню",
        iconMissingTitle: "Не находите значок?",
        iconMissingCaption: "Переполненная строка меню может его скрыть, особенно на Mac с вырезом.",
        sectionKeepAwake: "Не даёт Mac уснуть столько, сколько вы захотите.",
        sectionDisplays: "Яркость ваших экранов.",
        sectionMixer: "Громкость каждого приложения, свой ползунок для каждого.",
        sectionSystem: "Процессор, графика и память с одного взгляда.",
        sectionNetwork: "Скорость интернета и какие приложения его используют.",
        sectionDisks: "Свободное место и активность дисков.",
        sectionPower: "Батарея, зарядка и энергопотребление.",
        sectionFanControl: "Скорость вентиляторов и ваша собственная кривая.",
        sectionUtilities: "Снимки экрана, очистка, обновления и другие инструменты.",
        sectionControls: "Переключатели для функций мыши, клавиатуры и окон.",
        sectionToggles: "Действия в одно нажатие, например тёмный режим и отключение микрофона."
    )

    static let es = GeneralSettingsStrings(
        pageDescription: "Inicio y apariencia de Hexa.",
        advancedPageDescription: "Copia de seguridad y restauración de los ajustes.",
        aboutPageDescription: "Versión, código y apoyo.",
        appearanceCaption: "Solo afecta a las ventanas y paneles de Hexa, no a todo el Mac.",
        launchAtLoginCaption: "Se abre solo cada vez que enciendes el Mac.",
        panelIntro: "Haz clic en el icono de Hexa en la barra de menús para abrir el panel. Sus pestañas aparecen en este orden.",
        panelReorderHint: "Arrastra para reordenar. Desactiva lo que no necesites.",
        menuBarIconTitle: "Icono de la barra de menús",
        iconMissingTitle: "¿No encuentras el icono?",
        iconMissingCaption: "Una barra de menús llena puede ocultarlo, sobre todo en Macs con notch.",
        sectionKeepAwake: "Mantiene el Mac despierto todo el tiempo que quieras.",
        sectionDisplays: "Brillo de tus pantallas.",
        sectionMixer: "Volumen de cada app, con un control para cada una.",
        sectionSystem: "Procesador, gráficos y memoria de un vistazo.",
        sectionNetwork: "Velocidad de internet y qué apps la están usando.",
        sectionDisks: "Espacio libre y actividad de los discos.",
        sectionPower: "Batería, carga y consumo de energía.",
        sectionFanControl: "Velocidad de los ventiladores y tu propia curva.",
        sectionUtilities: "Capturas de pantalla, limpieza, actualizaciones y otras herramientas.",
        sectionControls: "Interruptores para funciones de ratón, teclado y ventanas.",
        sectionToggles: "Acciones de un clic, como el modo oscuro y silenciar el micrófono."
    )

    static let sk = GeneralSettingsStrings(
        pageDescription: "Spustenie a vzhľad Hexa.",
        advancedPageDescription: "Zálohovanie a obnovenie nastavení.",
        aboutPageDescription: "Verzia, zdrojový kód a podpora.",
        appearanceCaption: "Platí len pre vlastné okná a panely Hexa, nie pre celý Mac.",
        launchAtLoginCaption: "Otvorí sa sám vždy, keď zapnete Mac.",
        panelIntro: "Kliknutím na ikonu Hexa v lište otvoríte panel. Jeho karty sa zobrazujú v tomto poradí.",
        panelReorderHint: "Presunutím zmeníte poradie. Vypnite čokoľvek, čo nepotrebujete.",
        menuBarIconTitle: "Ikona v lište s ponukami",
        iconMissingTitle: "Nemôžete nájsť ikonu?",
        iconMissingCaption: "Preplnená lišta ju môže skryť, najmä na Macoch s výrezom.",
        sectionKeepAwake: "Udrží váš Mac prebudený tak dlho, ako chcete.",
        sectionDisplays: "Jas vašich obrazoviek.",
        sectionMixer: "Hlasitosť každej aplikácie, každá má vlastný posuvník.",
        sectionSystem: "Procesor, grafika a pamäť na jeden pohľad.",
        sectionNetwork: "Rýchlosť internetu a ktoré aplikácie ho využívajú.",
        sectionDisks: "Voľné miesto a aktivita disku.",
        sectionPower: "Batéria, nabíjanie a spotreba energie.",
        sectionFanControl: "Rýchlosť ventilátorov a vlastná krivka ventilátora.",
        sectionUtilities: "Snímky obrazovky, čistenie, aktualizácie a ďalšie nástroje.",
        sectionControls: "Prepínače pre funkcie myši, klávesnice a okien.",
        sectionToggles: "Akcie na jedno kliknutie, napríklad tmavý režim a stlmenie mikrofónu."
    )

    static let de = GeneralSettingsStrings(
        pageDescription: "Start und Erscheinungsbild von Hexa.",
        advancedPageDescription: "Sicherung und Wiederherstellung der Einstellungen.",
        aboutPageDescription: "Version, Quellcode und Unterstützung.",
        appearanceCaption: "Gilt nur für die Fenster und Panels von Hexa, nicht für den ganzen Mac.",
        launchAtLoginCaption: "Öffnet sich von selbst, sobald du den Mac einschaltest.",
        panelIntro: "Klicke auf das Hexa-Symbol in der Menüleiste, um das Panel zu öffnen. Die Tabs erscheinen in dieser Reihenfolge.",
        panelReorderHint: "Zum Umsortieren ziehen. Was du nicht brauchst, einfach ausschalten.",
        menuBarIconTitle: "Menüleistensymbol",
        iconMissingTitle: "Symbol nicht zu finden?",
        iconMissingCaption: "Eine volle Menüleiste kann es verbergen, vor allem bei Macs mit Notch.",
        sectionKeepAwake: "Hält den Mac so lange wach, wie du willst.",
        sectionDisplays: "Helligkeit deiner Bildschirme.",
        sectionMixer: "Lautstärke jeder App, mit einem eigenen Regler.",
        sectionSystem: "Prozessor, Grafik und Speicher auf einen Blick.",
        sectionNetwork: "Internetgeschwindigkeit und welche Apps sie nutzen.",
        sectionDisks: "Freier Speicherplatz und Festplattenaktivität.",
        sectionPower: "Batterie, Laden und Stromverbrauch.",
        sectionFanControl: "Lüfterdrehzahlen und deine eigene Lüfterkurve.",
        sectionUtilities: "Bildschirmfotos, Bereinigung, Updates und weitere Werkzeuge.",
        sectionControls: "Schalter für Maus-, Tastatur- und Fensterfunktionen.",
        sectionToggles: "Aktionen mit einem Klick, etwa Dunkelmodus und Mikrofon stummschalten."
    )

    static let fr = GeneralSettingsStrings(
        pageDescription: "Démarrage et apparence de Hexa.",
        advancedPageDescription: "Sauvegarde et restauration des réglages.",
        aboutPageDescription: "Version, code source et soutien.",
        appearanceCaption: "Ne concerne que les fenêtres et panneaux de Hexa, pas tout le Mac.",
        launchAtLoginCaption: "S’ouvre tout seul à chaque démarrage du Mac.",
        panelIntro: "Cliquez sur l’icône de Hexa dans la barre des menus pour ouvrir le panneau. Ses onglets apparaissent dans cet ordre.",
        panelReorderHint: "Glissez pour réordonner. Désactivez ce dont vous n’avez pas besoin.",
        menuBarIconTitle: "Icône de la barre des menus",
        iconMissingTitle: "Vous ne trouvez pas l’icône\u{00A0}?",
        iconMissingCaption: "Une barre des menus encombrée peut la masquer, surtout sur les Mac avec encoche.",
        sectionKeepAwake: "Garde le Mac éveillé aussi longtemps que vous voulez.",
        sectionDisplays: "Luminosité de vos écrans.",
        sectionMixer: "Volume de chaque app, avec un curseur pour chacune.",
        sectionSystem: "Processeur, graphismes et mémoire en un coup d’œil.",
        sectionNetwork: "Vitesse d’Internet et apps qui l’utilisent.",
        sectionDisks: "Espace libre et activité des disques.",
        sectionPower: "Batterie, charge et consommation d’énergie.",
        sectionFanControl: "Vitesse des ventilateurs et votre propre courbe.",
        sectionUtilities: "Captures d’écran, nettoyage, mises à jour et autres outils.",
        sectionControls: "Interrupteurs pour les fonctions de souris, clavier et fenêtres.",
        sectionToggles: "Actions en un clic, comme le mode sombre et la coupure du micro."
    )

    static let it = GeneralSettingsStrings(
        pageDescription: "Avvio e aspetto di Hexa.",
        advancedPageDescription: "Backup e ripristino delle impostazioni.",
        aboutPageDescription: "Versione, codice e supporto.",
        appearanceCaption: "Vale solo per le finestre e i pannelli di Hexa, non per tutto il Mac.",
        launchAtLoginCaption: "Si apre da solo ogni volta che accendi il Mac.",
        panelIntro: "Fai clic sull’icona di Hexa nella barra dei menu per aprire il pannello. Le sue schede compaiono in questo ordine.",
        panelReorderHint: "Trascina per riordinare. Disattiva ciò che non ti serve.",
        menuBarIconTitle: "Icona della barra dei menu",
        iconMissingTitle: "Non trovi l’icona?",
        iconMissingCaption: "Una barra dei menu affollata può nasconderla, soprattutto sui Mac con notch.",
        sectionKeepAwake: "Tiene il Mac sveglio per tutto il tempo che vuoi.",
        sectionDisplays: "Luminosità dei tuoi schermi.",
        sectionMixer: "Volume di ogni app, con un cursore per ciascuna.",
        sectionSystem: "Processore, grafica e memoria a colpo d’occhio.",
        sectionNetwork: "Velocità di Internet e quali app la stanno usando.",
        sectionDisks: "Spazio libero e attività dei dischi.",
        sectionPower: "Batteria, ricarica e consumo di energia.",
        sectionFanControl: "Velocità delle ventole e la tua curva personale.",
        sectionUtilities: "Istantanee, pulizia, aggiornamenti e altri strumenti.",
        sectionControls: "Interruttori per le funzioni di mouse, tastiera e finestre.",
        sectionToggles: "Azioni con un clic, come la modalità scura e il silenziamento del microfono."
    )

    static let ja = GeneralSettingsStrings(
        pageDescription: "起動と Hexa の外観。",
        advancedPageDescription: "設定のバックアップと復元。",
        aboutPageDescription: "バージョン、ソースコード、サポート。",
        appearanceCaption: "Hexa のウインドウとパネルにだけ適用され、Mac 全体には影響しません。",
        launchAtLoginCaption: "Mac の電源を入れるたびに自動で開きます。",
        panelIntro: "メニューバーの Hexa アイコンをクリックするとパネルが開きます。タブはこの順番で表示されます。",
        panelReorderHint: "ドラッグして並べ替え。不要なものはオフにします。",
        menuBarIconTitle: "メニューバーのアイコン",
        iconMissingTitle: "アイコンが見つからない場合",
        iconMissingCaption: "メニューバーがいっぱいだと隠れることがあります。ノッチのある Mac では特によく起こります。",
        sectionKeepAwake: "好きな時間だけ Mac をスリープさせません。",
        sectionDisplays: "ディスプレイの明るさ。",
        sectionMixer: "アプリごとの音量。それぞれにスライダーがあります。",
        sectionSystem: "プロセッサ、グラフィックス、メモリをひと目で。",
        sectionNetwork: "インターネットの速度と、それを使っているアプリ。",
        sectionDisks: "空き容量とディスクのアクティビティ。",
        sectionPower: "バッテリー、充電、消費電力。",
        sectionFanControl: "ファンの回転数と自分で決めるファンカーブ。",
        sectionUtilities: "スクリーンショット、クリーナー、アップデートなどのツール。",
        sectionControls: "マウス、キーボード、ウインドウ機能のスイッチ。",
        sectionToggles: "ダークモードやマイクのミュートなど、ワンクリックの操作。"
    )

    static let ko = GeneralSettingsStrings(
        pageDescription: "시작과 Hexa 모양.",
        advancedPageDescription: "설정 백업 및 복원.",
        aboutPageDescription: "버전, 소스 코드, 후원.",
        appearanceCaption: "Hexa의 윈도우와 패널에만 적용되며 Mac 전체에는 영향을 주지 않습니다.",
        launchAtLoginCaption: "Mac을 켤 때마다 자동으로 열립니다.",
        panelIntro: "메뉴 막대의 Hexa 아이콘을 클릭하면 패널이 열립니다. 탭은 이 순서로 표시됩니다.",
        panelReorderHint: "드래그하여 순서를 바꾸고, 필요 없는 것은 끄세요.",
        menuBarIconTitle: "메뉴 막대 아이콘",
        iconMissingTitle: "아이콘이 보이지 않나요?",
        iconMissingCaption: "메뉴 막대가 가득 차면 숨겨질 수 있습니다. 노치가 있는 Mac에서 특히 흔합니다.",
        sectionKeepAwake: "원하는 시간만큼 Mac을 깨어 있게 합니다.",
        sectionDisplays: "화면의 밝기.",
        sectionMixer: "앱별 음량, 각각 슬라이더로 조절.",
        sectionSystem: "프로세서, 그래픽, 메모리를 한눈에.",
        sectionNetwork: "인터넷 속도와 이를 사용하는 앱.",
        sectionDisks: "남은 공간과 디스크 활동.",
        sectionPower: "배터리, 충전, 전력 사용량.",
        sectionFanControl: "팬 속도와 직접 만드는 팬 곡선.",
        sectionUtilities: "스크린샷, 클리너, 업데이트 및 기타 도구.",
        sectionControls: "마우스, 키보드, 윈도우 기능 스위치.",
        sectionToggles: "다크 모드, 마이크 음소거 같은 원클릭 동작."
    )

    static let zhHans = GeneralSettingsStrings(
        pageDescription: "启动和 Hexa 外观。",
        advancedPageDescription: "设置的备份与恢复。",
        aboutPageDescription: "版本、源代码与支持。",
        appearanceCaption: "仅影响 Hexa 自己的窗口和面板，不影响整台 Mac。",
        launchAtLoginCaption: "每次开机时自动打开。",
        panelIntro: "点按菜单栏中的 Hexa 图标即可打开面板。标签页按此顺序显示。",
        panelReorderHint: "拖动可重新排序。不需要的关掉即可。",
        menuBarIconTitle: "菜单栏图标",
        iconMissingTitle: "找不到图标？",
        iconMissingCaption: "菜单栏太满时图标可能被隐藏，带刘海的 Mac 上尤其常见。",
        sectionKeepAwake: "让 Mac 在你需要的时间内保持唤醒。",
        sectionDisplays: "显示器亮度。",
        sectionMixer: "每个 App 的音量，各有一个滑块。",
        sectionSystem: "处理器、图形和内存一目了然。",
        sectionNetwork: "网速以及正在使用网络的 App。",
        sectionDisks: "可用空间和磁盘活动。",
        sectionPower: "电池、充电和功耗。",
        sectionFanControl: "风扇转速和你自己的风扇曲线。",
        sectionUtilities: "截屏、清理、更新和其他工具。",
        sectionControls: "鼠标、键盘和窗口功能的开关。",
        sectionToggles: "深色模式、静音麦克风等一键操作。"
    )

    static let zhTW = GeneralSettingsStrings(
        pageDescription: "啟動和 Hexa 外觀。",
        advancedPageDescription: "設定的備份與還原。",
        aboutPageDescription: "版本、原始碼與支持。",
        appearanceCaption: "僅影響 Hexa 自己的視窗和面板，不影響整台 Mac。",
        launchAtLoginCaption: "每次開機時自動開啟。",
        panelIntro: "按一下選單列中的 Hexa 圖示即可開啟面板。標籤頁會依此順序顯示。",
        panelReorderHint: "拖曳可重新排序。不需要的關掉即可。",
        menuBarIconTitle: "選單列圖示",
        iconMissingTitle: "找不到圖示？",
        iconMissingCaption: "選單列太滿時圖示可能被隱藏，有瀏海的 Mac 上尤其常見。",
        sectionKeepAwake: "讓 Mac 在你需要的時間內保持喚醒。",
        sectionDisplays: "顯示器亮度。",
        sectionMixer: "每個 App 的音量，各有一個滑桿。",
        sectionSystem: "處理器、圖形和記憶體一目了然。",
        sectionNetwork: "網路速度以及正在使用網路的 App。",
        sectionDisks: "可用空間和磁碟活動。",
        sectionPower: "電池、充電和耗電。",
        sectionFanControl: "風扇轉速和你自訂的風扇曲線。",
        sectionUtilities: "截圖、清理、更新和其他工具。",
        sectionControls: "滑鼠、鍵盤和視窗功能的開關。",
        sectionToggles: "深色模式、將麥克風靜音等一鍵操作。"
    )

    static let zhHK = GeneralSettingsStrings(
        pageDescription: "啟動和 Hexa 外觀。",
        advancedPageDescription: "設定嘅備份同還原。",
        aboutPageDescription: "版本、原始碼同支持。",
        appearanceCaption: "只影響 Hexa 自己的視窗和面板，不影響整部 Mac。",
        launchAtLoginCaption: "每次開機時自動開啟。",
        panelIntro: "按一下選單列中的 Hexa 圖示即可開啟面板。分頁會按此次序顯示。",
        panelReorderHint: "拖曳可重新排序。不需要的關掉即可。",
        menuBarIconTitle: "選單列圖示",
        iconMissingTitle: "找不到圖示？",
        iconMissingCaption: "選單列太滿時圖示可能被隱藏，有瀏海的 Mac 上尤其常見。",
        sectionKeepAwake: "讓 Mac 在你需要的時間內保持喚醒。",
        sectionDisplays: "顯示器亮度。",
        sectionMixer: "每個 App 的音量，各有一個滑桿。",
        sectionSystem: "處理器、圖像和記憶體一目了然。",
        sectionNetwork: "網絡速度以及正在使用網絡的 App。",
        sectionDisks: "可用空間和磁碟活動。",
        sectionPower: "電池、充電和耗電。",
        sectionFanControl: "風扇轉速和你自訂的風扇曲線。",
        sectionUtilities: "截圖、清理、更新和其他工具。",
        sectionControls: "滑鼠、鍵盤和視窗功能的開關。",
        sectionToggles: "深色模式、將麥克風靜音等一鍵操作。"
    )
}
