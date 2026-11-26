// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import QuartzCore
import SwiftUI

/// Fluid visual preview overlay for magnetic edge snapping, styled strictly with
/// Hexa's semantic design tokens (`DEC-011`, `DEC-017`). Created lazily on first
/// snap and ordered out immediately when the gesture ends.
final class WindowOverlayController {
    private var panel: OverlayPanel?
    private var hostingView: NSHostingView<WindowSnapOverlaySurface>?
    private var animationGeneration = 0

    func show(frame: CGRect, zoneLabel: String? = nil) {
        animationGeneration += 1
        let panel = ensurePanel()
        hostingView?.rootView = WindowSnapOverlaySurface(zoneLabel: zoneLabel)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if !panel.isVisible {
            panel.setFrame(frame, display: true)
            panel.alphaValue = reduceMotion ? 1 : 0
            panel.orderFrontRegardless()
            guard !reduceMotion else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.11
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            if reduceMotion {
                panel.setFrame(frame, display: true)
                panel.alphaValue = 1
            } else {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().setFrame(frame, display: true)
                    panel.animator().alphaValue = 1
                }
            }
        }
    }

    func hide(immediately: Bool = false) {
        guard let panel, panel.isVisible else { return }
        animationGeneration += 1
        let gen = animationGeneration
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if immediately || reduceMotion {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.09
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            guard let self, let panel, gen == self.animationGeneration else { return }
            panel.orderOut(nil)
        })
    }

    func tearDown() {
        animationGeneration += 1
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    private func ensurePanel() -> OverlayPanel {
        if let panel { return panel }
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .none

        let host = NSHostingView(rootView: WindowSnapOverlaySurface(zoneLabel: nil))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        self.panel = panel
        self.hostingView = host
        return panel
    }
}

private struct WindowSnapOverlaySurface: View {
    let zoneLabel: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HexaTheme.Radius.notch, style: .continuous)
        ZStack {
            shape
                .fill(.regularMaterial)
            shape
                .fill(HexaTheme.surfaceRaised.opacity(colorScheme == .dark ? 0.42 : 0.52))
            shape
                .strokeBorder(HexaTheme.surfaceInset, lineWidth: HexaTheme.hairline * 3)
            shape
                .inset(by: HexaTheme.hairline)
                .strokeBorder(HexaTheme.accentSolid, lineWidth: HexaTheme.hairline)

            if let zoneLabel, !zoneLabel.isEmpty {
                Text(zoneLabel)
                    .font(.hexa(.micro))
                    .foregroundStyle(HexaTheme.fgPrimary)
                    .padding(.horizontal, HexaTheme.Spacing.m)
                    .padding(.vertical, HexaTheme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .fill(HexaTheme.surfaceInset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                            .strokeBorder(HexaTheme.borderHairline, lineWidth: HexaTheme.hairline)
                    )
            }
        }
        .padding(HexaTheme.Spacing.xs)
        .accessibilityHidden(true)
    }
}
