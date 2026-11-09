// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

struct NotchQueueView: View {
    let playback: NotchPlayback
    @ObservedObject private var service = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchMusicExtrasStrings { FeatureStrings.notchMusicExtras(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text.queue).font(.hexa(.body))
                Spacer()
                if service.queueLoading || service.queueActionPending { ProgressView().controlSize(.mini) }
                Button { service.refreshQueue() } label: { HexaIcons.image("arrow.clockwise") }
                    .buttonStyle(.borderless).disabled(service.queueLoading || service.queueActionPending)
                    .help(text.refresh).accessibilityLabel(text.refresh)
            }
            if service.queueActionFailed {
                HexaStatusNote(message: text.actionFailed)
            }
            if let queue = service.upcoming, !service.upcomingRows.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.upcomingRows) { item in
                            HStack(spacing: 10) {
                                NotchArtwork(image: service.upcomingArtwork[item.id], size: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.hexa(.body)).lineLimit(1)
                                    if !item.artist.isEmpty { Text(item.artist).font(.hexa(.label)).foregroundStyle(HexaTheme.fgSecondary).lineLimit(1) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if queue.canPlay {
                                    Button { service.playQueued(item) } label: {
                                        HexaIcons.image("play.fill", size: 11).font(.hexaManrope(size: 11))
                                            .frame(width: 28, height: 28)
                                            .contentShape(RoundedRectangle(cornerRadius: HexaTheme.Radius.notch, style: .continuous))
                                    }
                                    .buttonStyle(NotchButtonStyle(cornerRadius: HexaTheme.Radius.notch))
                                    .disabled(service.queueActionPending || service.upcomingIsHeld)
                                    .help(text.playNow).accessibilityLabel("\(text.playNow): \(item.title)")
                                }
                            }.padding(.vertical, 8)
                        }
                    }
                }
                .notchScrollEdgeFade()
            } else if service.queueLoading {
                HexaBusyState(variant: .compact, message: l10n.s.loadingMessage)
                    .frame(maxHeight: .infinity)
            } else {
                NotchEmptyView(symbol: "list.bullet", message: service.upcoming == nil ? text.queueUnavailable : text.queueEmpty) {
                    NotchPillButton(title: text.openPlayer, prominent: true) { NotchPlayerOpener.open(playback.track) }
                }
            }
        }
        // The title sits as far below the player as the first verse would.
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
