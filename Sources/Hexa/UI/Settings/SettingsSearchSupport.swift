// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

// MARK: - Window Support

/// Geometria da janela compartilhada: largura fixa e altura expansível,
/// limitadas pela área útil da tela corrente.
enum SettingsWindowSupport {
    static var minContentWidth: Double { Double(FeatureWorkspaceMetrics.minWidth) }
    static var minContentHeight: Double { Double(FeatureWorkspaceMetrics.minHeight) }

    static func isValidContentSize(width: Double, height: Double) -> Bool {
        width == minContentWidth && height.isFinite && height >= minContentHeight
    }

    /// Área útil utilizável como limite: positiva e finita nas duas dimensões.
    private static func isUsableArea(_ area: CGSize) -> Bool {
        area.width.isFinite && area.width > 0 && area.height.isFinite && area.height > 0
    }

    /// Larguras antigas não são restauradas. A altura salva vale quando a tela
    /// comporta e é truncada pela área útil quando não comporta; a preferência
    /// salva nunca é regravada por esse truncamento.
    static func initialContentSize(savedHeight: Double, availableArea: CGSize) -> CGSize {
        let preferredHeight = savedHeight.isFinite && savedHeight > 0
            ? max(savedHeight, minContentHeight) : Double(FeatureWorkspaceMetrics.height)
        guard isUsableArea(availableArea) else {
            return CGSize(width: minContentWidth, height: preferredHeight)
        }
        return CGSize(width: min(minContentWidth, Double(availableArea.width)),
                      height: min(preferredHeight, Double(availableArea.height)))
    }

    /// Limites de redimensionamento pela área útil da tela. Área ausente ou
    /// degenerada mantém os limites de fábrica (largura travada, altura livre).
    static func contentSizeLimits(availableArea: CGSize) -> (min: NSSize, max: NSSize) {
        let factory = NSSize(width: minContentWidth, height: minContentHeight)
        guard isUsableArea(availableArea) else {
            return (factory, NSSize(width: factory.width, height: .greatestFiniteMagnitude))
        }
        let width = min(minContentWidth, Double(availableArea.width))
        let height = Double(availableArea.height)
        return (NSSize(width: width, height: min(minContentHeight, height)),
                NSSize(width: width, height: height))
    }

    /// Reencaixa o frame da janela na área útil: tamanho truncado e origem
    /// contida. Área degenerada devolve o frame de entrada.
    static func fittedFrame(frame: CGRect, visibleFrame: CGRect) -> CGRect {
        guard isUsableArea(visibleFrame.size) else { return frame }
        var result = frame
        result.size.width = min(frame.width, visibleFrame.width)
        result.size.height = min(frame.height, visibleFrame.height)
        result.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - result.width)
        result.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - result.height)
        return result
    }

    /// Keep both full presentations intact. Small displays use a movable cascade
    /// rather than squeezing content or pushing a window outside the work area.
    static func tourPlacement(settingsSize: CGSize, tourSize: CGSize,
                              visibleFrame: CGRect) -> (settings: CGRect, tour: CGRect) {
        let area = visibleFrame.insetBy(dx: 20, dy: 20)
        let gap: CGFloat = 16
        var settings = CGRect(origin: area.origin, size: settingsSize)
        var tour = CGRect(origin: area.origin, size: tourSize)
        if settings.width + gap + tour.width <= area.width {
            settings.origin.x = area.midX - (settings.width + gap + tour.width) / 2
            tour.origin.x = settings.maxX + gap
            settings.origin.y = area.midY - settings.height / 2
            tour.origin.y = area.midY - tour.height / 2
        } else if settings.height + gap + tour.height <= area.height {
            settings.origin.y = area.midY - (settings.height + gap + tour.height) / 2
            tour.origin.y = settings.maxY + gap
            settings.origin.x = area.midX - settings.width / 2
            tour.origin.x = area.midX - tour.width / 2
        } else {
            tour.origin.x = area.maxX - tour.width
            tour.origin.y = area.maxY - tour.height
        }
        func contained(_ frame: CGRect) -> CGRect {
            var result = frame
            result.origin.x = max(area.minX, min(frame.minX, area.maxX - frame.width))
            result.origin.y = min(max(area.minY, frame.minY), area.maxY - frame.height)
            return result
        }
        return (contained(settings), contained(tour))
    }

    static func panelPlacement(preferredFrame: CGRect,
                               panelFrame: CGRect,
                               visibleFrame: CGRect) -> (frame: CGRect, closesPanel: Bool) {
        let avoidedFrame = frame(preferredFrame, avoiding: panelFrame, in: visibleFrame)
        let closesPanel = avoidedFrame.intersects(panelFrame)
        return (closesPanel ? clamped(preferredFrame, to: visibleFrame) : avoidedFrame,
                closesPanel)
    }

    private static func frame(_ frame: CGRect, avoiding panelFrame: CGRect,
                              in visibleFrame: CGRect) -> CGRect {
        let gap: CGFloat = 28
        let margin: CGFloat = 20
        var adjusted = frame

        let leftX = panelFrame.minX - gap - frame.width
        let rightX = panelFrame.maxX + gap
        if panelFrame.midX >= visibleFrame.midX, leftX >= visibleFrame.minX + margin {
            adjusted.origin.x = min(frame.origin.x, leftX)
        } else if panelFrame.midX < visibleFrame.midX,
                  rightX + frame.width <= visibleFrame.maxX - margin {
            adjusted.origin.x = max(frame.origin.x, rightX)
        } else {
            let belowY = panelFrame.minY - gap - frame.height
            let aboveY = panelFrame.maxY + gap
            if belowY >= visibleFrame.minY + margin {
                adjusted.origin.y = min(frame.origin.y, belowY)
            } else if aboveY + frame.height <= visibleFrame.maxY - margin {
                adjusted.origin.y = max(frame.origin.y, aboveY)
            }
        }

        return clamped(adjusted, to: visibleFrame)
    }

    private static func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let margin: CGFloat = 20
        var clamped = frame
        clamped.origin.x = min(max(clamped.origin.x, visibleFrame.minX + margin),
                               visibleFrame.maxX - frame.width - margin)
        clamped.origin.y = min(max(clamped.origin.y, visibleFrame.minY + margin),
                               visibleFrame.maxY - frame.height - margin)
        return clamped
    }
}
