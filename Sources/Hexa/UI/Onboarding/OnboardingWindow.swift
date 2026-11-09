// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import SwiftUI

/// O que a tela de boas-vindas retém enquanto está na tela: a retenção da
/// política de ativação, a supressão do cartão flutuante de permissão e a
/// demanda de sondagem do passo de permissões. Vive fora da janela para que o
/// balanço do fechamento seja verificável sem AppKit.
final class OnboardingWindowSession {
    /// A demanda de sondagem do passo de permissões, a mesma que o modelo do
    /// roteiro carrega. O fechamento a libera mesmo quando o passo não liberou.
    let permissionDemandID: UUID
    private let releasePermissionDemand: (UUID) -> Void
    private(set) var isOpen = false

    init(permissionDemandID: UUID = UUID(),
         releasePermissionDemand: @escaping (UUID) -> Void = {
             Permissions.shared.setActivePermissionSurface($0, visible: false)
         }) {
        self.permissionDemandID = permissionDemandID
        self.releasePermissionDemand = releasePermissionDemand
    }

    deinit {
        end()
    }

    func begin() {
        guard !isOpen else { return }
        isOpen = true
        WindowActivationPolicy.retain()
        PermissionGuideOverlay.suppressed = true
    }

    /// Ordem do fechamento: a demanda de permissão, o cartão flutuante e a
    /// política de ativação. Idempotente: fechar duas vezes não devolve duas
    /// vezes o que outra dono ainda mantém.
    func end() {
        guard isOpen else { return }
        isOpen = false
        releasePermissionDemand(permissionDemandID)
        PermissionGuideOverlay.suppressed = false
        WindowActivationPolicy.release()
    }
}

/// A janela própria do hexa para a primeira execução: janela normal, não modal
/// (o app continua utilizável durante o roteiro), dona da política de ativação
/// enquanto existe e de nada depois que fecha.
final class OnboardingWindow: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindow()

    private var window: NSWindow?
    private var session: OnboardingWindowSession?
    var presentationWindow: NSWindow? { window }

    /// Abre a tela no primeiro passo (primeira execução) ou na reexecução do
    /// roteiro. O marcador é lido pelo modelo, nunca por esta camada.
    func show(isRedoing: Bool = false) {
        // Reabrir sem fechar devolve primeiro o que a sessão anterior retinha,
        // para o balanço da política e da demanda não dobrar.
        session?.end()

        let model = OnboardingModel(isRedoing: isRedoing)
        let session = OnboardingWindowSession(permissionDemandID: model.permissionDemandID)
        self.session = session
        session.begin()

        let size = Self.contentSize()
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        let host = NSHostingView(rootView: OnboardingView(model: model) { [weak self] in
            self?.close()
        })
        host.sizingOptions = []
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        let window = self.window ?? makeWindow()
        self.window = window
        window.contentView = container
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        session?.end()
        session = nil
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let size = Self.contentSize()
        let visible = NSScreen.main?.visibleFrame.size ?? .zero
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "hexa"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.contentMinSize = size
        window.contentMaxSize = NSSize(width: visible.width > 0
                                       ? max(size.width, min(OnboardingMetrics.windowWidth, visible.width))
                                       : OnboardingMetrics.windowWidth,
                                       height: visible.height > 0 ? max(size.height, visible.height) : size.height)
        window.delegate = self
        window.center()
        return window
    }

    /// Geometria derivada dos tokens de layout do app: proporção widescreen
    /// com palco de marca e conteúdo da tela operacional.
    private static func contentSize() -> NSSize {
        let width = OnboardingMetrics.windowWidth
        let visible = NSScreen.main?.visibleFrame.size ?? .zero
        let height = visible.height > 0
            ? min(OnboardingMetrics.windowHeight, visible.height)
            : OnboardingMetrics.windowHeight
        return NSSize(width: width, height: height)
    }
}
