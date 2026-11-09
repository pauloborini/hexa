// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import SwiftUI
import CoreText

/// Design system do hexa (DEC-017). Registro canônico de valores:
/// `_app-vault/specs/design-system.md`. A view consome token semântico;
/// literal direto de cor/fonte/tamanho é proibido quando existe papel aqui.
enum HexaTheme {
    // MARK: - Paleta base (spec §2.1)

    private static let ink = Color(hex: 0x201D17)
    private static let bone = Color(hex: 0xF6F4EE)
    private static let brass = Color(hex: 0xA3813C)
    private static let brassBright = Color(hex: 0xCFA955)
    private static let coal = Color(hex: 0x17140F)
    private static let panelDark = Color(hex: 0x211D15)

    private static let nsInk = NSColor(hex: 0x201D17)
    private static let nsBone = NSColor(hex: 0xF6F4EE)
    private static let nsBrass = NSColor(hex: 0xA3813C)
    private static let nsBrassBright = NSColor(hex: 0xCFA955)
    private static let nsCoal = NSColor(hex: 0x17140F)
    private static let nsPanelDark = NSColor(hex: 0x211D15)

    // MARK: - Tokens semânticos (spec §2.2), dinâmicos dark/light

    /// Fundo da superfície de trabalho.
    static let surfaceBase = dynamic(dark: nsCoal, light: nsBone)
    /// Cartão/painel elevado.
    static let surfaceRaised = dynamic(dark: nsPanelDark, light: NSColor(hex: 0xFBFAF6))
    /// Nicho (menu bar, notch, campo).
    static let surfaceInset = Color(surfaceInsetNSColor)
    /// Texto principal.
    static let fgPrimary = dynamic(dark: nsBone, light: nsInk)
    /// Texto de apoio (bone @ 66% / #5A554A).
    static let fgSecondary = dynamic(dark: nsBone.withAlphaComponent(0.66), light: NSColor(hex: 0x5A554A))
    /// Metadado discreto (bone @ 55% / ink @ 64%).
    static let fgTertiary = dynamic(dark: nsBone.withAlphaComponent(0.55), light: nsInk.withAlphaComponent(0.64))
    /// Desabilitado (bone @ 50% / ink @ 50%).
    static let fgDisabled = dynamic(dark: nsBone.withAlphaComponent(0.50), light: nsInk.withAlphaComponent(0.50))
    /// Texto sobre preenchimento invertido claro (ex.: dia selecionado do calendário do notch).
    static let fgInverse = dynamic(dark: nsInk, light: nsBone)
    /// Divisor decorativo (bone @ 13% / ink @ 14%).
    static let borderHairline = dynamic(dark: nsBone.withAlphaComponent(0.13), light: nsInk.withAlphaComponent(0.14))
    /// Taupe neutro derivado de bone (accent de UI quase sem cor; a marca
    /// permanece em latão). Prova de contraste: spec §6 (medido 2026-10-07).
    private static let nsTaupeDark = NSColor(hex: 0xA8A199)
    private static let nsTaupeTextDark = NSColor(hex: 0xB8B2A9)
    private static let nsTaupeLight = NSColor(hex: 0x6E675C)
    private static let nsTaupeTextLight = NSColor(hex: 0x5C564B)

    /// Accent não-texto: borda, fill de seleção, foco.
    static let accentSolid = dynamic(dark: nsTaupeDark, light: nsTaupeLight)
    /// Accent como texto (4.5:1 garantido pela spec §6).
    static let accentText = dynamic(dark: nsTaupeTextDark, light: nsTaupeTextLight)
    /// Anel de foco.
    static let focusRing = Color(focusRingNSColor)
    /// Fundo de seleção (taupe @ 12%).
    static let selectionBg = dynamic(dark: nsTaupeDark.withAlphaComponent(0.12), light: nsTaupeLight.withAlphaComponent(0.12))

    // MARK: Marca (DEC-017, spec §1): o latão NÃO alimenta mais papéis de UI;
    // fica reservado ao logo e ao wordmark.
    /// Latão da marca: segmento aberto e núcleo do glifo.
    static let brandSolid = dynamic(dark: nsBrassBright, light: nsBrass)
    /// Latão da marca como texto: "a" itálico do wordmark.
    static let brandText = dynamic(dark: nsBrassBright, light: NSColor(hex: 0x84682C))
    /// Indicador fixo de sessão Manter acordado.
    static let awakeActiveNSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(hex: 0xD89B4A) : NSColor(hex: 0x8E672C)
    }
    /// Espelho NSColor de `fgPrimary` (desenho em canvas/AppKit sobre a ilha).
    static let fgPrimaryNSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? nsBone : nsInk
    }
    /// Espelho NSColor de `fgSecondary`.
    static let fgSecondaryNSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? nsBone.withAlphaComponent(0.66) : NSColor(hex: 0x5A554A)
    }
    static let awakeActive = Color(awakeActiveNSColor)
    /// Sucesso/atualizado.
    static let statusOk = dynamic(dark: nsTaupeTextDark, light: nsTaupeTextLight)
    /// Aviso/pendente.
    static let statusWarning = dynamic(dark: nsTaupeTextDark, light: nsTaupeTextLight)
    /// Erro/risco.
    static let statusDanger = dynamic(dark: nsTaupeTextDark, light: nsTaupeTextLight)

    /// Espelho NSColor de `accentSolid`.
    static let accentSolidNSColor = dynamicNSColor(dark: nsTaupeDark, light: nsTaupeLight)
    /// Espelho NSColor de `focusRing` (desenho AppKit do anel de foco).
    static let focusRingNSColor = dynamicNSColor(dark: nsTaupeDark, light: nsTaupeLight)
    /// Espelho NSColor de `surfaceInset` (desenho AppKit de campos e controles).
    static let surfaceInsetNSColor = dynamicNSColor(dark: NSColor(hex: 0x1B1812), light: NSColor(hex: 0xECE8DD))
    /// Espelho NSColor de `selectionBg`.
    static let selectionBgNSColor = dynamicNSColor(
        dark: nsTaupeDark.withAlphaComponent(0.12),
        light: nsTaupeLight.withAlphaComponent(0.12)
    )
    /// Acessores CGColor para CoreGraphics.
    static var accentSolidCGColor: CGColor { accentSolidNSColor.cgColor }
    static var selectionBgCGColor: CGColor { selectionBgNSColor.cgColor }

    /// Resolve NSColor dinâmico dark/light.
    static func dynamicNSColor(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    private static func dynamic(dark: NSColor, light: NSColor) -> Color {
        Color(dynamicNSColor(dark: dark, light: light))
    }
}

// MARK: - Métricas (spec §4)

extension HexaTheme {
    /// Escala de espaçamento: 4 · 8 · 12 · 16 · 20 · 24 · 32.
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let pageGap: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Raios: controle 6, painel 10, base do notch 14.
    enum Radius {
        static let control: CGFloat = 6
        static let panel: CGFloat = 10
        static let notch: CGFloat = 14
    }

    /// Hairline: 1 px.
    static let hairline: CGFloat = 1

    /// Densidade: linha compacta 28, linha padrão 36, item de menu bar 24, linha da sidebar 30.
    enum Density {
        static let rowCompact: CGFloat = 28
        static let rowStandard: CGFloat = 36
        static let menuBarItem: CGFloat = 24
        static let rowSidebar: CGFloat = 30
    }
}

// MARK: - Tipografia (spec §3)

enum HexaFontRole {
    /// Instrument Serif 400 (itálico permitido), tracking -0.01em.
    case display(CGFloat)
    /// Manrope 600, 15/20, tracking -0.01em.
    case heading
    /// Manrope 400, 13/18.
    case body
    /// Manrope 500, 12/15.
    case label
    /// IBM Plex Mono 500, 10.5/13, uppercase, tracking 0.16em.
    case micro
    /// IBM Plex Mono 400/500, 12.5/16, tabular-nums.
    case data

    /// Título da feature/página (token §3): Instrument Serif, UM tamanho.
    /// Todo título de tela do hexa usa este token, em qualquer janela.
    static var featureTitle: HexaFontRole { .display(PageTypography.title) }
    /// Subtítulo da feature/página (token §3): Manrope 400 13, distinto do
    /// título de seção (SectionLabel, micro — spec §7).
    static var featureSubtitle: HexaFontRole { .body }
}

/// Medidas dos tokens tipográficos de página (spec §3). Um único valor por
/// papel: nenhuma tela define tamanho de título próprio.
enum PageTypography {
    /// Título de feature/página — o mesmo em todas as telas.
    static let title: CGFloat = 28
}

extension HexaTheme {
    /// Resolve com segurança a fonte pelo nome PostScript ou cai para o fallback
    /// da spec (Georgia / Helvetica Neue / Menlo / SystemFont).
    /// Valida se a fonte registrada não retorna glifo .notdef (0) para caracteres
    /// básicos, impedindo que fontes corrompidas ou sem CMAP gerem tofu (missing glyphs).
    static func safeFont(name: String, size: CGFloat, fallback: () -> NSFont) -> NSFont {
        if let font = NSFont(name: name, size: size) {
            let sample = "Hexa"
            var glyphs = [CGGlyph](repeating: 0, count: sample.utf16.count)
            let chars = Array(sample.utf16)
            if CTFontGetGlyphsForCharacters(font as CTFont, chars, &glyphs, chars.count),
               !glyphs.contains(0) {
                return font
            }
        }
        return fallback()
    }
}

extension Font {
    /// Papel tipográfico do design system. Resolução garantida com fallback
    /// seguro (spec §3: Georgia / Helvetica Neue / Menlo) impedindo qualquer
    /// regressão de tofu (.notdef) caso o CoreText falhe na resolução de instâncias.
    static func hexa(_ role: HexaFontRole, italic: Bool = false) -> Font {
        switch role {
        case .display(let size):
            let ns = HexaTheme.safeFont(name: italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: size) {
                NSFont(name: italic ? "Georgia-Italic" : "Georgia", size: size)
                    ?? NSFont.systemFont(ofSize: size, weight: .regular)
            }
            return Font(ns)
        case .heading:
            let ns = HexaTheme.safeFont(name: "Manrope-SemiBold", size: 15) {
                NSFont(name: "HelveticaNeue-Medium", size: 15)
                    ?? NSFont.systemFont(ofSize: 15, weight: .semibold)
            }
            return Font(ns)
        case .body:
            let ns = HexaTheme.safeFont(name: "Manrope-Regular", size: 13) {
                NSFont(name: "HelveticaNeue", size: 13)
                    ?? NSFont.systemFont(ofSize: 13, weight: .regular)
            }
            return Font(ns)
        case .label:
            let ns = HexaTheme.safeFont(name: "Manrope-Medium", size: 12) {
                NSFont(name: "HelveticaNeue-Medium", size: 12)
                    ?? NSFont.systemFont(ofSize: 12, weight: .medium)
            }
            return Font(ns)
        case .micro:
            let ns = HexaTheme.safeFont(name: "IBMPlexMono-Medium", size: 10.5) {
                NSFont(name: "Menlo", size: 10.5)
                    ?? NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)
            }
            return Font(ns)
        case .data:
            let ns = HexaTheme.safeFont(name: "IBMPlexMono-Regular", size: 12.5) {
                NSFont(name: "Menlo", size: 12.5)
                    ?? NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
            }
            return Font(ns)
        }
    }
}

extension View {
    /// Aplica o papel tipográfico com tracking e caixa do papel.
    /// Cor NÃO é aplicada aqui (exceto `micro`, que carrega a assinatura
    /// accentText da spec): fica ortogonal e explícita via tokens `HexaTheme`.
    @ViewBuilder
    func hexaFont(_ role: HexaFontRole, italic: Bool = false) -> some View {
        switch role {
        case .display(let size):
            self
                .font(.hexa(.display(size), italic: italic))
                .kerning(size * -0.01)
        case .heading:
            self
                .font(.hexa(.heading))
                .kerning(15 * -0.01)
        case .body:
            self.font(.hexa(.body))
        case .label:
            self.font(.hexa(.label))
        case .micro:
            self
                .font(.hexa(.micro))
                .tracking(10.5 * 0.16)
                .textCase(.uppercase)
        case .data:
            self.font(.hexa(.data))
        }
    }

    /// Rótulo de seção (SectionLabel, spec §7): micro + accentText
    /// (assinatura da marca em uso controlado).
    func hexaSectionLabel() -> some View {
        hexaFont(.micro)
            .foregroundStyle(HexaTheme.accentText)
    }
}

extension HexaTheme {
    /// Wordmark "hexa" (spec §1.2): minúsculas, Instrument Serif regular,
    /// "a" em itálico na cor de marca (latão). Marca, não string de usuário (DEC-016).
    /// "hex" herda a cor do contexto; "a" usa `brandText`.
    static func wordmark(size: CGFloat = 20) -> Text {
        let tracking = size * -0.02
        return Text("hex")
            .font(.hexa(.display(size)))
            .kerning(tracking)
            + Text("a")
            .font(.hexa(.display(size), italic: true))
            .kerning(tracking)
            .foregroundColor(brandText)
    }
}

// MARK: - Registro de fontes

extension HexaTheme {
    private static var fontsRegistered = false

    /// Registra as fontes OFL embutidas no escopo do processo. Idempotente.
    /// Chamar uma vez no launch, antes de qualquer view renderizar.
    static func registerFonts() {
        guard !fontsRegistered else { return }
        fontsRegistered = true
        let postScriptNames = [
            "InstrumentSerif-Regular",
            "InstrumentSerif-Italic",
            "Manrope-Regular",
            "Manrope-Medium",
            "Manrope-SemiBold",
            "IBMPlexMono-Regular",
            "IBMPlexMono-Medium"
        ]
        var urls: [CFURL] = []
        for name in postScriptNames {
            let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            if let url {
                urls.append(url as CFURL)
            }
        }
        if !urls.isEmpty {
            CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
        }
    }

    /// Papel `data` para desenho AppKit (leituras da menu bar). Sem peso
    /// SemiBold na família Plex Mono carregada, peso maior cai em Medium.
    /// Cai para a mono do sistema se a OFL não estiver registrada, para o
    /// binário sem recursos nunca ficar sem fonte.
    static func dataFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch weight {
        case .medium, .semibold, .bold, .heavy, .black:
            return safeFont(name: "IBMPlexMono-Medium", size: size) {
                NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            }
        default:
            return safeFont(name: "IBMPlexMono-Regular", size: size) {
                NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            }
        }
    }

    /// Papéis Manrope para desenho AppKit (rótulos das leituras da menu bar).
    static func manropeFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return safeFont(name: "Manrope-SemiBold", size: size) {
                NSFont(name: "HelveticaNeue-Medium", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            }
        case .medium:
            return safeFont(name: "Manrope-Medium", size: size) {
                NSFont(name: "HelveticaNeue-Medium", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            }
        default:
            return safeFont(name: "Manrope-Regular", size: size) {
                NSFont(name: "HelveticaNeue", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            }
        }
    }
}

// MARK: - Fonte do tema em tamanho dinâmico (engenharia fina do notch)

extension Font {
    /// Manrope em tamanho dinâmico: preserva a medida do layout (DEC-007)
    /// e adota a família do tema.
    static func hexaManrope(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        let nsWeight: NSFont.Weight
        switch weight {
        case .semibold, .bold, .heavy, .black:
            name = "Manrope-SemiBold"
            nsWeight = .semibold
        case .medium:
            name = "Manrope-Medium"
            nsWeight = .medium
        default:
            name = "Manrope-Regular"
            nsWeight = .regular
        }
        let ns = HexaTheme.safeFont(name: name, size: size) {
            NSFont(name: "HelveticaNeue", size: size) ?? NSFont.systemFont(ofSize: size, weight: nsWeight)
        }
        return Font(ns)
    }

    /// IBM Plex Mono em tamanho dinâmico (papel `data` fora da medida 11.5).
    static func hexaMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let isMedium = weight == .medium || weight == .semibold || weight == .bold || weight == .heavy || weight == .black
        let name = isMedium ? "IBMPlexMono-Medium" : "IBMPlexMono-Regular"
        let nsWeight: NSFont.Weight = isMedium ? .medium : .regular
        let ns = HexaTheme.safeFont(name: name, size: size) {
            NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: nsWeight)
        }
        return Font(ns)
    }
}

// MARK: - Marca: Conceito A "Segmento aberto" (spec §1.1)

/// Desenho vetorial da marca hexa: hexágono pointy-top segmentado, com o
/// segmento superior-direito solto (deslocado 2.5 para fora) e núcleo central.
/// Construção em viewBox 48, centro (24,24), r=15; AppKit desenha y-up,
/// então o y é espelhado aqui. Sem gradiente, sombra ou contorno externo.
enum HexaBrandGlyph {
    /// Vértices do hexágono pointy-top r=15 (spec §1.1).
    private static let vertices: [(CGFloat, CGFloat)] = [
        (24, 9), (36.99, 16.5), (36.99, 31.5), (24, 39), (11.01, 31.5), (11.01, 16.5)
    ]

    /// Segmento fechado base (trimmed pelos gaps); os outros 4 saem daqui
    /// por rotação de 60° a 300° em torno do centro.
    private static let baseSegment: [(CGFloat, CGFloat)] = [(25.73, 10), (35.25, 15.5)]

    /// Segmento aberto (superior direito), já deslocado 2.5 para fora.
    private static let openSegment: [(CGFloat, CGFloat)] = [(29.14, 9.08), (34.34, 12.08)]

    /// Peso por tamanho (spec §1.1): stroke e raio do núcleo em UNIDADES do
    /// viewBox 48 (o protótipo usa stroke-width 4 no viewBox renderizado a
    /// 16 px, por exemplo).
    private static func weight(for size: CGFloat) -> (stroke: CGFloat, core: CGFloat) {
        if size >= 32 { return (2, 2.2) }
        if size >= 20 { return (3, 2.8) }
        return (4, 3.4)
    }

    private static func rotate(_ p: (CGFloat, CGFloat), degrees: CGFloat) -> (CGFloat, CGFloat) {
        let rad = degrees * .pi / 180
        let dx = p.0 - 24, dy = p.1 - 24
        return (24 + dx * cos(rad) - dy * sin(rad),
                24 + dx * sin(rad) + dy * cos(rad))
    }

    private static func segmentPath(_ pts: [(CGFloat, CGFloat)], size: CGFloat) -> Path {
        let s = size / 48
        let a = pts[0], b = pts[1]
        return Path { p in
            p.move(to: CGPoint(x: a.0 * s, y: a.1 * s))
            p.addLine(to: CGPoint(x: b.0 * s, y: b.1 * s))
        }
    }

    /// Os 5 segmentos fechados, em `size` pt (y-down, como a spec).
    static func closedSegments(size: CGFloat) -> [Path] {
        stride(from: 60.0, through: 300.0, by: 60.0).map { angle in
            segmentPath(baseSegment.map { rotate($0, degrees: CGFloat(angle)) }, size: size)
        }
    }

    /// O segmento aberto (superior direito), em `size` pt.
    static func openSegment(size: CGFloat) -> Path {
        segmentPath(openSegment, size: size)
    }

    /// O núcleo circular, em `size` pt.
    static func core(size: CGFloat) -> CGRect {
        let r = weight(for: size).core * size / 48
        let s = size / 48
        return CGRect(x: 24 * s - r, y: 24 * s - r, width: r * 2, height: r * 2)
    }

    /// Peso (largura do traço) em pt para uma marca renderizada a `size` pt.
    static func strokeWidth(for size: CGFloat) -> CGFloat {
        weight(for: size).stroke * size / 48
    }

    /// Desenha a marca ocupando `size` pt no contexto (coordenadas y-up do
    /// AppKit/CoreGraphics). `accentColor`: desenha o segmento solto e o
    /// núcleo na cor de accent; sem accent, tudo sai na cor do traço.
    static func draw(in context: CGContext, size: CGFloat, strokeColor: CGColor, accentColor: CGColor? = nil) {
        let s = size / 48
        let w = weight(for: size)
        context.saveGState()
        context.translateBy(x: 0, y: size)
        context.scaleBy(x: s, y: -s)

        func addSegment(_ pts: [(CGFloat, CGFloat)]) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            path.addLine(to: CGPoint(x: pts[1].0, y: pts[1].1))
            context.addPath(path)
        }

        context.setStrokeColor(strokeColor)
        context.setLineWidth(w.stroke)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for angle in stride(from: 60.0, through: 300.0, by: 60.0) {
            addSegment(baseSegment.map { rotate($0, degrees: CGFloat(angle)) })
            context.strokePath()
        }

        let coreColor = accentColor ?? strokeColor
        let coreR = w.core
        let core = CGRect(x: 24 - coreR, y: 24 - coreR, width: coreR * 2, height: coreR * 2)
        context.setStrokeColor(coreColor)
        addSegment(openSegment)
        context.strokePath()
        context.setFillColor(coreColor)
        context.fillEllipse(in: core)
        context.restoreGState()
    }

    /// Marca para a menu bar: template image (dark/light automático).
    /// Alvo de 28 pt, limitado à espessura real da barra (o glifo ocupa só
    /// 62,5% da altura do viewBox, então a tinta cabe com respiro natural).
    static var menuBarSize: CGFloat { min(28, NSStatusBar.system.thickness) }

    static func menuBarImage() -> NSImage {
        let size = menuBarSize
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.clip(to: rect)
            // Template: cor única; o AppKit tinge pelo tema da menu bar.
            draw(in: context, size: size, strokeColor: NSColor.black.cgColor)
            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - Color(hex:) e NSColor(hex:)

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Geometria aprovada para a janela operacional e o painel rápido (spec).
enum FeatureWorkspaceMetrics {
    static let width: CGFloat = 800
    static let height: CGFloat = 690
    static let minWidth: CGFloat = width
    static let minHeight: CGFloat = height
    static let sidebarWidth: CGFloat = 220
    static let scaffoldWidth: CGFloat = width - sidebarWidth
    static let contentWidth: CGFloat = scaffoldWidth - HexaTheme.Spacing.xxl * 2
    static let toolbarHeight: CGFloat = 48
    static let workspaceTopInset: CGFloat = 32
    static let quickWidth: CGFloat = 600
    static let metricValueSize: CGFloat = 20
}

enum HexaSwitchMetrics {
    static let width: CGFloat = 36
    static let height: CGFloat = 22
    static let knob: CGFloat = 14
    static let inset: CGFloat = 3
}

/// Tamanhos dos glifos da família única.
enum HexaIconMetrics {
    static let standard: CGFloat = 16
    static let label: CGFloat = 14
    /// Ícone pequeno (botão de ícone small, glifo de saída de acesso).
    static let small: CGFloat = 12
}
