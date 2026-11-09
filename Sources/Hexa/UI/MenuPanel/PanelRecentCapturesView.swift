// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct PanelRecentCapturesView: View {
    var onClose: () -> Void

    var body: some View {
        RecentCapturesView(onClose: onClose)
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
        }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}

/// The same history surface is used by the menu panel and by the floating
/// palette opened from editors and the Command Bar.
struct RecentCapturesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var history = RecentCaptureService.shared
    @Environment(\.notchPresentation) private var inNotch
    /// No workspace a seção do host já traz o rótulo e o cartão: a lista vira
    /// linhas separadas por hairline, sem cabeçalho de painel nem cartão próprio.
    @Environment(\.featureWorkspacePresentation) private var inWorkspace
    @State private var confirmingClear = false

    var onClose: (() -> Void)?
    /// Inside the island the list becomes a rail of cards that fill this
    /// area and continue sideways.
    var notchSize: CGSize? = nil

    private var text: RecentCaptureStrings {
        FeatureStrings.recentCaptures(l10n.language)
    }

    private var visibleEntries: [RecentCaptureEntry] { Self.visible(history.entries) }

    static func visible(_ entries: [RecentCaptureEntry]) -> [RecentCaptureEntry] {
        // The recorder is out of scope; every entry left is a screenshot.
        AppFeature.screenshot.isAvailable ? entries : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HexaTheme.Spacing.s) {
            if notchSize == nil { header }
            content
        }
        .onAppear { history.reload() }
        .confirmationDialog(text.clear,
                            isPresented: $confirmingClear,
                            titleVisibility: .visible) {
            Button(text.clear, role: .destructive) {
                history.clear()
            }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        }
    }

    @ViewBuilder
    private var header: some View {
        if inWorkspace {
            HStack(spacing: HexaTheme.Spacing.s) {
                Spacer(minLength: 0)
                clearButton
            }
        } else {
            HexaPanelHeader(title: text.title, icon: "clock.arrow.circlepath") {
                clearButton
                if let onClose {
                    HexaIconButton(icon: "xmark.circle.fill",
                                   label: l10n.s.uninstallerCancel,
                                   variant: .small,
                                   action: onClose)
                    .help(l10n.s.uninstallerCancel)
                }
            }
        }
    }

    private var clearButton: some View {
        HexaIconButton(icon: "trash",
                       label: text.clear,
                       variant: .small) {
            if inNotch { Self.confirmClearAboveIsland() } else { confirmingClear = true }
        }
        .help(text.clear)
        .disabled(visibleEntries.isEmpty)
    }

    /// The dialog would hang from the island as a sheet; there it asks on its own.
    static func confirmClearAboveIsland() {
        DispatchQueue.main.async {
            let l10n = L10n.shared
            let text = FeatureStrings.recentCaptures(l10n.language)
            guard NSAlert.confirmAboveIsland(text.clear, message: "", action: text.clear, destructive: true,
                                             cancel: l10n.s.uninstallerCancel) else { return }
            RecentCaptureService.shared.clear()
        }
    }

    @ViewBuilder
    private var content: some View {
        if visibleEntries.isEmpty {
            if inWorkspace {
                emptyText
                    .padding(.vertical, HexaTheme.Spacing.s)
            } else {
                emptyText
                    .frame(height: notchSize == nil ? 92 : nil)
                    .frame(maxHeight: notchSize == nil ? nil : .infinity)
                    .panelCard()
            }
        } else if let notchSize {
            let rows = NotchLayout.railRows(count: visibleEntries.count,
                                            perRow: NotchLayout.railCapacity(width: notchSize.width, itemWidth: 236, spacing: HexaTheme.Spacing.s),
                                            rowHeight: 88, spacing: HexaTheme.Spacing.s, height: notchSize.height)
            let cardHeight = (notchSize.height - CGFloat(rows - 1) * 8) / CGFloat(rows)
            NotchRail(items: visibleEntries, rows: rows, itemWidth: 236, width: notchSize.width) { entry in
                row(entry).frame(height: cardHeight)
            }
        } else {
            // Lista plana: a rolagem acontece no nível da tela hospedeira
            // (workspace, painel do menu), fora do elemento.
            LazyVStack(alignment: .leading, spacing: inWorkspace ? 0 : HexaTheme.Spacing.s) {
                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                    if inWorkspace, index > 0 { HairlineDivider() }
                    row(entry)
                }
            }
        }
    }

    private var emptyText: some View {
        Text(text.empty)
            .font(.hexa(.label))
            .foregroundStyle(HexaTheme.fgTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func row(_ entry: RecentCaptureEntry) -> some View {
        HStack(spacing: HexaTheme.Spacing.s) {
            preview(entry)
            VStack(alignment: .leading, spacing: HexaTheme.Spacing.xs) {
                Text(entry.kind == .screenshot ? text.screenshot : text.recording)
                    .font(.hexa(.label))
                if entry.kind == .recording, let name = entry.recordingURL?.lastPathComponent {
                    Text(name)
                        .font(.hexa(.label))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(entry.createdAt, style: .relative)
                    .font(.hexa(.label))
                    .foregroundStyle(HexaTheme.fgTertiary)
                HStack(spacing: HexaTheme.Spacing.xs) {
                    Button(entry.kind == .screenshot ? text.restore : text.open) {
                        history.open(entry)
                    }
                    .buttonStyle(HexaActionButtonStyle())
                    .controlSize(.mini)
                    HexaIconButton(
                        icon: "trash",
                        label: text.remove,
                        variant: .small
                    ) {
                        history.remove(entry)
                    }
                    .help(text.remove)
                }
            }
            Spacer(minLength: 0)
        }
        .modifier(RecentRowSurface(inWorkspace: inWorkspace))
    }

    @ViewBuilder
    private func preview(_ entry: RecentCaptureEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .fill(HexaTheme.surfaceInset)
            if let image = history.thumbnail(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous))
            } else {
                HexaIcons.image(entry.kind == .screenshot ? "photo" : "film", size: 20)
                    .foregroundStyle(HexaTheme.fgTertiary)
            }
        }
        .frame(width: 104, height: 68)
        .overlay(
            RoundedRectangle(cornerRadius: HexaTheme.Radius.control, style: .continuous)
                .strokeBorder(HexaTheme.borderHairline, lineWidth: 1)
        )
    }
}

/// Linha da lista: cartão próprio no painel e na paleta; no workspace, a linha
/// só ganha respiro vertical dentro do cartão da seção.
private struct RecentRowSurface: ViewModifier {
    let inWorkspace: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if inWorkspace {
            content.padding(.vertical, HexaTheme.Spacing.s)
        } else {
            content.panelCard()
        }
    }
}

/// Borderless palette content. Its compact fixed width keeps the same list
/// readable over either editor without covering the work area.
struct RecentCapturesWindowView: View {
    var onClose: () -> Void

    var body: some View {
        OverlayScrollView {
            RecentCapturesView(onClose: onClose)
        }
        .frame(maxHeight: 300)
        .padding(HexaTheme.Spacing.m)
        .frame(width: 440)
        .background(HUDBackdrop(cornerRadius: HexaTheme.Radius.panel, contrast: .high))
        .clipShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.panel, style: .continuous))
    }
}
