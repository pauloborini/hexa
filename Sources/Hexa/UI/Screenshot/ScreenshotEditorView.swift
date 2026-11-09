// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI
import UniformTypeIdentifiers

/// Screenshot annotation editor with a tool rail, actions, contextual styles
/// and a shared renderer for the canvas and exported image.
struct ScreenshotEditorView: View {
    @ObservedObject var model: ScreenshotEditorModel
    let controller: ScreenshotEditorController
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var keyboard = ScreenshotShortcutContext()

    @State private var editingText = ""
    @FocusState private var textFieldFocused: Bool
    @State private var dragInFlight = false
    @State private var dragStartView: CGPoint = .zero
    @State private var backdropPopoverShown = false
    @State private var watermarkPopoverShown = false
    @State private var hoveredTool: ScreenshotSupport.Tool?
    @State private var toolOptionsShown = false
    @State private var shareAnchor = SharePickerAnchor.Anchor()
    @AppStorage(DefaultsKey.screenshotToolOrder) private var toolOrderRaw =
        ScreenshotSupport.Tool.defaultOrderStorage
    @AppStorage(DefaultsKey.screenshotToolShortcuts) private var bindingsRaw = ""
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var recentCapturesTitle: String {
        FeatureStrings.recentCaptures(l10n.language).title
    }

    var body: some View {
        // Real rows and columns, not overlays: the canvas scrolls in its own
        // region, so zoomed content can never slide under the controls.
        ZStack {
            artboard
            VStack(spacing: 0) {
                topBand
                    .padding(.top, HexaTheme.Spacing.s)
                    .padding(.horizontal, HexaTheme.Spacing.m)
                HStack(spacing: 0) {
                    ScrollView(.vertical) {
                        toolRail
                    }
                    .scrollIndicators(.never)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, HexaTheme.Spacing.s)
                    canvasArea
                }
                .padding(.top, HexaTheme.Spacing.xs)
                bottomRow
                    .padding(.horizontal, HexaTheme.Spacing.m)
                    .padding(.top, HexaTheme.Spacing.xs)
                    .padding(.bottom, HexaTheme.Spacing.s)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: model.tool)
        .animation(.easeOut(duration: 0.16), value: model.annotationShadowsEnabled)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: model.backdropStyle)
        .onAppear { keyboard.start() }
        .onDisappear { keyboard.stop() }
    }

    /// The window's crown: the brand centered like the menu bar panel, the
    /// actions on the right, the trash for a capture not worth keeping.
    private var topBand: some View {
        ZStack {
            BrandMark(width: 40, tint: HexaTheme.fgPrimary)
            HStack {
                Spacer()
                actionCluster
            }
        }
        .frame(height: 38)
    }

    // MARK: - Artboard

    /// Dark canvas surface shared by the editor chrome.
    private var artboard: some View {
        Rectangle()
            .fill(HexaTheme.surfaceBase)
            .overlay {
                LinearGradient(colors: [HexaTheme.fgPrimary.opacity(0.035), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    // MARK: - Canvas

    private var contentPixelSize: CGSize {
        let pad = model.backdropPaddingPixels
        return CGSize(width: model.imageSize.width + pad * 2,
                      height: model.imageSize.height + pad * 2)
    }

    private var canvasArea: some View {
        GeometryReader { proxy in
            let zoom = zoomFactor(available: proxy.size)
            let canvasSize = CGSize(width: contentPixelSize.width * zoom,
                                    height: contentPixelSize.height * zoom)
            ScrollView([.horizontal, .vertical]) {
                canvas(zoom: zoom, canvasSize: canvasSize)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .padding(canvasInsets(available: proxy.size, canvas: canvasSize))
            }
            .scrollIndicators(.never)
            // Trackpad pinch, anchored at the zoom the gesture started from.
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let base = magnifyBase
                            ?? (model.zoomOverride ?? model.currentDisplayZoom)
                        magnifyBase = base
                        model.setZoom(base * value)
                    }
                    .onEnded { _ in magnifyBase = nil }
            )
        }
    }

    @State private var magnifyBase: CGFloat?

    // Margin around the capture inside its scroll region.
    private static let canvasMargin: CGFloat = 14

    private func zoomFactor(available: CGSize) -> CGFloat {
        let zoom: CGFloat
        if let override = model.zoomOverride {
            zoom = override
        } else {
            let width = max(available.width - Self.canvasMargin * 2, 80)
            let height = max(available.height - Self.canvasMargin * 2, 80)
            let fit = min(width / max(contentPixelSize.width, 1),
                          height / max(contentPixelSize.height, 1))
            // Small captures grow to a practical editing size. This affects
            // only the canvas; exported pixels stay untouched.
            zoom = min(fit, 1)
        }
        // Pinch and scroll zoom start from what is actually on screen.
        model.currentDisplayZoom = zoom
        return zoom
    }

    private func canvasInsets(available: CGSize, canvas: CGSize) -> EdgeInsets {
        EdgeInsets(top: max((available.height - canvas.height) / 2, Self.canvasMargin),
                   leading: max((available.width - canvas.width) / 2, Self.canvasMargin),
                   bottom: max((available.height - canvas.height) / 2, Self.canvasMargin),
                   trailing: max((available.width - canvas.width) / 2, Self.canvasMargin))
    }

    private func canvas(zoom: CGFloat, canvasSize: CGSize) -> some View {
        let outerRadius = model.showsBackdrop
            ? 6
            : max(4, model.cardCornerPixels * zoom)
        return ZStack {
            if model.showsBackdrop {
                backdropFillView
                    .scaleEffect(1 + CGFloat(model.backdropStyle.blur) * 0.08)
                    .blur(radius: ScreenshotSupport.backdropBlurRadius(
                        for: contentPixelSize,
                        factor: CGFloat(model.backdropStyle.blur)) * zoom)
            }
            Canvas { context, size in
                context.withCGContext { cg in
                    drawContent(cg, size: size, zoom: zoom)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(HexaTheme.fgPrimary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 24, y: 10)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        .gesture(canvasGesture(zoom: zoom))
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let point = imagePoint(from: location, zoom: zoom)
                if model.tool != .select, model.selectedAnnotationOwns(point) {
                    NSCursor.openHand.set()
                } else if model.tool != .select {
                    NSCursor.crosshair.set()
                } else if model.wordIndex(at: point) != nil {
                    // Recognized text under the cursor reads as text.
                    NSCursor.iBeam.set()
                } else {
                    NSCursor.arrow.set()
                }
            case .ended:
                NSCursor.arrow.set()
            }
        }
        .overlay(alignment: .topLeading) {
            textEditorOverlay(zoom: zoom)
        }
        .overlay(alignment: .topLeading) {
            cropLoupeOverlay(zoom: zoom, canvasSize: canvasSize)
        }
    }

    /// The live backdrop layer, matching exactly what the exporter paints.
    @ViewBuilder
    private var backdropFillView: some View {
        switch model.backdropFill {
        case .none:
            EmptyView()
        case .colors(let components):
            if components.count == 1, let single = components.first {
                Color(.sRGB, red: single.red, green: single.green, blue: single.blue, opacity: 1)
            } else {
                LinearGradient(colors: components.map {
                    Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue, opacity: 1)
                }, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .image(let image):
            // The overlay clips aspect-fill overflow to the backdrop bounds.
            Rectangle()
                .fill(.clear)
                .overlay {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                }
                .clipped()
        }
    }

    private func drawContent(_ cg: CGContext, size: CGSize, zoom: CGFloat) {
        let pad = model.backdropPaddingPixels * zoom
        let imageRect = CGRect(x: pad, y: pad,
                               width: model.imageSize.width * zoom,
                               height: model.imageSize.height * zoom)

        if model.showsBackdrop {
            // The capture sits on the fill like a card: soft shadow and the
            // user's corner rounding, exactly what the exporter composes.
            let corner = model.cardCornerPixels * zoom
            let path = CGPath(roundedRect: imageRect,
                              cornerWidth: corner, cornerHeight: corner, transform: nil)
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -5), blur: 18,
                         color: CGColor(gray: 0, alpha: 0.38))
            cg.addRect(CGRect(origin: .zero, size: size))
            cg.addPath(path)
            cg.clip(using: .evenOdd)
            cg.addPath(path)
            cg.setFillColor(CGColor(gray: 1, alpha: 1))
            cg.fillPath()
            cg.restoreGState()
            cg.saveGState()
            cg.addPath(path)
            cg.clip()
            drawImageUpright(cg, in: imageRect, canvasHeight: size.height)
            cg.restoreGState()
        } else {
            drawImageUpright(cg, in: imageRect, canvasHeight: size.height)
        }

        cg.saveGState()
        cg.scaleBy(x: zoom, y: zoom)
        cg.translateBy(x: model.backdropPaddingPixels, y: model.backdropPaddingPixels)
        if model.showsBackdrop {
            // The exporter composes annotations before the backdrop, so they
            // never spill onto the margin; the live canvas must agree.
            cg.clip(to: CGRect(origin: .zero, size: model.imageSize))
        }
        ScreenshotRenderer.drawAnnotations(model.annotations,
                                           in: cg,
                                           pixelated: model.pixelated,
                                           imageSize: model.imageSize,
                                           scale: model.scale,
                                           annotationShadowsEnabled: model.annotationShadowsEnabled,
                                           skippingText: model.editingTextID)
        ScreenshotRenderer.drawWatermark(model.watermarkStyle,
                                         image: model.watermarkImage,
                                         in: cg,
                                         imageSize: model.imageSize,
                                         scale: model.scale,
                                         shadowsEnabled: model.annotationShadowsEnabled,
                                         cornerRadius: model.cardCornerPixels)
        drawTextSelection(cg)
        drawSelectionChrome(cg)
        drawCropChrome(cg, canvasSize: size, zoom: zoom)
        cg.restoreGState()
    }

    /// Highlight for recognized words selected on the canvas.
    private func drawTextSelection(_ cg: CGContext) {
        guard !model.selectedWordIndexes.isEmpty else { return }
        cg.setFillColor(HexaTheme.selectionBgNSColor.withAlphaComponent(0.32).cgColor)
        for index in model.selectedWordIndexes where model.textWords.indices.contains(index) {
            let rect = model.textWords[index].rect.insetBy(dx: -1.5 * model.scale,
                                                           dy: -1.5 * model.scale)
            let path = CGPath(roundedRect: rect,
                              cornerWidth: 2 * model.scale, cornerHeight: 2 * model.scale,
                              transform: nil)
            cg.addPath(path)
            cg.fillPath()
        }
    }

    private func drawImageUpright(_ cg: CGContext, in rect: CGRect, canvasHeight: CGFloat) {
        cg.saveGState()
        cg.translateBy(x: 0, y: canvasHeight)
        cg.scaleBy(x: 1, y: -1)
        let flipped = CGRect(x: rect.minX,
                             y: canvasHeight - rect.maxY,
                             width: rect.width,
                             height: rect.height)
        cg.draw(model.baseImage, in: flipped)
        cg.restoreGState()
    }

    // MARK: - Gestures

    private func canvasGesture(zoom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = imagePoint(from: value.location, zoom: zoom)
                if !dragInFlight {
                    dragInFlight = true
                    dragStartView = value.location
                    commitEditingTextIfNeeded()
                    model.beginDrag(at: point)
                } else {
                    model.continueDrag(to: point)
                }
            }
            .onEnded { value in
                dragInFlight = false
                let point = imagePoint(from: value.location, zoom: zoom)
                // A click is a click in screen points, whatever the zoom.
                let isTap = hypot(value.location.x - dragStartView.x,
                                  value.location.y - dragStartView.y) < 7
                if isTap, model.tool == .text || model.tool == .sticker || model.tool == .counter,
                   !CGRect(origin: .zero, size: model.imageSize).contains(point) {
                    return
                }
                model.endDrag(at: point, isTap: isTap)
                if model.editingTextID != nil {
                    editingText = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        textFieldFocused = true
                    }
                }
            }
    }

    private func imagePoint(from viewPoint: CGPoint, zoom: CGFloat) -> CGPoint {
        let pad = model.backdropPaddingPixels
        return CGPoint(x: viewPoint.x / zoom - pad, y: viewPoint.y / zoom - pad)
    }

    // MARK: - Crop loupe

    private static let cropLoupeSize: CGFloat = 72

    @ViewBuilder
    private func cropLoupeOverlay(zoom: CGFloat, canvasSize: CGSize) -> some View {
        if let point = model.cropLoupePoint {
            // A crop edge sits between pixels, not on one, so this loupe wants an
            // even sample side to put that edge in the middle of the frame — the
            // opposite of what the capture loupe's color read needs.
            let sourceRect = ScreenshotSupport.cropLoupeSampleRect(
                around: point,
                imageSize: model.imageSize,
                sideLength: 14,
                centredOnPixel: false)
            if let sample = model.baseImage.cropping(to: sourceRect) {
                let size = Self.cropLoupeSize
                let crossX = min(max((point.x - sourceRect.minX) / sourceRect.width * size, 0.5),
                                 size - 0.5)
                let crossY = min(max((point.y - sourceRect.minY) / sourceRect.height * size, 0.5),
                                 size - 0.5)
                ZStack(alignment: .topLeading) {
                    Image(decorative: sample, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: size, height: size)
                    Rectangle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: 1, height: size)
                        .offset(x: crossX - 0.5)
                    Rectangle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: size, height: 1)
                        .offset(y: crossY - 0.5)
                    Circle()
                        .strokeBorder(HexaTheme.fgPrimary, lineWidth: 1)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                        .frame(width: 7, height: 7)
                        .offset(x: crossX - 3.5, y: crossY - 3.5)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(HexaTheme.fgPrimary.opacity(0.9), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                .position(cropLoupePosition(for: point, zoom: zoom, canvasSize: canvasSize))
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private func cropLoupePosition(for point: CGPoint,
                                   zoom: CGFloat,
                                   canvasSize: CGSize) -> CGPoint {
        let size = Self.cropLoupeSize
        let half = size / 2
        let gap: CGFloat = 14
        let pad = model.backdropPaddingPixels
        let anchor = CGPoint(x: (point.x + pad) * zoom,
                             y: (point.y + pad) * zoom)
        var x = anchor.x + half + gap
        var y = anchor.y - half - gap
        if x + half > canvasSize.width { x = anchor.x - half - gap }
        if y - half < 0 { y = anchor.y + half + gap }
        if canvasSize.width >= size {
            x = min(max(x, half), canvasSize.width - half)
        } else {
            x = canvasSize.width / 2
        }
        if canvasSize.height >= size {
            y = min(max(y, half), canvasSize.height - half)
        } else {
            y = canvasSize.height / 2
        }
        return CGPoint(x: x, y: y)
    }

    // MARK: - Selection and crop chrome

    private func drawSelectionChrome(_ cg: CGContext) {
        guard let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return }
        let scale = model.scale
        cg.setStrokeColor(HexaTheme.accentSolidCGColor)
        cg.setLineWidth(1.5 * scale)
        cg.setLineDash(phase: 0, lengths: [4 * scale, 3 * scale])
        if selected.points.count >= 2, selected.tool != .freehand {
            for point in selected.points.prefix(2) {
                cg.setFillColor(CGColor(gray: 1, alpha: 1))
                let handle = CGRect(x: point.x - 4 * scale, y: point.y - 4 * scale,
                                    width: 8 * scale, height: 8 * scale)
                cg.fillEllipse(in: handle)
                cg.strokeEllipse(in: handle)
            }
            return
        }
        let box = selected.tool == .counter
            ? counterBox(selected)
            : selected.rect.insetBy(dx: -3 * scale, dy: -3 * scale)
        cg.stroke(box)
        cg.setLineDash(phase: 0, lengths: [])
        if selected.tool.resizesWithHandles {
            for handle in ScreenshotSupport.Handle.allCases {
                let position = handle.position(in: selected.rect)
                let dot = CGRect(x: position.x - 3.5 * scale, y: position.y - 3.5 * scale,
                                 width: 7 * scale, height: 7 * scale)
                cg.setFillColor(CGColor(gray: 1, alpha: 1))
                cg.fillEllipse(in: dot)
                cg.strokeEllipse(in: dot)
            }
        }
    }

    private func counterBox(_ annotation: ScreenshotSupport.Annotation) -> CGRect {
        let diameter = ScreenshotSupport.counterDiameter(for: model.imageSize, scale: 1)
        return CGRect(x: annotation.rect.midX - diameter / 2,
                      y: annotation.rect.midY - diameter / 2,
                      width: diameter,
                      height: diameter).insetBy(dx: -3, dy: -3)
    }

    private func drawCropChrome(_ cg: CGContext, canvasSize: CGSize, zoom: CGFloat) {
        guard model.tool == .crop, let draft = model.cropDraft else { return }
        let scale = model.scale
        let pad = model.backdropPaddingPixels
        cg.setFillColor(CGColor(gray: 0, alpha: 0.45))
        cg.beginPath()
        cg.addRect(CGRect(x: -pad, y: -pad,
                          width: canvasSize.width / zoom, height: canvasSize.height / zoom))
        cg.addRect(draft)
        cg.fillPath(using: .evenOdd)
        cg.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        cg.setLineWidth(1.5 * scale)
        cg.stroke(draft)
        for handle in ScreenshotSupport.Handle.allCases {
            let position = handle.position(in: draft)
            let radius = 4 * scale
            // A crop grip belongs to the edge itself. Do not push full-image
            // grips inward just to keep the entire circle visible.
            let dot = CGRect(x: position.x - radius, y: position.y - radius,
                             width: 8 * scale, height: 8 * scale)
            cg.setFillColor(CGColor(gray: 1, alpha: 1))
            cg.fillEllipse(in: dot)
        }
    }

    // MARK: - Inline text editing

    @ViewBuilder
    private func textEditorOverlay(zoom: CGFloat) -> some View {
        if let editingID = model.editingTextID,
           let annotation = model.annotations.first(where: { $0.id == editingID }) {
            let fontSize = max(11, ScreenshotRenderer.fontSize(for: annotation.textSize,
                                                               scale: model.scale) * zoom)
            let pad = model.backdropPaddingPixels
            TextField(strings.textPlaceholder, text: $editingText)
                .textFieldStyle(.plain)
                .font(.hexaManrope(size: fontSize, weight: .semibold))
                .foregroundStyle(Color(nsColor: ScreenshotRenderer.nsColor(annotation.color)))
                .focused($textFieldFocused)
                .frame(minWidth: 130)
                .padding(.horizontal, HexaTheme.Spacing.xs)
                .padding(.vertical, HexaTheme.Spacing.xs)
                .background(.black.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(HexaTheme.focusRing, lineWidth: 1)
                )
                .offset(x: (annotation.rect.minX + pad) * zoom - 6,
                        y: (annotation.rect.minY + pad) * zoom - 3)
                .onAppear {
                    editingText = annotation.text
                    DispatchQueue.main.async { textFieldFocused = true }
                }
                .onSubmit {
                    model.commitText(editingID, text: editingText)
                }
                .onExitCommand {
                    model.commitText(editingID, text: editingText)
                }
        }
    }

    private func commitEditingTextIfNeeded() {
        if let editingID = model.editingTextID {
            model.commitText(editingID, text: editingText)
        }
    }

    // MARK: - Tool rail

    private var orderedTools: [ScreenshotSupport.Tool] {
        ScreenshotSupport.Tool.ordered(from: toolOrderRaw)
    }

    private var toolRail: some View {
        VStack(spacing: HexaTheme.Spacing.xs) {
            ForEach(orderedTools, id: \.self) { tool in
                railButton(tool)
            }
            HairlineDivider()
                .frame(width: 22)
                .padding(.vertical, 2)
            Button {
                toolOptionsShown.toggle()
            } label: {
                HexaIcons.image("gearshape.fill", size: 13)
                    .font(.hexa(.body))
                    .frame(width: 33, height: 29)
                    .background(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .fill(toolOptionsShown
                                    ? HexaTheme.selectionBg : .clear)
                    )
                    .foregroundStyle(toolOptionsShown ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                    .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.toolShortcutsTitle)
            .accessibilityLabel(strings.toolShortcutsTitle)
            .popover(isPresented: $toolOptionsShown, arrowEdge: .leading) {
                ScreenshotToolOrderControls(orderRaw: $toolOrderRaw,
                                            shortcutsEnabled: $toolShortcutsEnabled)
                    .padding(HexaTheme.Spacing.m)
                    .frame(width: 340)
            }
        }
        .padding(HexaTheme.Spacing.xs)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                .strokeBorder(HexaTheme.fgPrimary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 5)
    }

    private func railButton(_ tool: ScreenshotSupport.Tool) -> some View {
        let isActive = model.tool == tool
        let isHovered = hoveredTool == tool
        let shortcutLabel = ScreenshotSupport.Tool.shortcutLabel(
            for: tool, orderRaw: toolOrderRaw, bindingsRaw: bindingsRaw, enabled: toolShortcutsEnabled,
            capsLockOn: keyboard.capsLockOn)
        return Button {
            commitEditingTextIfNeeded()
            model.tool = tool
        } label: {
            ZStack(alignment: .topTrailing) {
                HexaIcons.image(tool.screenshotSymbolName, size: 13)
                    .font(.hexa(.body))
                    .animation(.easeOut(duration: 0.15), value: isActive)
                    .frame(width: 33, height: 29)
                if let shortcutLabel {
                    Text(shortcutLabel)
                        .font(.hexa(.micro))
                        .fixedSize()
                        .foregroundStyle(isActive ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
                        .padding(2)
                        .opacity(isHovered || isActive ? 0.9 : 0.55)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                    .fill(isActive
                            ? HexaTheme.selectionBg
                            : isHovered ? HexaTheme.fgPrimary.opacity(0.08) : .clear)
            )
            .foregroundStyle(HexaTheme.fgPrimary)
            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.borderless)
        .onHover { inside in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                hoveredTool = inside ? tool : (hoveredTool == tool ? nil : hoveredTool)
            }
        }
        .screenshotSafeHelp(tool.screenshotTitle(strings)
            + (shortcutLabel.map { "  (\($0))" } ?? ""))
        .accessibilityLabel(tool.screenshotTitle(strings)
            + (shortcutLabel.map { "  (\($0))" } ?? ""))
    }

    // MARK: - QR code (shown only when the capture holds one)

    /// Opens the shared result panel that spells out the code's content, with
    /// copy and open actions.
    private var qrControl: some View {
        Button {
            controller.showQRResult()
        } label: {
            HexaIcons.image("qrcode")
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .tint(HexaTheme.fgSecondary)
        .screenshotSafeHelp(l10n.s.qrResultTitle)
        .accessibilityLabel(l10n.s.qrResultTitle)
    }

    // MARK: - Action cluster (top right)

    private var actionCluster: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            HexaIconButton(
                icon: "clock.arrow.circlepath",
                label: recentCapturesTitle
            ) {
                RecentCaptureService.shared.showHistoryWindow()
            }
            .screenshotSafeHelp(recentCapturesTitle)

            HairlineDivider(vertical: true).frame(height: 16).padding(.horizontal, HexaTheme.Spacing.xs)

            HexaIconButton(
                icon: "trash",
                label: strings.discardConfirm
            ) {
                controller.discardAndClose()
            }
            .screenshotSafeHelp(strings.discardConfirm)

            HairlineDivider(vertical: true).frame(height: 16).padding(.horizontal, HexaTheme.Spacing.xs)

            HexaIconButton(
                icon: "arrow.uturn.backward",
                label: l10n.s.menuUndo
            ) {
                commitEditingTextIfNeeded()
                model.undo()
            }
            .disabled(!model.canUndo)

            HexaIconButton(
                icon: "arrow.uturn.forward",
                label: l10n.s.menuRedo
            ) {
                commitEditingTextIfNeeded()
                model.redo()
            }
            .disabled(!model.canRedo)

            if model.qrReading != nil {
                HairlineDivider(vertical: true).frame(height: 16).padding(.horizontal, HexaTheme.Spacing.xs)
                qrControl
                    .transition(.scale.combined(with: .opacity))
            }

            HairlineDivider(vertical: true).frame(height: 16).padding(.horizontal, HexaTheme.Spacing.xs)

            Button {
                commitEditingTextIfNeeded()
                controller.pin()
            } label: {
                HexaIcons.image("pin")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.pinButton + "  (⌘P)")
            .accessibilityLabel(strings.pinButton)

            HairlineDivider(vertical: true).frame(height: 16).padding(.horizontal, HexaTheme.Spacing.xs)

            Button {
                commitEditingTextIfNeeded()
                guard let url = controller.shareFile() else {
                    NSSound.beep()
                    return
                }
                shareAnchor.present([url]) { chosen in
                    if chosen { model.markExported() }
                }
            } label: {
                HexaIcons.image("square.and.arrow.up")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .background(SharePickerAnchor(anchor: shareAnchor))
            .screenshotSafeHelp(strings.shareButton)
            .accessibilityLabel(strings.shareButton)

            HairlineDivider(vertical: true).frame(height: 16).padding(.horizontal, HexaTheme.Spacing.xs)

            Menu {
                Button(strings.saveButton) {
                    commitEditingTextIfNeeded()
                    controller.save()
                }
                Button(strings.saveAsButton) {
                    commitEditingTextIfNeeded()
                    controller.saveAs()
                }
            } label: {
                Text(strings.saveButton)
            } primaryAction: {
                commitEditingTextIfNeeded()
                controller.save()
            }
            .fixedSize()
            .screenshotSafeHelp("⌘S")

            Button(strings.copyButton) {
                commitEditingTextIfNeeded()
                controller.copyToClipboard()
            }
            .buttonStyle(HexaActionButtonStyle())
            .screenshotSafeHelp("⏎")
        }
        .padding(.horizontal, HexaTheme.Spacing.s)
        .padding(.vertical, HexaTheme.Spacing.xs)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous)
                .strokeBorder(HexaTheme.fgPrimary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 14, y: 4)
    }

    // MARK: - Bottom row

    private var showsColorControls: Bool {
        switch model.tool {
        case .arrow, .line, .rect, .ellipse, .freehand, .highlight, .text, .counter, .redact:
            return true
        case .select:
            guard let selectedID = model.selectedID,
                  let selected = model.annotations.first(where: { $0.id == selectedID })
            else { return false }
            return selected.tool != .sticker
                && selected.tool != .pixelate
        case .sticker, .pixelate, .crop:
            return false
        }
    }

    private var showsBlurControls: Bool {
        if model.tool == .pixelate { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .pixelate
    }

    /// Text takes a point size where shapes take a thickness.
    private var showsTextSizeControls: Bool {
        if model.tool == .text { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .text
    }

    private var showsArrowStyleControls: Bool {
        if model.tool == .arrow { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .arrow
    }

    /// Depth only means something once a shape is picked, and only when there
    /// is something else for it to pass.
    private var showsLayerControls: Bool {
        model.selectedID != nil && model.annotations.count > 1
    }

    /// Each direction dims on its own once the shape reaches that end, so the
    /// buttons never offer a move that would do nothing.
    private func canMoveSelected(_ move: ScreenshotSupport.LayerMove) -> Bool {
        guard let selectedID = model.selectedID else { return false }
        return ScreenshotSupport.canReorder(model.annotations, moving: selectedID, move)
    }

    private func layerButton(_ move: ScreenshotSupport.LayerMove,
                             symbol: String,
                             label: String) -> some View {
        Button {
            commitEditingTextIfNeeded()
            model.moveSelected(move)
        } label: {
            HexaIcons.image(symbol)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .disabled(!canMoveSelected(move))
        .screenshotSafeHelp(label)
        .accessibilityLabel(label)
    }

    private var showsStickerControls: Bool {
        if model.tool == .sticker { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .sticker
    }

    private var bottomRow: some View {
        // One row, no stacking: the chips can never collide with the style
        // bar on a narrow window.
        HStack(alignment: .center, spacing: HexaTheme.Spacing.s) {
            infoChip
            Spacer(minLength: 6)
            if model.tool == .crop, model.cropDraft != nil {
                cropBar
            } else {
                styleBar
            }
            Spacer(minLength: 6)
            zoomChip
        }
    }

    private var styleBar: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            if showsArrowStyleControls {
                arrowStyleMenu
                HairlineDivider(vertical: true).frame(height: 16)
            }
            if showsStickerControls {
                stickerMenu
                HairlineDivider(vertical: true).frame(height: 16)
            }
            if showsBlurControls {
                blurLevelControl
                HairlineDivider(vertical: true).frame(height: 16)
            }
            if showsColorControls {
                HStack(spacing: HexaTheme.Spacing.xs) {
                    ForEach(ScreenshotSupport.ColorID.allCases, id: \.self) { colorID in
                        colorDot(colorID)
                    }
                }
                HairlineDivider(vertical: true).frame(height: 16)
                if showsTextSizeControls {
                    textSizeControl
                } else {
                    HStack(spacing: HexaTheme.Spacing.xs) {
                        ForEach(ScreenshotSupport.StrokeID.allCases, id: \.self) { stroke in
                            strokeGlyph(stroke)
                        }
                    }
                }
                HairlineDivider(vertical: true).frame(height: 16)
            }
            if showsLayerControls {
                layerButton(.backward, symbol: "square.2.layers.3d.bottom.filled",
                            label: strings.sendBackward)
                layerButton(.forward, symbol: "square.2.layers.3d.top.filled",
                            label: strings.bringForward)
                HairlineDivider(vertical: true).frame(height: 16)
            }
            annotationShadowButton
            HairlineDivider(vertical: true).frame(height: 16)
            backdropButton
            HairlineDivider(vertical: true).frame(height: 16)
            watermarkButton
        }
        .padding(.horizontal, HexaTheme.Spacing.m)
        .padding(.vertical, HexaTheme.Spacing.s)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(HexaTheme.fgPrimary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 12, y: 3)
    }

    /// The same kind of menu as the sticker picker: an inline picker gives
    /// each style a native row with a checkmark, and the sample images come
    /// from the editor's own renderer, so the menu shows exactly what draws.
    private var arrowStyleMenu: some View {
        Menu {
            Picker(strings.arrowStyleLabel, selection: $model.arrowStyle) {
                ForEach(ScreenshotSupport.ArrowStyleID.allCases, id: \.self) { style in
                    Label {
                        Text(strings.arrowStyleTitle(style))
                    } icon: {
                        Image(nsImage: ScreenshotArrowStyleSamples.image(for: style))
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Image(nsImage: ScreenshotArrowStyleSamples.image(for: model.arrowStyle))
                    .renderingMode(.template)
                Text(strings.arrowStyleTitle(model.arrowStyle))
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .frame(height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .screenshotSafeHelp(strings.arrowStyleLabel)
        .accessibilityLabel(strings.arrowStyleLabel)
    }

    private var stickerMenu: some View {
        Menu {
            ForEach(ScreenshotSupport.StickerID.allCases, id: \.self) { sticker in
                Button {
                    model.sticker = sticker
                } label: {
                    HStack {
                        Text(sticker.glyph)
                        if model.sticker == sticker {
                            HexaIcons.image("checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Text(model.sticker.glyph)
                    .font(.hexa(.heading))
                Text(strings.toolSticker)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
            .padding(.horizontal, HexaTheme.Spacing.s)
            .frame(height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .screenshotSafeHelp(strings.toolSticker)
        .accessibilityLabel(strings.toolSticker)
    }

    private var cropBar: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            Button(strings.cancel) {
                model.tool = .select
            }
            Button(strings.cropApply) {
                model.applyCrop()
            }
            .buttonStyle(HexaActionButtonStyle())
            .screenshotSafeHelp("⏎")
        }
        .padding(.horizontal, HexaTheme.Spacing.m)
        .padding(.vertical, HexaTheme.Spacing.s)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 3)
    }

    private func colorDot(_ colorID: ScreenshotSupport.ColorID) -> some View {
        let selected = model.color == colorID
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                model.color = colorID
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(nsColor: ScreenshotRenderer.nsColor(colorID)))
                    .frame(width: 17, height: 17)
                    .overlay(
                        Circle().strokeBorder(HexaTheme.fgPrimary.opacity(0.22), lineWidth: 0.5)
                    )
                if selected {
                    Circle()
                        .strokeBorder(HexaTheme.fgPrimary.opacity(0.9), lineWidth: 1.5)
                        .frame(width: 23, height: 23)
                }
            }
            .frame(width: 24, height: 24)
            .scaleEffect(selected ? 1.05 : 1)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(strings.colorLabel)
    }

    /// Line-weight glyphs with three increasing stroke widths.
    private func strokeGlyph(_ stroke: ScreenshotSupport.StrokeID) -> some View {
        let selected = model.stroke == stroke
        let height: CGFloat = switch stroke {
        case .small: 1.8
        case .medium: 3.4
        case .large: 5.4
        }
        return Button {
            model.stroke = stroke
        } label: {
            Capsule()
                .fill(selected ? HexaTheme.fgPrimary : HexaTheme.fgPrimary.opacity(0.6))
                .frame(width: 15, height: height)
                .frame(width: 25, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(selected ? HexaTheme.selectionBg : .clear)
                )
        }
        .buttonStyle(.borderless)
        .screenshotSafeHelp(strings.strokeLabel)
        .accessibilityLabel(strings.strokeLabel)
    }

    /// Smaller and larger buttons step through the presets; the menu jumps
    /// straight to any of them.
    private var textSizeControl: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            textSizeStepButton(up: false)
            Menu {
                Picker(strings.fontSizeLabel, selection: $model.textSize) {
                    ForEach(ScreenshotSupport.textSizes, id: \.self) { size in
                        Text("\(size) pt").tag(size)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text("\(model.textSize) pt")
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
                    .padding(.horizontal, HexaTheme.Spacing.xs)
                    .frame(height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            textSizeStepButton(up: true)
        }
        .screenshotSafeHelp(strings.fontSizeLabel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.fontSizeLabel)
    }

    /// Five steps from a light blur to a heavy one; the middle is the
    /// strength the tool always had.
    private var blurLevelControl: some View {
        let levels = ScreenshotSupport.BlurStrength.levels
        return HStack(spacing: HexaTheme.Spacing.xs) {
            HexaIcons.image("aqi.low", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
            Slider(value: Binding(get: { Double(model.blurLevel) },
                                  set: { model.blurLevel = Int($0.rounded()) }),
                   in: Double(levels.lowerBound)...Double(levels.upperBound),
                   step: 1)
                .controlSize(.mini)
                .frame(width: 84)
            HexaIcons.image("aqi.high", size: 11)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
        }
        .frame(height: 24)
        .screenshotSafeHelp(strings.blurStrengthLabel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strings.blurStrengthLabel)
        .accessibilityValue("\(model.blurLevel)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.blurLevel = min(levels.upperBound, model.blurLevel + 1)
            case .decrement: model.blurLevel = max(levels.lowerBound, model.blurLevel - 1)
            @unknown default: break
            }
        }
    }

    private func textSizeStepButton(up: Bool) -> some View {
        let next = ScreenshotSupport.steppedTextSize(from: model.textSize, up: up)
        return Button {
            if let next { model.textSize = next }
        } label: {
            HexaIcons.image(up ? "textformat.size.larger" : "textformat.size.smaller", size: 13)
                .font(.hexa(.body))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .disabled(next == nil)
        .accessibilityLabel(strings.fontSizeLabel + (up ? " +" : " −"))
    }

    private var annotationShadowButton: some View {
        Button {
            model.annotationShadowsEnabled.toggle()
        } label: {
            HexaIcons.image("circle.lefthalf.filled", size: 13)
                .font(.hexa(.body))
                .frame(width: 25, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .fill(model.annotationShadowsEnabled
                                ? HexaTheme.selectionBg : .clear)
                )
                .foregroundStyle(model.annotationShadowsEnabled
                                    ? HexaTheme.fgPrimary : HexaTheme.fgPrimary.opacity(0.65))
                .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.borderless)
        .screenshotSafeHelp(strings.shadowLabel)
        .accessibilityLabel(strings.shadowLabel)
        .accessibilityAddTraits(model.annotationShadowsEnabled ? .isSelected : [])
    }

    private var backdropButton: some View {
        Button {
            backdropPopoverShown.toggle()
        } label: {
            HStack(spacing: HexaTheme.Spacing.xs) {
                Group {
                    switch model.backdropStyle.sanitized().kind {
                    case .none:
                        HexaIcons.image("sparkles.rectangle.stack", size: 13)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgPrimary)
                    case .image:
                        HexaIcons.image("photo.fill", size: 13)
                            .font(.hexa(.body))
                            .foregroundStyle(HexaTheme.fgPrimary)
                    case .preset, .solid, .gradient:
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .fill(fillPreview(for: model.backdropStyle))
                            .frame(width: 21, height: 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                                    .strokeBorder(HexaTheme.fgPrimary.opacity(0.7), lineWidth: 1)
                            )
                    }
                }
                Text(strings.backdropLabel)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgSecondary)
            }
        }
        .buttonStyle(HexaActionButtonStyle())
        .controlSize(.small)
        .screenshotSafeHelp(strings.backdropLabel)
        .accessibilityLabel(strings.backdropLabel)
        .popover(isPresented: $backdropPopoverShown, arrowEdge: .top) {
            ScreenshotBackdropPopover(model: model)
        }
    }

    private var watermarkButton: some View {
        Button {
            watermarkPopoverShown.toggle()
        } label: {
            HStack(spacing: HexaTheme.Spacing.xs) {
                HexaIcons.image("signature", size: 13)
                    .font(.hexa(.body))
                    .foregroundStyle(HexaTheme.fgPrimary)
                Text(strings.watermarkLabel)
                    .font(.hexa(.label))
                    .foregroundStyle(model.showsWatermark ? HexaTheme.fgPrimary : HexaTheme.fgSecondary)
            }
        }
        .buttonStyle(HexaActionButtonStyle())
        .controlSize(.small)
        .screenshotSafeHelp(strings.watermarkLabel)
        .accessibilityLabel(strings.watermarkLabel)
        .accessibilityAddTraits(model.showsWatermark ? .isSelected : [])
        .popover(isPresented: $watermarkPopoverShown, arrowEdge: .top) {
            ScreenshotWatermarkPopover(model: model)
        }
    }

    private func fillPreview(for style: ScreenshotSupport.BackdropStyle) -> LinearGradient {
        let colors = BackdropPickerAssets.previewColors(for: style)
        return LinearGradient(colors: colors,
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Corner chips

    private var infoChip: some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            dragOutHandle
            Text(dimensionsLabel)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, HexaTheme.Spacing.s)
        .padding(.vertical, HexaTheme.Spacing.xs)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    private var zoomChip: some View {
        HStack(spacing: HexaTheme.Spacing.xs) {
            zoomButton(active: model.zoomOverride == nil, help: "⌘0") {
                HexaIcons.image("arrow.down.right.and.arrow.up.left", size: 11)
                    .font(.hexa(.label))
            } action: {
                model.zoomOverride = nil
            }
            .accessibilityLabel(ScreenshotFeatureStrings.zoomResetAccessibilityLabel(l10n.language))
            Text(zoomPercentLabel)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .frame(minWidth: 38)
                .lineLimit(1)
                .fixedSize()
            zoomButton(active: isActualZoom, help: "⌘1") {
                Text(strings.zoomOneToOne)
                    .font(.hexa(.label))
            } action: {
                model.zoomOverride = 1 / model.scale
            }
        }
        .padding(HexaTheme.Spacing.xs)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .screenshotSafeHelp("⌃ scroll · ⌘+ ⌘-")
    }

    private func zoomButton<Label: View>(active: Bool,
                                         help: String,
                                         @ViewBuilder label: @escaping () -> Label,
                                         action: @escaping () -> Void) -> some View {
        ScreenshotZoomButton(active: active, help: help, label: label, action: action)
    }

    private var isActualZoom: Bool {
        guard let override = model.zoomOverride else { return false }
        return abs(override - 1 / model.scale) < 0.001
    }

    private var zoomPercentLabel: String {
        let zoom = model.zoomOverride ?? model.currentDisplayZoom
        return "\(Int((zoom * model.scale * 100).rounded()))%"
    }

    private var dimensionsLabel: String {
        let width = Int(model.imageSize.width)
        let height = Int(model.imageSize.height)
        let retina = model.scale > 1 ? "  @\(Int(model.scale))x" : ""
        return "\(width) × \(height) px\(retina)"
    }

    /// A draggable control that exports the flattened PNG. Lives in infoChip
    /// (bottom row), not the top toolbar — that region overlaps the
    /// window's real system title bar, where no subview-level override
    /// can reliably stop AppKit from treating a click as "move the
    /// window."
    private var dragOutHandle: some View {
        Label(strings.dragOutHandleLabel, hexaIcon: "arrow.up.doc")
            .labelStyle(.iconOnly)
            .font(.hexa(.label))
            .frame(width: 26, height: 18)
            .contentShape(Rectangle())
            .onDrag {
                commitEditingTextIfNeeded()
                guard let export = model.exportImage(),
                      let provider = ScreenshotService.dragItemProvider(
                          image: export.image,
                          scale: export.scale,
                          strings: strings
                      )
                else { return NSItemProvider() }
                model.markExported()
                return provider
            }
            .screenshotSafeHelp(strings.dragOutHandleLabel)
            .accessibilityLabel(strings.dragOutHandleLabel)
    }
}

private struct ScreenshotZoomButton<Label: View>: View {
    let active: Bool
    let help: String
    @ViewBuilder let label: () -> Label
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 30, height: 20)
                .background(active ? HexaTheme.selectionBg : .clear,
                            in: RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                .foregroundStyle(HexaTheme.fgPrimary)
                .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                        .strokeBorder(isFocused ? HexaTheme.focusRing : .clear, lineWidth: 1.5)
                        .padding(1)
                )
        }
        .buttonStyle(.borderless)
        .focused($isFocused)
        .screenshotSafeHelp(help)
    }
}


extension ScreenshotSupport.Tool {
    var screenshotSymbolName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rect: return "rectangle"
        case .ellipse: return "circle"
        case .freehand: return "scribble.variable"
        case .highlight: return "highlighter"
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .counter: return "1.circle"
        case .pixelate: return "aqi.medium"
        case .redact: return "rectangle.fill"
        case .crop: return "crop"
        }
    }

    func screenshotTitle(_ strings: ScreenshotFeatureStrings) -> String {
        switch self {
        case .select: return strings.toolSelect
        case .arrow: return strings.toolArrow
        case .line: return strings.toolLine
        case .rect: return strings.toolRect
        case .ellipse: return strings.toolEllipse
        case .freehand: return strings.toolFreehand
        case .highlight: return strings.toolHighlight
        case .text: return strings.toolText
        case .sticker: return strings.toolSticker
        case .counter: return strings.toolCounter
        case .pixelate: return strings.toolPixelate
        case .redact: return strings.toolRedact
        case .crop: return strings.toolCrop
        }
    }
}

/// Small samples of each arrow style, drawn by the editor's own renderer so
/// the menu and the toolbar show exactly what a stroke will look like. They
/// are templates, so menus tint them like their text.
private enum ScreenshotArrowStyleSamples {
    private static let images: [ScreenshotSupport.ArrowStyleID: NSImage] = Dictionary(
        uniqueKeysWithValues: ScreenshotSupport.ArrowStyleID.allCases.map { ($0, render($0)) })

    static func image(for style: ScreenshotSupport.ArrowStyleID) -> NSImage {
        images[style] ?? render(style)
    }

    private static func render(_ style: ScreenshotSupport.ArrowStyleID) -> NSImage {
        let size = NSSize(width: 36, height: 16)
        let image = NSImage(size: size)
        image.isTemplate = true
        // Rasterized at 2x so the sample stays crisp on Retina displays.
        let scale: CGFloat = 2
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(pixels.width),
                                            pixelsHigh: Int(pixels.height),
                                            bitsPerSample: 8,
                                            samplesPerPixel: 4,
                                            hasAlpha: true,
                                            isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0,
                                            bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext
        else { return image }
        bitmap.size = size
        // The renderer works in top-down image pixels.
        context.translateBy(x: 0, y: pixels.height)
        context.scaleBy(x: 1, y: -1)
        // A thin sample; the fixed seed keeps the scribbly one stable.
        let sample = ScreenshotSupport.Annotation(
            tool: .arrow,
            points: [CGPoint(x: 3 * scale, y: pixels.height / 2),
                     CGPoint(x: pixels.width - 3 * scale, y: pixels.height / 2)],
            color: .black,
            stroke: .small,
            arrowStyle: style,
            scribbleSeed: 0x5343524942424C59)
        ScreenshotRenderer.drawAnnotations([sample],
                                           in: context,
                                           pixelated: [:],
                                           imageSize: pixels,
                                           scale: scale,
                                           annotationShadowsEnabled: false)
        image.addRepresentation(bitmap)
        return image
    }
}

extension View {
    /// SwiftUI's system tooltip bridge crashes on the current macOS 27 beta
    /// while routing hover events. Keep accessibility labels everywhere and
    /// use native hover help on earlier systems.
    @ViewBuilder
    func screenshotSafeHelp(_ text: String) -> some View {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            self
        } else {
            help(text)
        }
    }
}
