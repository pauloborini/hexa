// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct PanelMediaView: View {
    var onClose: () -> Void

    var body: some View {
        MediaWorkspaceView(compact: true, onClose: onClose)
            .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
            .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}

private enum MediaCompressionLevel: CaseIterable {
    case low, medium, high

    var quality: Double {
        switch self {
        case .low: return 0.88
        case .medium: return 0.68
        case .high: return 0.28
        }
    }

    /// Nível de um valor lido da chave. A escala é discreta: o segmento grava
    /// `quality` do nível escolhido, então só uma gravação anterior a ela cai no
    /// mais próximo.
    init(storedQuality: Double) {
        self = Self.allCases.min {
            abs($0.quality - storedQuality) < abs($1.quality - storedQuality)
        } ?? .medium
    }
}

extension MediaTool {
    /// Rótulo do segmento de ferramenta, único para o seletor do painel e o do workspace.
    func segmentTitle(_ s: Strings) -> String {
        switch self {
        case .videoCompressor: return s.mediaToolVideo
        case .gifMaker: return s.mediaToolGIF
        case .imageCompressor: return s.mediaToolImage
        case .textExtractor: return s.mediaToolText
        }
    }
}

/// Seletor das quatro ferramentas de mídia. Só mostra e devolve a escolha;
/// os efeitos da troca ficam em `MediaWorkspaceView`.
/// Fica desabilitado enquanto `media` converte: trocar de ferramenta reseta o
/// serviço e cancelaria a conversão em silêncio.
struct MediaToolPicker: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var selection: MediaTool
    @ObservedObject var media: MediaService = .shared

    var body: some View {
        HexaSegmentControl(MediaTool.allCases.map { $0.segmentTitle(l10n.s) }, selection: Binding(
            get: { MediaTool.allCases.firstIndex(of: selection) ?? 0 },
            set: { selection = MediaTool.allCases[$0] }
        ))
        .disabled(isRunning)
    }

    private var isRunning: Bool {
        if case .running = media.state { return true }
        return false
    }
}

struct MediaWorkspaceView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var media: MediaService
    @ObservedObject private var featureRuntime = FeatureRuntime.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notchPresentation) private var inNotch

    @AppStorage(DefaultsKey.mediaLastTool) private var toolRaw = MediaTool.videoCompressor.rawValue
    @AppStorage(DefaultsKey.mediaVideoStart) private var videoStart = 0.0
    @AppStorage(DefaultsKey.mediaVideoEnd) private var videoEnd = 0.0
    @AppStorage(DefaultsKey.mediaVideoQuality) private var videoQuality = 0.68
    @AppStorage(DefaultsKey.mediaVideoMaxDimension) private var videoMaxDimension = 1280
    @AppStorage(DefaultsKey.mediaVideoFPS) private var videoFPSRaw = 30.0
    @AppStorage(DefaultsKey.mediaVideoKeepAudio) private var videoKeepAudio = true
    @AppStorage(DefaultsKey.mediaVideoCodec) private var videoCodecRaw = MediaVideoCodec.h264.rawValue
    @AppStorage(DefaultsKey.mediaVideoSizing) private var videoSizingRaw = MediaSizingMode.resolution.rawValue
    @AppStorage(DefaultsKey.mediaVideoTargetMegabytes) private var videoTargetMegabytes = 20

    @AppStorage(DefaultsKey.mediaGIFStart) private var gifStart = 0.0
    @AppStorage(DefaultsKey.mediaGIFEnd) private var gifEnd = 0.0
    @AppStorage(DefaultsKey.mediaGIFQuality) private var gifQualityRaw = 0.74
    @AppStorage(DefaultsKey.mediaGIFWidth) private var gifWidth = 720
    @AppStorage(DefaultsKey.mediaGIFFPS) private var gifFPS = 12.0
    @AppStorage(DefaultsKey.mediaGIFLoops) private var gifLoops = true
    @AppStorage(DefaultsKey.mediaGIFSizing) private var gifSizingRaw = MediaSizingMode.resolution.rawValue
    @AppStorage(DefaultsKey.mediaGIFTargetMegabytes) private var gifTargetMegabytes = 10

    @AppStorage(DefaultsKey.mediaImageQuality) private var imageQuality = 0.68
    @AppStorage(DefaultsKey.mediaImageMaxDimension) private var imageMaxDimension = 1600
    @AppStorage(DefaultsKey.mediaImageFormat) private var imageFormatRaw = MediaImageFormat.jpeg.rawValue
    @AppStorage(DefaultsKey.mediaImageStripMetadata) private var imageStripMetadata = true
    @AppStorage(DefaultsKey.mediaImageResizeKind) private var imageResizeKindRaw = MediaImageResizeKind.maxDimension.rawValue
    @AppStorage(DefaultsKey.mediaImageResizeWidth) private var imageResizeWidth = 1600
    @AppStorage(DefaultsKey.mediaImageResizeHeight) private var imageResizeHeight = 1200
    @AppStorage(DefaultsKey.mediaImageExactResizeMode) private var imageExactResizeModeRaw = MediaImageExactResizeMode.stretch.rawValue
    @AppStorage(DefaultsKey.mediaImageWatermarkKind) private var imageWatermarkKindRaw = MediaImageWatermarkKind.off.rawValue
    @AppStorage(DefaultsKey.mediaImageWatermarkText) private var imageWatermarkText = ""
    @AppStorage(DefaultsKey.mediaImageWatermarkLogoPath) private var imageWatermarkLogoPath = ""
    @AppStorage(DefaultsKey.mediaImageWatermarkPosition) private var imageWatermarkPositionRaw = MediaImageWatermarkPosition.bottomRight.rawValue
    @AppStorage(DefaultsKey.mediaImageWatermarkOpacity) private var imageWatermarkOpacity = 0.45
    @AppStorage(DefaultsKey.mediaImageWatermarkMargin) private var imageWatermarkMargin = 32
    @AppStorage(DefaultsKey.mediaImageWatermarkScale) private var imageWatermarkScale = 0.18
    @AppStorage(DefaultsKey.mediaImageRenamePattern) private var imageRenamePattern = ""
    @AppStorage(DefaultsKey.mediaImageBackground) private var imageBackgroundRaw = MediaImageBackground.transparent.rawValue
    @AppStorage(DefaultsKey.mediaImagePreserveModificationDate) private var imagePreserveModificationDate = false
    @AppStorage(DefaultsKey.mediaImageSaveInSubfolder) private var imageSaveInSubfolder = false
    @AppStorage(DefaultsKey.mediaImageProfiles) private var imageProfilesRaw = "[]"
    @AppStorage(DefaultsKey.mediaImageSelectedProfileID) private var imageSelectedProfileID = ""

    @AppStorage(DefaultsKey.mediaTextAccurate) private var textAccurate = true
    @AppStorage(DefaultsKey.mediaTextLanguageCorrection) private var textLanguageCorrection = true

    @StateObject private var workspace: MediaWorkspaceSelection
    private var inputURLs: [URL] {
        get { workspace.inputURLs }
        nonmutating set { workspace.inputURLs = newValue }
    }
    private var inputImageSize: CGSize? {
        get { workspace.inputImageSize }
        nonmutating set { workspace.inputImageSize = newValue }
    }
    private var outputURL: URL? {
        get { workspace.outputURL }
        nonmutating set { workspace.outputURL = newValue }
    }
    private var outputWasChosenManually: Bool {
        get { workspace.outputWasChosenManually }
        nonmutating set { workspace.outputWasChosenManually = newValue }
    }
    @State private var isDropTargeted = false
    @State private var localMessage: String?
    /// Altura medida do conteúdo no modo compact: o OverlayScrollView
    /// (NSScrollView) não tem tamanho intrínseco, então o teto do painel
    /// é aplicado sobre a altura real medida do conteúdo.
    @State private var compactContentHeight: CGFloat = 430
    @State private var mediaDefaultsTask: Task<Void, Never>?
    @State private var profileName = ""
    @State private var imageMoreOptionsExpanded = false
    /// A saída desenhada pelo serviço com o mesmo render do arquivo gravado.
    /// Um pedido vencido nunca chama o completion, então a tela mantém a última
    /// imagem até a próxima chegar.
    @State private var outputPreview: CGImage?
    /// O pedido atual já respondeu, com imagem ou sem. Antes disso a miniatura
    /// mostra carregamento, não o mesmo ícone de "sem imagem".
    @State private var previewFinished = false

    var compact: Bool
    var onClose: (() -> Void)?
    private let initialInputs: [URL]
    private let initialTool: MediaTool?
    private let preservesServiceState: Bool
    private let onContentHeightChange: ((CGFloat) -> Void)?
    private let onToolChange: (() -> Void)?
    /// True when the host draws `MediaToolPicker` in its own pinned slot, so this view omits its picker.
    private let toolPickerHoisted: Bool
    /// Última ferramenta com efeitos aplicados; difere de `selectedTool` só quando a chave muda por fora.
    @State private var appliedTool: MediaTool?

    init(compact: Bool, onClose: (() -> Void)? = nil,
         media: MediaService = .shared, initialInputs: [URL] = [],
         initialTool: MediaTool? = nil, preservesServiceState: Bool = false,
         workspace: MediaWorkspaceSelection? = nil,
         onContentHeightChange: ((CGFloat) -> Void)? = nil,
         onToolChange: (() -> Void)? = nil,
         toolPickerHoisted: Bool = false) {
        self.compact = compact
        self.onClose = onClose
        self.media = media
        self.initialInputs = initialInputs
        self.initialTool = initialTool
        self.preservesServiceState = preservesServiceState
        self.onContentHeightChange = onContentHeightChange
        self.onToolChange = onToolChange
        self.toolPickerHoisted = toolPickerHoisted
        _workspace = StateObject(wrappedValue: workspace ?? MediaWorkspaceSelection())
    }

    private var inputURL: URL? { inputURLs.first }
    private static let imageOutputSubfolderName = "Converted"
    private static let imageRenameTokens = [
        "{name}", "{index}", "{index:03}", "{counter}", "{date}",
        "{time}", "{datetime}", "{width}", "{height}", "{format}",
    ]
    private var imageText: MediaImageConverterStrings {
        MediaImageConverterStrings.localized(l10n.language)
    }

    private var screenshotText: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var selectedTool: MediaTool {
        get { workspace.tool ?? MediaSupport.sanitizedTool(toolRaw) }
        nonmutating set {
            if preservesServiceState { workspace.tool = newValue }
            else { toolRaw = newValue.rawValue }
            applyToolChange(newValue)
        }
    }

    /// Efeitos de trocar a ferramenta: entrada de imagem, saída padrão, padrões e reset do serviço.
    private func applyToolChange(_ tool: MediaTool) {
        appliedTool = tool
        inputImageSize = tool == .imageCompressor
            ? inputURL.flatMap { MediaSupport.imageDisplaySize(at: $0) }
            : nil
        outputURL = defaultOutputURL(for: inputURLs, tool: tool)
        outputWasChosenManually = false
        applyMediaDefaults(for: inputURL, tool: tool)
        localMessage = nil
        media.reset()
    }

    private var selectedToolBinding: Binding<MediaTool> {
        Binding {
            selectedTool
        } set: { newValue in
            guard newValue != selectedTool else { return }
            onToolChange?()
            selectedTool = newValue
        }
    }

    private var isRunning: Bool {
        if case .running = media.state { return true }
        return false
    }

    var body: some View {
        layout
        .onAppear {
            if !workspace.loadedInitialInputs {
                workspace.loadedInitialInputs = true
                if let initialTool {
                    if preservesServiceState { workspace.tool = initialTool }
                    else { selectedTool = initialTool }
                }
                if !initialInputs.isEmpty { setInputs(initialInputs, resetsMedia: !preservesServiceState) }
            } else {
                applyMediaDefaults(for: inputURL, tool: selectedTool, replacingInput: false)
            }
        }
        .onChange(of: currentImageOptions) { oldOptions, newOptions in
            guard selectedTool == .imageCompressor else { return }
            if outputWasChosenManually {
                if inputURLs.count == 1,
                   oldOptions.format != newOptions.format,
                   let outputURL {
                    self.outputURL = MediaSupport.outputURLByReplacingExtension(
                        outputURL,
                        fileExtension: newOptions.format.fileExtension)
                }
                return
            }
            outputURL = defaultOutputURL(for: inputURLs, tool: .imageCompressor)
        }
        .onDisappear {
            mediaDefaultsTask?.cancel()
            workspace.durationLoading.cancel()
            media.cancelImagePreview()
        }
        .onChange(of: featureRuntime.revision) {
            if !AppFeature.mediaTools.isAvailable {
                mediaDefaultsTask?.cancel()
                workspace.durationLoading.cancel()
            }
        }
        .onChange(of: toolRaw) {
            // Troca vinda do seletor do workspace (outra view, mesma chave): aplica os efeitos aqui.
            guard !preservesServiceState, selectedTool != appliedTool else { return }
            // Com conversão em andamento, a troca vinda de fora é desfeita: aplicá-la
            // resetaria o serviço e cancelaria a conversão sem aviso.
            if isRunning, let appliedTool {
                toolRaw = appliedTool.rawValue
                return
            }
            applyToolChange(selectedTool)
        }
    }

    private var layout: some View {
        Group {
            if let onContentHeightChange {
                // Seletor fixo acima da área rolável (regra A6); a altura medida
                // continua sendo a do conjunto inteiro, como antes.
                VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m) {
                    header
                    if !toolPickerHoisted { toolPicker }
                    OverlayScrollView {
                        content.padding(.trailing, 1) // geometria de plataforma (spec §4): gutter do indicador de scroll
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    onContentHeightChange($0)
                }
            } else {
                VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m) {
                    header
                    if !toolPickerHoisted { toolPicker }
                    if compact {
                        // Painel: o conteúdo define a altura até o teto e
                        // rola além disso. O NSScrollView não adota a altura
                        // ideal do conteúdo, então medimos o conteúdo interno
                        // e fixamos a altura do container nesse mínimo.
                        OverlayScrollView {
                            content.padding(.trailing, 1) // geometria de plataforma (spec §4): gutter do indicador de scroll
                                .fixedSize(horizontal: false, vertical: true)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                    compactContentHeight = $0
                                }
                        }
                        .frame(height: min(compactContentHeight, 430))
                    } else {
                        // Workspace: o container ocupa o espaço disponível e
                        // só rola se o conteúdo exceder.
                        OverlayScrollView {
                            content.padding(.trailing, 1) // geometria de plataforma (spec §4): gutter do indicador de scroll
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let onClose {
            HStack {
                Spacer()
                HexaIconButton(icon: "xmark.circle.fill",
                               label: l10n.s.uninstallerCancel,
                               variant: .small,
                               action: onClose)
                    .help(l10n.s.uninstallerCancel)
            }
        }
    }

    private var toolPicker: some View {
        MediaToolPicker(selection: selectedToolBinding, media: media)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.l) {
            fileCard
            optionsCard
            actionRow
            statusCard
            if !compact {
                Spacer().frame(height: HexaTheme.Spacing.pageGap)
            }
        }
    }

    /// DEC-017: seção de página = SectionLabel FORA do cartão. Na
    /// apresentação workspace (não-compacta) o cartão é `HexaSection(title)`;
    /// no painel/notch (`compact`) o desenho `.panelCard()` é preservado.
    @ViewBuilder
    private func sectioned<Content: View>(_ title: String,
                                          @ViewBuilder _ content: @escaping () -> Content) -> some View {
        if compact {
            content().panelCard()
        } else {
            HexaSection(title) { content() }
        }
    }

    @ViewBuilder private var inputDropTarget: some View {
        if inNotch {
            inputSelector
        } else {
            inputSelector.onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                acceptDrop(providers)
            }
        }
    }

    private var inputSelector: some View {
        ZStack(alignment: .trailing) {
            Button {
                chooseInput()
            } label: {
                HStack(spacing: HexaTheme.Spacing.s) {
                    HexaIcons.image(selectedTool == .textExtractor ? "doc.text.viewfinder" : "doc.badge.plus", size: 15)
                        .font(.hexa(.heading))
                    VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                        Text(inputTitle)
                            .font(compact ? .hexa(.label) : .hexa(.body))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(l10n.s.mediaDropHint)
                            .font(.hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m)
                // Reserva compacta = botão pequeno + folga do conteúdo (s + xs/2); workspace mantém o gutter de 32.
                .padding(.trailing, inputURLs.isEmpty ? 0 : compact
                    ? HexaTheme.Spacing.xl + HexaTheme.Spacing.s + HexaTheme.Spacing.xs / 2
                    : HexaTheme.Spacing.xxl)
                .frame(maxWidth: .infinity, minHeight: compact ? 52 : 62, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 62, alignment: .leading)
            // Trocar ou limpar a entrada reseta o serviço e cancelaria a conversão.
            .disabled(isRunning)

            if !inputURLs.isEmpty {
                HexaIconButton(icon: "xmark.circle.fill",
                               label: l10n.s.mediaCancel,
                               variant: compact ? .small : .regular,
                               action: clearInput)
                    .help(l10n.s.mediaCancel)
                    .disabled(isRunning)
                    .padding(.trailing, compact ? HexaTheme.Spacing.s : HexaTheme.Spacing.m)
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 52 : 62, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                .fill(isDropTargeted ? HexaTheme.selectionBg : PanelSurface.controlFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                .strokeBorder(isDropTargeted ? HexaTheme.focusRing : PanelSurface.border(for: colorScheme),
                              lineWidth: isDropTargeted ? 1.2 : 0.8)
        )
    }

    private var fileCard: some View {
        sectioned(l10n.s.mediaSelectFile) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                inputDropTarget

                HStack(spacing: HexaTheme.Spacing.s) {
                    Text(l10n.s.mediaOutput)
                        .font(compact ? .hexa(.micro) : .hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                    Text(outputURL?.lastPathComponent ?? l10n.s.mediaOutputAutomatic)
                        .font(.hexa(.label))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button {
                        chooseOutput()
                    } label: {
                        Label(l10n.s.mediaChooseOutput, hexaIcon: "folder")
                    }
                    .controlSize(.small)
                    .disabled(inputURLs.isEmpty || isRunning)
                }
                if selectedTool == .imageCompressor, inputURLs.count > 1 {
                    Toggle(imageText.saveInSubfolder, isOn: $imageSaveInSubfolder)
                        .toggleStyle(.checkbox)
                        .disabled(isRunning)
                }
            }
        }
    }

    @ViewBuilder
    private var optionsCard: some View {
        sectioned(l10n.s.mediaOutputParamsSection) {
            switch selectedTool {
            case .videoCompressor:
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    timeRangeRow(start: $videoStart, end: $videoEnd)
                    sizingPicker(selection: $videoSizingRaw)
                    if videoSizing == .resolution {
                        compressionRow(value: $videoQuality)
                        stepperInt(l10n.s.mediaMaxSize, value: $videoMaxDimension, range: 640...3840, step: 320, suffix: "px")
                    } else {
                        targetSizeRow(value: $videoTargetMegabytes)
                    }
                }
            case .gifMaker:
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    timeRangeRow(start: $gifStart, end: $gifEnd)
                    sizingPicker(selection: $gifSizingRaw)
                    if gifSizing == .resolution {
                        fpsSliderRow(value: $gifFPS, range: 1...30)
                        HStack(spacing: HexaTheme.Spacing.s) {
                            stepperInt(l10n.s.mediaWidth, value: $gifWidth, range: 160...1600, step: 80, suffix: "px")
                        }
                    } else {
                        targetSizeRow(value: $gifTargetMegabytes)
                    }
                    Toggle(l10n.s.mediaLoopGIF, isOn: $gifLoops)
                        .toggleStyle(.checkbox)
                }
            case .imageCompressor:
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    imageQuickPresetsRow
                    imagePreviewSection
                    HexaSegmentControl(
                        MediaImageFormat.allCases.map { ($0.rawValue, $0.displayName) },
                        selection: $imageFormatRaw
                    )
                    .accessibilityLabel(l10n.s.mediaFormat)
                    compressionRow(value: $imageQuality)
                    imageResizeSection
                    DisclosureHeaderRow(isExpanded: $imageMoreOptionsExpanded) {
                        Text(imageText.moreOptions)
                        Spacer()
                    }
                    if imageMoreOptionsExpanded {
                        // O disclosure separa ajustes de naturezas diferentes em
                        // três subgrupos nomeados; o nível principal acima fica
                        // com a decisão principal (presets, prévia, formato,
                        // qualidade, redimensionamento).
                        VStack(alignment: .leading, spacing: HexaTheme.Spacing.m) {
                            imageOptionsSubgroup(imageText.outputAndMetadataSection) {
                                // PDF output never carries EXIF (the image is re-encoded
                                // into the document), so the toggle would be a dead control.
                                if MediaImageFormat.sanitized(imageFormatRaw) != .pdf {
                                    Toggle(l10n.s.mediaStripMetadata, isOn: $imageStripMetadata)
                                        .toggleStyle(.checkbox)
                                }
                                imageBackgroundSection
                                Toggle(imageText.preserveDate, isOn: $imagePreserveModificationDate)
                                    .toggleStyle(.checkbox)
                            }
                            imageOptionsSubgroup(imageText.watermarkSection) {
                                imageWatermarkSection
                            }
                            imageOptionsSubgroup(imageText.renameAndProfilesSection) {
                                imageRenameSection
                                imageProfileRow
                            }
                        }
                        .padding(.top, HexaTheme.Spacing.xs)
                        .disclosureIndent()
                    }
                }
            case .textExtractor:
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    HexaSegmentControl([
                        (true, l10n.s.mediaOCRAccurate),
                        (false, l10n.s.mediaOCRFast),
                    ], selection: $textAccurate)
                    .accessibilityLabel(l10n.s.mediaOCRMode)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button {
                run()
            } label: {
                Label(actionTitle, hexaIcon: selectedTool == .textExtractor ? "text.viewfinder" : "play.fill")
            }
            .buttonStyle(HexaActionButtonStyle())
            .disabled(inputURLs.isEmpty || isRunning)

            if isRunning {
                Button {
                    media.cancel()
                } label: {
                    Label(l10n.s.mediaCancel, hexaIcon: "xmark")
                }
            }

            Spacer(minLength: 0)

            Text(l10n.s.mediaLocalNote)
                .font(compact ? .hexa(.micro) : .hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
        .controlSize(compact ? .small : .regular)
    }

    @ViewBuilder
    private var statusCard: some View {
        switch media.state {
        case .idle:
            if let localMessage {
                messageCard(localMessage, systemImage: "exclamationmark.triangle.fill", tone: .warning)
            }
        case let .running(progress, _):
            sectioned(l10n.s.mediaRunning) {
                VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
                    HStack {
                        // No workspace o SectionLabel já dá o título; o rótulo
                        // interno é só para o painel compacto.
                        if compact {
                            Label(l10n.s.mediaRunning, hexaIcon: "gearshape.2")
                                .font(.hexa(.label))
                        }
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(compact ? .hexa(.label) : .hexa(.label))
                            .foregroundStyle(HexaTheme.fgSecondary)
                    }
                    ProgressView(value: progress)
                }
            }
        case let .completed(result):
            resultCard(result)
        case let .failed(failure):
            messageCard(message(for: failure), systemImage: "exclamationmark.triangle.fill", tone: .warning)
        case .cancelled:
            messageCard(l10n.s.mediaCancelled, systemImage: "xmark.circle.fill", tone: .neutral)
        }
    }

    private func resultCard(_ result: MediaResult) -> some View {
        sectioned(l10n.s.mediaCompleted) {
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            // No workspace o SectionLabel já dá o título; o rótulo
            // interno é só para o painel compacto.
            if compact {
                Label(l10n.s.mediaCompleted, hexaIcon: "checkmark.circle.fill")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.statusOk)
            }
            if let outputURL = result.outputURL {
                Text(result.imageBatchItems.count > 1 ? batchSummary(result) : String(format: l10n.s.mediaResultSavedFormat, outputURL.lastPathComponent))
                    .font(.hexa(.label))
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(String(format: l10n.s.mediaResultSizeFormat,
                            ByteCountFormatter.string(fromByteCount: result.originalBytes, countStyle: .file),
                            ByteCountFormatter.string(fromByteCount: result.outputBytes, countStyle: .file)))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                if let delta = resultSizeDelta(result) {
                    Text(delta)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                if MediaSupport.outputGrew(originalBytes: result.originalBytes,
                                           outputBytes: result.outputBytes) {
                    Text(l10n.s.mediaResultGrewCaption)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
                if result.failedCount > 0 {
                    Text(result.imageBatchItems.compactMap { item in
                        item.failure.map { "\(item.inputURL.lastPathComponent): \(message(for: $0))" }
                    }.prefix(3).joined(separator: "\n"))
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(3)
                }
            }
            if let text = result.text {
                Text(text.isEmpty ? l10n.s.mediaEmptyText : text)
                    .font(.hexa(.label))
                    .lineLimit(compact ? 5 : 8)
                    .textSelection(.enabled)
                    .padding(HexaTheme.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous).fill(HexaTheme.surfaceInset))
            }
            HStack(spacing: HexaTheme.Spacing.s) {
                if let outputURL = result.outputURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting(result.outputURLs.isEmpty ? [outputURL] : result.outputURLs)
                    } label: {
                        Label(l10n.s.mediaOpenInFinder, hexaIcon: "folder")
                    }
                }
                if let text = result.text {
                    Button {
                        copy(text)
                    } label: {
                        Label(l10n.s.mediaCopyText, hexaIcon: "doc.on.doc")
                    }
                }
                if result.imageBatchItems.count > 1 {
                    Button {
                        copy(batchSummaryText(result))
                    } label: {
                        Label(imageText.copySummary, hexaIcon: "doc.on.doc")
                    }
                }
                Button {
                    run()
                } label: {
                    Label(l10n.s.mediaRunAgain, hexaIcon: "arrow.clockwise")
                }
            }
            .controlSize(.small)
            }
        }
    }

    private func batchSummary(_ result: MediaResult) -> String {
        if result.failedCount > 0 {
            return String(format: imageText.batchPartialFormat, result.processedCount, result.failedCount)
        }
        return String(format: imageText.batchSavedFormat, result.processedCount)
    }

    private func batchSummaryText(_ result: MediaResult) -> String {
        var lines = [String(format: imageText.batchSummaryHeaderFormat, result.processedCount, result.failedCount)]
        if let delta = resultSizeDelta(result) {
            lines.append(delta)
        }
        for item in result.imageBatchItems {
            if let outputURL = item.outputURL {
                lines.append(String(format: imageText.batchSummaryItemFormat,
                                    item.inputURL.lastPathComponent,
                                    outputURL.lastPathComponent))
            } else if let failure = item.failure {
                lines.append("\(item.inputURL.lastPathComponent): \(message(for: failure))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func resultSizeDelta(_ result: MediaResult) -> String? {
        let delta = result.originalBytes - result.outputBytes
        guard delta != 0 else { return nil }
        let formatted = ByteCountFormatter.string(fromByteCount: abs(delta), countStyle: .file)
        if delta > 0 {
            return String(format: imageText.savedBytesFormat, formatted)
        }
        return String(format: imageText.grewBytesFormat, formatted)
    }

    private func messageCard(_ message: String, systemImage: String, tone: HexaStatusNote.Tone) -> some View {
        sectioned(l10n.s.mediaStatusNotice) {
            HexaStatusNote(message: message, icon: systemImage, tone: tone)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Subgrupo nomeado dentro do disclosure da aba Imagem. Usa o rótulo de
    /// grupo da casa (`SectionLabel`) e não cria primitive: o cartão da seção
    /// continua sendo o de `sectioned`.
    @ViewBuilder
    private func imageOptionsSubgroup<Content: View>(_ title: String,
                                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            SectionLabel(title)
            content()
        }
    }

    private var imageProfileRow: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack(spacing: HexaTheme.Spacing.s) {
                Picker(imageText.profile, selection: $imageSelectedProfileID) {
                    Text(imageText.noProfile).tag("")
                    ForEach(imageProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .onChange(of: imageSelectedProfileID) { _, value in
                    guard !value.isEmpty,
                          let profile = imageProfiles.first(where: { $0.id == value }) else { return }
                    applyImageOptions(profile.options)
                }
                HexaIconButton(icon: "trash",
                               label: imageText.deleteProfile,
                               variant: .small,
                               action: deleteSelectedProfile)
                    .disabled(imageSelectedProfileID.isEmpty)
                    .help(imageText.deleteProfile)
            }
            if selectedImageProfile != nil, imageProfileIsModified {
                Label(imageText.profileModified, hexaIcon: "pencil")
                    .font(compact ? .hexa(.micro) : .hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            HStack(spacing: HexaTheme.Spacing.xs) {
                TextField(imageText.profileName, text: $profileName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    updateSelectedProfile()
                } label: {
                    Label(imageText.updateProfile, hexaIcon: "checkmark")
                }
                .controlSize(.small)
                .disabled(imageSelectedProfileID.isEmpty)
                Button {
                    saveNewProfile()
                } label: {
                    Label(imageText.saveAsNew, hexaIcon: "plus")
                }
                .controlSize(.small)
            }
        }
    }

    private var imageQuickPresetsRow: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            Button(imageText.presetWeb) {
                applyImageOptions(MediaImageOptions(quality: MediaCompressionLevel.medium.quality,
                                                    maxDimension: 1600,
                                                    format: .jpeg,
                                                    stripMetadata: true,
                                                    resizeMode: .maxDimension(1600),
                                                    renamePattern: MediaImageRenamePattern("{name}-web")))
            }
            Button(imageText.presetSocial) {
                applyImageOptions(MediaImageOptions(quality: MediaCompressionLevel.low.quality,
                                                    maxDimension: 2048,
                                                    format: .png,
                                                    stripMetadata: true,
                                                    resizeMode: .maxDimension(2048),
                                                    renamePattern: MediaImageRenamePattern("{name}-social")))
            }
            Button(imageText.presetDocs) {
                applyImageOptions(MediaImageOptions(quality: MediaCompressionLevel.medium.quality,
                                                    maxDimension: 1600,
                                                    format: .pdf,
                                                    stripMetadata: true,
                                                    resizeMode: .maxDimension(1600),
                                                    background: .white,
                                                    preserveModificationDate: true))
            }
        }
        .controlSize(.small)
    }

    private var imagePreviewSection: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(previewBackgroundColor)
                if let outputPreview {
                    Image(decorative: outputPreview, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: previewFrameSize.width,
                               height: previewFrameSize.height,
                               alignment: .center)
                } else if inputURL != nil, !previewFinished {
                    // Miniatura pequena: o HexaBusyState não cabe nela sem estourar a moldura.
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(l10n.s.loadingMessage)
                } else {
                    HexaIcons.image("photo", size: compact ? 26 : 32)
                        .foregroundStyle(HexaTheme.fgSecondary)
                }
            }
            .task(id: imagePreviewRequest) {
                guard let url = imagePreviewRequest.inputURL else {
                    media.cancelImagePreview()
                    outputPreview = nil
                    return
                }
                previewFinished = false
                // O serviço cancela o pedido anterior ao receber o próximo.
                media.imagePreview(inputURL: url, options: currentImageOptions) { image in
                    outputPreview = image
                    previewFinished = true
                }
            }
            .onChange(of: inputURL) {
                // A imagem anterior é de outro arquivo; não pode ficar na tela
                // enquanto o render do novo não chega.
                outputPreview = nil
                previewFinished = false
            }
            .frame(width: previewFrameSize.width, height: previewFrameSize.height)
            .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.8)
            )
            // A `Image` é decorativa (fora da árvore de acessibilidade), então o
            // nome da figura fica no contêiner; o texto ao lado sai da árvore
            // para o mesmo conteúdo não ser anunciado duas vezes.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel(outputPreview == nil && inputURL != nil && !previewFinished
                                ? l10n.s.loadingMessage
                                : "\(imageText.preview). \(imageText.outputName): \(previewOutputName)")

            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(imageText.preview)
                    .font(compact ? .hexa(.label) : .hexa(.label))
                Text("\(imageText.outputName): \(previewOutputName)")
                    .font(.hexa(.label))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
    }

    private var imageResizeSection: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            Picker(imageText.resize, selection: $imageResizeKindRaw) {
                Text(imageText.resizeNone).tag(MediaImageResizeKind.none.rawValue)
                Text(imageText.resizeMax).tag(MediaImageResizeKind.maxDimension.rawValue)
                Text(imageText.resizeWidth).tag(MediaImageResizeKind.width.rawValue)
                Text(imageText.resizeHeight).tag(MediaImageResizeKind.height.rawValue)
                Text(imageText.resizeExact).tag(MediaImageResizeKind.exact.rawValue)
            }
            .pickerStyle(.menu)
            switch MediaImageResizeKind.sanitized(imageResizeKindRaw) {
            case .none:
                EmptyView()
            case .maxDimension:
                stepperInt(l10n.s.mediaMaxSize, value: $imageMaxDimension, range: 64...20_000, step: 128, suffix: "px")
            case .width:
                stepperInt(l10n.s.mediaWidth, value: $imageResizeWidth, range: 1...20_000, step: 64, suffix: "px")
            case .height:
                stepperInt(imageText.height, value: $imageResizeHeight, range: 1...20_000, step: 64, suffix: "px")
            case .exact:
                HStack(spacing: HexaTheme.Spacing.s) {
                    stepperInt(l10n.s.mediaWidth, value: $imageResizeWidth, range: 1...20_000, step: 64, suffix: "px")
                    stepperInt(imageText.height, value: $imageResizeHeight, range: 1...20_000, step: 64, suffix: "px")
                }
                HexaSegmentControl([
                    (MediaImageExactResizeMode.stretch.rawValue, imageText.exactStretch),
                    (MediaImageExactResizeMode.fit.rawValue, imageText.exactFit),
                    (MediaImageExactResizeMode.fill.rawValue, imageText.exactFill),
                ], selection: $imageExactResizeModeRaw)
            }
        }
    }

    private var imageWatermarkSection: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            Picker(imageText.watermark, selection: $imageWatermarkKindRaw) {
                Text(imageText.watermarkOff).tag(MediaImageWatermarkKind.off.rawValue)
                Text(imageText.watermarkText).tag(MediaImageWatermarkKind.text.rawValue)
                Text(imageText.watermarkLogo).tag(MediaImageWatermarkKind.logo.rawValue)
                Text(imageText.watermarkBoth).tag(MediaImageWatermarkKind.textAndLogo.rawValue)
            }
            .pickerStyle(.menu)
            if currentWatermarkKind == .text || currentWatermarkKind == .textAndLogo {
                TextField(imageText.watermarkTextPlaceholder, text: $imageWatermarkText)
                    .textFieldStyle(.roundedBorder)
            }
            if currentWatermarkKind == .logo || currentWatermarkKind == .textAndLogo {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Text(imageWatermarkLogoPath.isEmpty ? imageText.noLogo : URL(fileURLWithPath: imageWatermarkLogoPath).lastPathComponent)
                        .font(.hexa(.label))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button {
                        chooseWatermarkLogo()
                    } label: {
                        Label(imageText.chooseLogo, hexaIcon: "photo")
                    }
                    .controlSize(.small)
                    if !imageWatermarkLogoPath.isEmpty {
                        HexaIconButton(icon: "xmark.circle.fill",
                                       label: l10n.s.urlCleanerClearButton,
                                       variant: .small,
                                       action: { imageWatermarkLogoPath = "" })
                    }
                }
            }
            if currentWatermarkKind != .off {
                Picker(imageText.position, selection: $imageWatermarkPositionRaw) {
                    Text(imageText.topLeft).tag(MediaImageWatermarkPosition.topLeft.rawValue)
                    Text(imageText.topRight).tag(MediaImageWatermarkPosition.topRight.rawValue)
                    Text(imageText.center).tag(MediaImageWatermarkPosition.center.rawValue)
                    Text(imageText.bottomLeft).tag(MediaImageWatermarkPosition.bottomLeft.rawValue)
                    Text(imageText.bottomRight).tag(MediaImageWatermarkPosition.bottomRight.rawValue)
                }
                .pickerStyle(.menu)
                stepperDouble(imageText.opacity, value: $imageWatermarkOpacity, range: 0.1...1, step: 0.05, suffix: "%") {
                    "\(Int(($0 * 100).rounded()))"
                }
                stepperInt(imageText.margin, value: $imageWatermarkMargin, range: 0...2000, step: 8, suffix: "px")
                stepperDouble(imageText.scale, value: $imageWatermarkScale, range: 0.05...0.8, step: 0.01, suffix: "%") {
                    "\(Int(($0 * 100).rounded()))"
                }
            }
        }
    }

    private var imageBackgroundSection: some View {
        HexaSegmentControl([
            (MediaImageBackground.transparent.rawValue, imageText.backgroundTransparent),
            (MediaImageBackground.white.rawValue, imageText.backgroundWhite),
            (MediaImageBackground.black.rawValue, imageText.backgroundBlack),
        ], selection: $imageBackgroundRaw)
        .accessibilityLabel(imageText.background)
    }

    private var imageRenameSection: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Text(imageText.rename)
                .font(compact ? .hexa(.label) : .hexa(.label))
            HStack(spacing: HexaTheme.Spacing.xs) {
                TextField("{name}-{index:03}", text: $imageRenamePattern)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    ForEach(Self.imageRenameTokens, id: \.self) { token in
                        Button(token) {
                            imageRenamePattern.append(token)
                        }
                    }
                } label: {
                    Text("{…}")
                        .font(compact ? .hexa(.label) : .hexa(.label))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(imageText.rename)
                .accessibilityLabel(imageText.rename)
            }
        }
    }

    private func timeRangeRow(start: Binding<Double>, end: Binding<Double>) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            numberField(l10n.s.mediaStartTime, value: start, suffix: "s")
            numberField(l10n.s.mediaEndTime, value: end, suffix: "s")
        }
    }

    private var videoSizing: MediaSizingMode {
        MediaSizingMode.sanitized(videoSizingRaw)
    }

    private var videoFPS: Double {
        MediaSupport.sanitizedFPS(videoFPSRaw, fallback: 30, maxFPS: 60)
    }

    private var videoCodec: MediaVideoCodec {
        MediaVideoCodec.sanitized(videoCodecRaw)
    }

    private var gifQuality: Double {
        MediaSupport.sanitizedQuality(gifQualityRaw)
    }

    private var gifSizing: MediaSizingMode {
        MediaSizingMode.sanitized(gifSizingRaw)
    }

    private func sizingPicker(selection: Binding<String>) -> some View {
        HexaSegmentControl([
            (MediaSizingMode.resolution.rawValue, l10n.s.mediaSizingResolution),
            (MediaSizingMode.targetSize.rawValue, l10n.s.mediaSizingFileSize),
        ], selection: selection)
    }

    private func targetSizeRow(value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            integerField(l10n.s.mediaTargetSize,
                         value: value,
                         suffix: l10n.s.mediaMegabytesSuffix)
            Text(l10n.s.mediaTargetSizeHint)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compressionRow(value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            Text(l10n.s.mediaQuality)
                .font(.hexa(.label))
            HexaSegmentControl(
                MediaCompressionLevel.allCases.map { ($0, compressionTitle(for: $0)) },
                selection: compressionLevel(value)
            )
            .accessibilityLabel(l10n.s.mediaQuality)
            Text(compressionDescription(for: MediaCompressionLevel(storedQuality: value.wrappedValue)))
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        // A escala é discreta: normaliza o valor gravado antes dela para o nível
        // que a linha exibe, para rótulo e arquivo medirem a mesma coisa.
        .onAppear {
            value.wrappedValue = MediaCompressionLevel(storedQuality: value.wrappedValue).quality
        }
    }

    /// Seleção do segmento: lê o valor gravado e grava o valor do nível escolhido.
    private func compressionLevel(_ quality: Binding<Double>) -> Binding<MediaCompressionLevel> {
        Binding(
            get: { MediaCompressionLevel(storedQuality: quality.wrappedValue) },
            set: { quality.wrappedValue = $0.quality }
        )
    }

    private func fpsSliderRow(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
            HStack {
                Text(l10n.s.mediaFPS)
                    .font(compact ? .hexa(.label) : .hexa(.label))
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(compact ? .hexa(.label) : .hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            Slider(value: value, in: range, step: 1)
                .accessibilityLabel(l10n.s.mediaFPS)
                .accessibilityValue("\(Int(value.wrappedValue.rounded()))")
        }
    }

    private func numberField(_ label: String, value: Binding<Double>, suffix: String) -> some View {
        numberField(label, suffix: suffix) {
            TextField("", value: value, formatter: Self.decimalFormatter)
        }
    }

    private func integerField(_ label: String, value: Binding<Int>, suffix: String) -> some View {
        // Wider than the trim fields: this label is a phrase in most languages,
        // not a single word.
        numberField(label, suffix: suffix, labelWidth: compact ? 74 : 92) {
            TextField("", value: value, formatter: Self.megabytesFormatter)
        }
    }

    private func numberField<Field: View>(_ label: String,
                                          suffix: String,
                                          labelWidth: CGFloat? = nil,
                                          @ViewBuilder field: () -> Field) -> some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            Text(label)
                .font(compact ? .hexa(.label) : .hexa(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: labelWidth ?? (compact ? 48 : 62), alignment: .leading)
            field()
                .textFieldStyle(.plain)
                .font(compact ? .hexa(.body) : .hexa(.heading))
                .padding(.horizontal, HexaTheme.Spacing.s)
                .frame(width: compact ? 62 : 76, height: compact ? 28 : 30, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(PanelSurface.controlFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.8)
                )
            Text(suffix)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
    }

    private func stepperInt(_ label: String, value: Binding<Int>, range: ClosedRange<Int>,
                            step: Int, suffix: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text(label)
                    .font(compact ? .hexa(.label) : .hexa(.label))
                Spacer(minLength: 0)
                Text("\(value.wrappedValue)\(suffix)")
                    .font(compact ? .hexa(.label) : .hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
    }

    private func stepperDouble(_ label: String,
                               value: Binding<Double>,
                               range: ClosedRange<Double>,
                               step: Double,
                               suffix: String,
                               display: @escaping (Double) -> String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text(label)
                    .font(compact ? .hexa(.label) : .hexa(.label))
                Spacer(minLength: 0)
                Text("\(display(value.wrappedValue))\(suffix)")
                    .font(compact ? .hexa(.label) : .hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
    }

    private var inputTitle: String {
        guard !inputURLs.isEmpty else { return l10n.s.mediaSelectFile }
        if selectedTool == .imageCompressor, inputURLs.count > 1 {
            return String(format: imageText.filesSelectedFormat, inputURLs.count)
        }
        return inputURLs[0].lastPathComponent
    }

    private var currentResizeMode: MediaImageResizeMode {
        MediaImageResizeMode(kind: MediaImageResizeKind.sanitized(imageResizeKindRaw),
                             maxDimension: imageMaxDimension,
                             width: imageResizeWidth,
                             height: imageResizeHeight,
                             exactMode: MediaImageExactResizeMode.sanitized(imageExactResizeModeRaw))
    }

    private var currentWatermarkKind: MediaImageWatermarkKind {
        MediaImageWatermarkKind.sanitized(imageWatermarkKindRaw)
    }

    private var currentWatermark: MediaImageWatermark {
        MediaImageWatermark(kind: currentWatermarkKind,
                            text: imageWatermarkText,
                            logoPath: imageWatermarkLogoPath,
                            position: MediaImageWatermarkPosition.sanitized(imageWatermarkPositionRaw),
                            opacity: imageWatermarkOpacity,
                            margin: imageWatermarkMargin,
                            scale: imageWatermarkScale)
    }

    private var currentImageOptions: MediaImageOptions {
        MediaImageOptions(quality: imageQuality,
                          maxDimension: imageMaxDimension,
                          format: MediaImageFormat.sanitized(imageFormatRaw),
                          stripMetadata: imageStripMetadata,
                          resizeMode: currentResizeMode,
                          watermark: currentWatermark,
                          renamePattern: MediaImageRenamePattern(imageRenamePattern),
                          background: MediaImageBackground.sanitized(imageBackgroundRaw),
                          preserveModificationDate: imagePreserveModificationDate)
    }

    private var imageProfiles: [MediaImageProfile] {
        guard let data = imageProfilesRaw.data(using: .utf8),
              let profiles = try? JSONDecoder().decode([MediaImageProfile].self, from: data) else {
            return []
        }
        return MediaSupport.sanitizedImageProfiles(profiles)
    }

    private var selectedImageProfile: MediaImageProfile? {
        guard !imageSelectedProfileID.isEmpty else { return nil }
        return imageProfiles.first { $0.id == imageSelectedProfileID }
    }

    private var imageProfileIsModified: Bool {
        guard let profile = selectedImageProfile else { return false }
        return profile.options != currentImageOptions
    }

    private var previewOutputName: String {
        guard let inputURL else { return l10n.s.mediaOutputAutomatic }
        if let outputURL { return outputURL.lastPathComponent }
        return defaultOutputURL(for: [inputURL], tool: .imageCompressor)?.lastPathComponent
            ?? l10n.s.mediaOutputAutomatic
    }

    private var previewOutputSize: CGSize {
        guard inputURL != nil, let sourceSize = inputImageSize else {
            return currentResizeMode.targetSize(for: CGSize(width: 1600, height: 1200))
        }
        return currentResizeMode.targetSize(for: sourceSize)
    }

    private var previewFrameSize: CGSize {
        let bounds = CGSize(width: compact ? 108 : 136, height: compact ? 74 : 92)
        let ratio = max(0.01, previewOutputSize.width / previewOutputSize.height)
        if ratio > bounds.width / bounds.height {
            return CGSize(width: bounds.width, height: max(1, bounds.width / ratio))
        }
        return CGSize(width: max(1, bounds.height * ratio), height: bounds.height)
    }

    /// O que muda o desenho da prévia: ela é a saída renderizada pelo serviço,
    /// então só a geometria e a marca d'água pedem um render novo. Qualidade,
    /// metadados e renomear ficam de fora: não mudam a imagem e não podem custar
    /// um render por tecla digitada no padrão de renomear.
    private struct ImagePreviewRequest: Equatable {
        let inputURL: URL?
        let format: MediaImageFormat
        let resizeMode: MediaImageResizeMode
        let watermark: MediaImageWatermark
        let background: MediaImageBackground
    }

    private var imagePreviewRequest: ImagePreviewRequest {
        ImagePreviewRequest(inputURL: inputURL,
                            format: MediaImageFormat.sanitized(imageFormatRaw),
                            resizeMode: currentResizeMode,
                            watermark: currentWatermark,
                            background: MediaImageBackground.sanitized(imageBackgroundRaw))
    }

    private var previewBackgroundColor: Color {
        if MediaImageFormat.sanitized(imageFormatRaw) == .jpeg
            || MediaImageFormat.sanitized(imageFormatRaw) == .pdf {
            return MediaImageBackground.sanitized(imageBackgroundRaw) == .black ? .black : .white
        }
        switch MediaImageBackground.sanitized(imageBackgroundRaw) {
        case .transparent:
            return HexaTheme.fgPrimary.opacity(0.045)
        case .white:
            return .white
        case .black:
            return .black
        }
    }

    private var actionTitle: String {
        switch selectedTool {
        case .videoCompressor: return l10n.s.mediaStartVideo
        case .gifMaker: return l10n.s.mediaStartGIF
        case .imageCompressor:
            // Choosing PDF changes the file's kind, so the button says what
            // will actually happen instead of promising compression.
            return MediaImageFormat.sanitized(imageFormatRaw) == .pdf
                ? l10n.s.mediaStartConvertPDF
                : l10n.s.mediaStartImage
        case .textExtractor: return l10n.s.mediaStartText
        }
    }

    private func compressionDescription(for level: MediaCompressionLevel) -> String {
        switch level {
        case .low: return l10n.s.mediaCompressionLowDescription
        case .medium: return l10n.s.mediaCompressionMediumDescription
        case .high: return l10n.s.mediaCompressionHighDescription
        }
    }

    private func compressionTitle(for level: MediaCompressionLevel) -> String {
        switch level {
        case .low: return l10n.s.mediaCompressionLow
        case .medium: return l10n.s.mediaCompressionMedium
        case .high: return l10n.s.mediaCompressionHigh
        }
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = selectedTool == .imageCompressor
        panel.allowedContentTypes = inputTypes
        Self.runPanelModal(panel) { response in
            // In the island the panel is not modal, so a conversion may have started meanwhile.
            if response == .OK, !isRunning {
                setInputs(panel.urls)
            }
        }
    }

    private func chooseOutput() {
        guard let inputURL else { return }
        if selectedTool == .imageCompressor, inputURLs.count > 1 {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = outputURL ?? inputURL.deletingLastPathComponent()
            Self.runPanelModal(panel) { response in
                if response == .OK, let url = panel.url {
                    outputURL = url
                    outputWasChosenManually = true
                }
            }
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [outputType]
        let fallback = defaultOutputURL(for: inputURLs, tool: selectedTool)
        panel.directoryURL = (outputURL ?? fallback)?.deletingLastPathComponent()
        panel.nameFieldStringValue = (outputURL ?? fallback)?.lastPathComponent ?? ""
        Self.runPanelModal(panel) { response in
            if response == .OK, let url = panel.url {
                outputURL = url
                outputWasChosenManually = true
            }
        }
    }

    /// The hosts of this view (menu popover) never activate
    /// the app, and a modal file dialog in an inactive app takes no clicks or
    /// keys (only Cancel reacts). Activate first and let the run loop turn so
    /// the activation lands before the modal session starts.
    /// One dialog at a time: the modal now starts a run-loop turn after the
    /// click, so a double-click (or clicking both pickers quickly) would queue
    /// a second identical dialog behind the first without this guard.
    /// While it is set, the island keeps its working surface open.
    private(set) static var panelModalActive = false

    private static func runPanelModal(_ panel: NSSavePanel,
                                      completion: @escaping (NSApplication.ModalResponse) -> Void) {
        guard !panelModalActive else { return }
        panelModalActive = true
        if let island = NotchService.shared.presentationWindow, island.isVisible,
           NSApp.currentEvent?.window === island || NSApp.keyWindow === island {
            // The island floats above the modal panel level, so an
            // application-modal dialog would open behind it, and a sheet
            // moves/reskins the borderless island. Open it on its own,
            // just above the island.
            panel.level = NSWindow.Level(rawValue: island.level.rawValue + 1)
            // Like the sheet it replaces, it stays up while another app is active.
            panel.hidesOnDeactivate = false
            panel.begin { response in
                panelModalActive = false
                // Dismissal restores the previous key window after this callback.
                DispatchQueue.main.async { if NotchService.shared.expanded { island.makeKey() } }
                completion(response)
            }
            NSApp.activate(ignoringOtherApps: true)
            // Activation alone can leave the nonactivating island holding focus.
            panel.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            let response = panel.runModal()
            panelModalActive = false
            completion(response)
        }
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty, !isRunning else {
            return false
        }
        let group = DispatchGroup()
        let lock = NSLock()
        var indexedURLs: [(offset: Int, url: URL)] = []
        for (offset, provider) in fileProviders.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let itemURL = item as? URL {
                url = itemURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }
                if let url {
                    lock.lock()
                    indexedURLs.append((offset, url))
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            // A conversion may have started while the providers loaded.
            guard !isRunning else { return }
            let urls = MediaSupport.urlsInProviderOrder(indexedURLs)
            let accepted = urls.filter { url in
                let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                return MediaSupport.inputMatchesTool(contentType: contentType, inputTypes: inputTypes)
            }
            if accepted.isEmpty || (selectedTool != .imageCompressor && accepted.count != urls.count) {
                media.rejectUnsupportedInput()
            } else {
                setInputs(selectedTool == .imageCompressor ? accepted : Array(accepted.prefix(1)))
            }
        }
        return true
    }

    private func setInputs(_ urls: [URL], resetsMedia: Bool = true) {
        inputURLs = selectedTool == .imageCompressor ? urls : Array(urls.prefix(1))
        inputImageSize = selectedTool == .imageCompressor
            ? inputURL.flatMap { MediaSupport.imageDisplaySize(at: $0) }
            : nil
        outputURL = defaultOutputURL(for: inputURLs, tool: selectedTool)
        outputWasChosenManually = false
        applyMediaDefaults(for: inputURL, tool: selectedTool)
        localMessage = nil
        if resetsMedia { media.reset() }
    }

    private func clearInput() {
        mediaDefaultsTask?.cancel()
        workspace.durationLoading.reset()
        inputURLs = []
        inputImageSize = nil
        outputURL = nil
        outputWasChosenManually = false
        localMessage = nil
        media.reset()
    }

    private func applyMediaDefaults(for url: URL?, tool: MediaTool, replacingInput: Bool = true) {
        mediaDefaultsTask?.cancel()
        workspace.durationLoading.cancel()
        if replacingInput {
            workspace.durationLoading.reset()
            // Zero means the full recording until its actual duration arrives.
            // Never leave a previous input's saved trim on a newly chosen file.
            if tool == .videoCompressor { videoStart = 0; videoEnd = 0 }
            else if tool == .gifMaker { gifStart = 0; gifEnd = 0 }
        }
        guard AppFeature.mediaTools.isAvailable,
              let request = workspace.durationLoading.start(url: url, tool: tool) else { return }
        mediaDefaultsTask = Task {
            let duration = await Self.mediaDuration(for: request.url)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard inputURL == request.url, selectedTool == request.tool,
                      AppFeature.mediaTools.isAvailable,
                      let duration = workspace.durationLoading.finish(request, duration: duration) else { return }
                switch tool {
                case .videoCompressor:
                    videoStart = 0
                    videoEnd = duration
                case .gifMaker:
                    gifStart = 0
                    gifEnd = duration
                case .imageCompressor, .textExtractor:
                    break
                }
            }
        }
    }

    private static func mediaDuration(for url: URL) async -> Double? {
        guard let duration = try? await AVURLAsset(url: url).load(.duration).seconds else { return nil }
        guard duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    private func run() {
        guard let inputURL, !inputURLs.isEmpty else {
            localMessage = l10n.s.mediaErrorNoFile
            return
        }
        // Without a destination the user picked, every run takes a free name
        // now, so a repeat never replaces the previous result.
        let outputURL = outputWasChosenManually
            ? outputURL ?? defaultOutputURL(for: inputURLs, tool: selectedTool)
            : defaultOutputURL(for: inputURLs, tool: selectedTool)
        guard let outputURL else {
            localMessage = l10n.s.mediaErrorNoFile
            return
        }
        self.outputURL = outputURL
        localMessage = nil
        switch selectedTool {
        case .videoCompressor:
            media.compressVideo(inputURL: inputURL, outputURL: outputURL,
                                options: MediaVideoOptions(start: videoStart,
                                                           end: videoEnd,
                                                           quality: videoQuality,
                                                           maxDimension: videoMaxDimension,
                                                           fps: videoFPS,
                                                           keepAudio: videoKeepAudio,
                                                           codec: videoCodec,
                                                           sizing: videoSizing,
                                                           targetBytes: MediaSupport.targetBytes(
                                                               megabytes: videoTargetMegabytes)))
        case .gifMaker:
            media.makeGIF(inputURL: inputURL, outputURL: outputURL,
                          options: MediaGIFOptions(start: gifStart,
                                                   end: gifEnd,
                                                   quality: gifQuality,
                                                   width: gifWidth,
                                                   fps: gifFPS,
                                                   loops: gifLoops,
                                                   sizing: gifSizing,
                                                   targetBytes: MediaSupport.targetBytes(
                                                       megabytes: gifTargetMegabytes)))
        case .imageCompressor:
            if inputURLs.count > 1 {
                let outputDirectory = imageSaveInSubfolder
                    ? outputURL.appendingPathComponent(Self.imageOutputSubfolderName,
                                                       isDirectory: true)
                    : outputURL
                media.processImages(inputURLs: inputURLs,
                                    outputDirectory: outputDirectory,
                                    options: currentImageOptions)
            } else {
                media.compressImage(inputURL: inputURL,
                                    outputURL: outputURL,
                                    options: currentImageOptions)
            }
        case .textExtractor:
            media.extractText(inputURL: inputURL, outputURL: outputURL,
                              options: MediaTextOptions(accurate: textAccurate,
                                                        languageCorrection: textLanguageCorrection,
                                                        recognitionLanguages: MediaSupport.recognitionLanguages(for: l10n.language.rawValue)))
        }
    }

    private var inputTypes: [UTType] {
        switch selectedTool {
        case .videoCompressor, .gifMaker:
            return [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        case .imageCompressor, .textExtractor:
            return [.image]
        }
    }

    private var outputType: UTType {
        switch selectedTool {
        case .videoCompressor: return .mpeg4Movie
        case .gifMaker: return .gif
        case .imageCompressor:
            switch MediaImageFormat.sanitized(imageFormatRaw) {
            case .jpeg: return .jpeg
            case .heic: return .heic
            case .png: return .png
            case .pdf: return .pdf
            }
        case .textExtractor: return .plainText
        }
    }

    private func defaultOutputURL(for inputURLs: [URL], tool: MediaTool) -> URL? {
        guard let inputURL = inputURLs.first else { return nil }
        switch tool {
        case .videoCompressor:
            return MediaSupport.uniqueOutputURL(for: inputURL, suffix: "-compressed", fileExtension: "mp4")
        case .gifMaker:
            return MediaSupport.uniqueOutputURL(for: inputURL, suffix: "", fileExtension: "gif")
        case .imageCompressor:
            if inputURLs.count > 1 {
                return inputURL.deletingLastPathComponent()
            }
            let sourceSize = inputImageSize ?? CGSize(width: 1600, height: 1200)
            return MediaSupport.imageOutputURL(for: inputURL,
                                               outputDirectory: inputURL.deletingLastPathComponent(),
                                               options: currentImageOptions,
                                               index: 1,
                                               outputSize: currentResizeMode.targetSize(for: sourceSize))
        case .textExtractor:
            return MediaSupport.uniqueOutputURL(for: inputURL, suffix: "-text", fileExtension: "txt")
        }
    }

    private func message(for failure: MediaFailure) -> String {
        switch failure {
        case .noInput: return l10n.s.mediaErrorNoFile
        case .noVideoTrack: return l10n.s.mediaErrorNoVideo
        case .sameOutput: return l10n.s.mediaErrorSameOutput
        case .unsupported: return l10n.s.mediaErrorUnsupported
        case .imageTooLarge: return imageText.tooLarge
        case let .gifTooLong(maxSeconds):
            return String(format: l10n.s.mediaErrorGIFTooLongFormat,
                          maxSeconds)
        case .targetTooSmall: return l10n.s.mediaErrorTargetTooSmall
        case .watermarkUnavailable: return imageText.noLogo
        case .videoUnreadable: return imageText.videoUnreadable
        case .videoConversionFailed: return imageText.videoConversionFailed
        case .cancelled: return l10n.s.mediaCancelled
        case let .failed(message): return message.isEmpty ? l10n.s.mediaErrorUnsupported : message
        }
    }

    private func chooseWatermarkLogo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        Self.runPanelModal(panel) { response in
            if response == .OK, let url = panel.url {
                imageWatermarkLogoPath = url.path
            }
        }
    }

    private func updateSelectedProfile() {
        var profiles = imageProfiles
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !imageSelectedProfileID.isEmpty,
              let index = profiles.firstIndex(where: { $0.id == imageSelectedProfileID }) else { return }
        let name = trimmed.isEmpty ? profiles[index].name : trimmed
        profiles[index] = MediaImageProfile(id: profiles[index].id, name: name, options: currentImageOptions)
        profileName = ""
        saveImageProfiles(profiles)
    }

    private func saveNewProfile() {
        var profiles = imageProfiles
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(format: imageText.profileDefaultNameFormat, profiles.count + 1) : trimmed
        let profile = MediaImageProfile(name: name, options: currentImageOptions)
        profiles.append(profile)
        imageSelectedProfileID = profile.id
        profileName = ""
        saveImageProfiles(profiles)
    }

    private func deleteSelectedProfile() {
        guard !imageSelectedProfileID.isEmpty else { return }
        var profiles = imageProfiles
        profiles.removeAll { $0.id == imageSelectedProfileID }
        imageSelectedProfileID = ""
        saveImageProfiles(profiles)
    }

    private func saveImageProfiles(_ profiles: [MediaImageProfile]) {
        let cleanProfiles = MediaSupport.sanitizedImageProfiles(profiles)
        guard let data = try? JSONEncoder().encode(cleanProfiles),
              let raw = String(data: data, encoding: .utf8) else { return }
        imageProfilesRaw = raw
    }

    private func applyImageOptions(_ options: MediaImageOptions) {
        // Preset e perfil gravam o nível da escala, não um valor intermediário.
        imageQuality = MediaCompressionLevel(storedQuality: options.quality).quality
        // Older profiles can carry the previously clamped legacy field;
        // resizeMode remains authoritative for the value the user selected.
        imageMaxDimension = options.resizeMode.maxDimension
        imageFormatRaw = options.format.rawValue
        imageStripMetadata = options.stripMetadata
        imageResizeKindRaw = options.resizeMode.kind.rawValue
        imageResizeWidth = options.resizeMode.width
        imageResizeHeight = options.resizeMode.height
        imageExactResizeModeRaw = options.resizeMode.exactMode.rawValue
        imageWatermarkKindRaw = options.watermark.kind.rawValue
        imageWatermarkText = options.watermark.text
        imageWatermarkLogoPath = options.watermark.logoPath
        imageWatermarkPositionRaw = options.watermark.position.rawValue
        imageWatermarkOpacity = options.watermark.opacity
        imageWatermarkMargin = options.watermark.margin
        imageWatermarkScale = options.watermark.scale
        imageRenamePattern = options.renamePattern.rawValue
        imageBackgroundRaw = options.background.rawValue
        imagePreserveModificationDate = options.preserveModificationDate
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// A size target is typed rather than stepped, so the formatter is what
    /// keeps it a whole number the planner can work with.
    private static let megabytesFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = NSNumber(value: MediaSupport.minimumTargetMegabytes)
        formatter.maximum = NSNumber(value: MediaSupport.maximumTargetMegabytes)
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.minimum = 0
        return formatter
    }()
}

extension MediaImageFormat {
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .pdf: return "PDF"
        }
    }
}
