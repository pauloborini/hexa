// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import SwiftUI

/// The "apps this feature treats differently" block a Settings page carries:
/// a disclosure row with a count, one line per app with its icon and a minus
/// button, an add button that opens the app picker, and a caption underneath.
///
/// Pages differ only in where the list is kept, what a row shows next to
/// the name and which apps the picker offers, so that is what they pass in.
/// It stays a single quiet row while nothing is listed and comes up open when
/// the feature already has entries, so a page with several of these never
/// turns into a wall of lists.
struct AppBundleList<Accessory: View>: View {
    let title: String
    let caption: String
    let addTitle: String
    let removeLabel: String
    /// The listed bundle identifiers in any order; rows are sorted by name.
    let bundleIDs: [String]
    /// Whether the picker reaches every app instead of only the installed
    /// ones: it browses Applications and offers what is running as well.
    let reachesEveryApp: Bool
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void
    let accessory: (String) -> Accessory

    @State private var isExpanded: Bool
    @State private var showingAppPicker = false

    init(title: String,
         caption: String,
         addTitle: String,
         removeLabel: String,
         bundleIDs: [String],
         reachesEveryApp: Bool = false,
         onAdd: @escaping (String) -> Void,
         onRemove: @escaping (String) -> Void,
         @ViewBuilder accessory: @escaping (String) -> Accessory) {
        self.title = title
        self.caption = caption
        self.addTitle = addTitle
        self.removeLabel = removeLabel
        self.bundleIDs = bundleIDs
        self.reachesEveryApp = reachesEveryApp
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.accessory = accessory
        _isExpanded = State(initialValue: !bundleIDs.isEmpty)
    }

    var body: some View {
        HexaDisclosure(isExpanded: $isExpanded) {
            HStack {
                Text(title)
                    .font(.hexa(.body))
                Spacer()
                if !bundleIDs.isEmpty {
                    Text("\(bundleIDs.count)")
                        .font(.hexa(.data))
                        .foregroundStyle(HexaTheme.fgSecondary)
                        .monospacedDigit()
                }
            }
        } content: {
            ForEach(sortedBundleIDs, id: \.self) { bundleID in
                HexaListItem(
                    nsImage: InstalledApps.icon(for: bundleID),
                    title: InstalledApps.name(for: bundleID),
                    accessory: {
                        HStack(spacing: HexaTheme.Spacing.s) {
                            accessory(bundleID)
                            HexaIconButton(icon: "minus.circle.fill",
                                           label: removeLabel,
                                           variant: .small) {
                                onRemove(bundleID)
                            }
                        }
                    }
                )
            }


            Button {
                showingAppPicker = true
            } label: {
                Label(addTitle, hexaIcon: "plus")
            }
            .buttonStyle(HexaActionButtonStyle())
            .controlSize(.small)
            // Rows inside a disclosure group center themselves; the button
            // belongs under the list it adds to.
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(caption)
                .font(.hexa(.label))
                .foregroundStyle(HexaTheme.fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingAppPicker) {
            appPickerSheet
        }
    }

    private var sortedBundleIDs: [String] {
        bundleIDs.sorted {
            let byName = InstalledApps.name(for: $0)
                .localizedCaseInsensitiveCompare(InstalledApps.name(for: $1))
            // Equal display names fall back to the identity so the rows hold
            // one order between renders.
            return byName == .orderedSame ? $0 < $1 : byName == .orderedAscending
        }
    }

    private var appPickerSheet: some View {
        let listed = Set(bundleIDs)
        return AppPickerView(canBrowseApplications: reachesEveryApp) {
            showingAppPicker = false
        } onSelect: { _ in
            showingAppPicker = false
        } onSelectApp: { app in
            showingAppPicker = false
            guard let identity = app.identity else { return }
            onAdd(identity)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: listed,
                                                      includeRunningApplications: reachesEveryApp)
        }
    }
}

extension AppBundleList where Accessory == EmptyView {
    init(title: String,
         caption: String,
         addTitle: String,
         removeLabel: String,
         bundleIDs: [String],
         reachesEveryApp: Bool = false,
         onAdd: @escaping (String) -> Void,
         onRemove: @escaping (String) -> Void) {
        self.init(title: title,
                  caption: caption,
                  addTitle: addTitle,
                  removeLabel: removeLabel,
                  bundleIDs: bundleIDs,
                  reachesEveryApp: reachesEveryApp,
                  onAdd: onAdd,
                  onRemove: onRemove,
                  accessory: { _ in EmptyView() })
    }
}
