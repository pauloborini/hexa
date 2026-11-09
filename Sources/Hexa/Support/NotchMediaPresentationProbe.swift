// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

#if HEXA_DEVELOPMENT
import AppKit
import SwiftUI
import QuartzCore
import Darwin

/// Runs the real media view and window compositor in an invisible, isolated
/// fixture. Cocoa actions stay within its controls; no system input is posted.
enum NotchMediaPresentationProbe {
    private final class Model: ObservableObject {
        let geometry: NotchGeometry
        let defaults: UserDefaults
        let media = MediaService(replacesExistingOutputs: false)
        let workspace = MediaWorkspaceSelection()
        @Published var height: CGFloat?
        weak var host: NotchWindowHost?
        var trace: [String] = []
        var backingTooSmall = false

        init(geometry: NotchGeometry, defaults: UserDefaults) {
            self.geometry = geometry
            self.defaults = defaults
        }

        var size: CGSize { geometry.expandedSize(module: .files, fileMediaHeight: height) }

        func measured(_ value: CGFloat) {
            guard value.isFinite, value > 0, height != ceil(value) else { return }
            height = ceil(value)
            trace.append("measure:\(Int(value))")
            host?.present(size: size, geometry: geometry, animated: true)
            if let host {
                trace.append("canvas:\(Int(host.contentCanvasSize.height))/\(Int(size.height))")
                if host.contentCanvasSize.height + 0.5 < size.height { backingTooSmall = true }
            }
        }

        func willChange() {
            trace.append("tool")
            host?.present(size: size, geometry: geometry, animated: true, transitionContent: .replace)
        }

        func select(tool: MediaTool) {
            willChange()
            workspace.tool = tool
        }

        func syncPreferences() {
            trace.append("preferences")
            host?.present(size: size, geometry: geometry, animated: false)
        }
    }

    private struct Content: View {
        @ObservedObject var model: Model

        var body: some View {
            VStack(spacing: NotchLayout.spacing) {
                Text("Files").frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: model.geometry.headerRowHeight)
                MediaWorkspaceView(compact: true, media: model.media, initialTool: .videoCompressor,
                                   preservesServiceState: true, workspace: model.workspace,
                                   onContentHeightChange: model.measured, onToolChange: model.willChange)
            }
            .padding(.horizontal, NotchLayout.horizontalInset)
            .padding(.top, model.geometry.headerTopInset)
            .padding(.bottom, NotchLayout.bottomInset)
            .frame(width: model.size.width, height: model.size.height, alignment: .top)
            .background(.black).foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
            .environment(\.notchPresentation, true)
            .defaultAppStorage(model.defaults)
        }
    }

    static func runAndExit() -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        guard let screen = NSScreen.main else { print("MEDIA MOTION FAILED: no display"); exit(1) }
        let lockPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Preferences/.hexa-defaults-media-motion.lock")
        let lockFD = open(lockPath, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        precondition(lockFD >= 0, "Não foi possível abrir o lock de defaults")
        var lockResult: Int32
        repeat { lockResult = flock(lockFD, LOCK_EX) } while lockResult == -1 && errno == EINTR
        precondition(lockResult == 0, "Não foi possível adquirir o lock de defaults")
        let domain = "com.hexa.tests.media-motion"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defaults.register(defaults: Defaults.registeredDefaults)
        let geometry = NotchGeometry(screen: screen.frame, safeAreaTop: 32, cameraWidth: 180, layout: .spacious)
        let model = Model(geometry: geometry, defaults: defaults)
        let host = NotchWindowHost(content: AnyView(Content(model: model)), geometry: geometry, size: model.size)
        model.host = host
        host.panel.alphaValue = 0
        host.panel.ignoresMouseEvents = true
        host.panel.orderFrontRegardless()
        let observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                               object: nil, queue: .main) { _ in
            DispatchQueue.main.async { model.syncPreferences() }
        }
        func advance(_ seconds: TimeInterval) {
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline { RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.008))) }
        }
        advance(1)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var failures: [String] = []
        let backing = NotchWindowHost(content: AnyView(Color.black), geometry: geometry,
                                      size: CGSize(width: geometry.expanded.width, height: 300))
        backing.panel.alphaValue = 0
        backing.panel.ignoresMouseEvents = true
        backing.panel.orderFrontRegardless()
        backing.present(size: CGSize(width: geometry.expanded.width, height: 300), geometry: geometry,
                        animated: false)
        advance(0.1)
        for height: CGFloat in [620, 320, 520] {
            let from = backing.visibleFrame.height
            let target = CGSize(width: geometry.expanded.width, height: height)
            let ready = backing.probePresentDuringLayout(size: target, geometry: geometry)
            var intermediate = 0
            let began = CACurrentMediaTime()
            while CACurrentMediaTime() - began < 0.8 {
                advance(0.008)
                let drawn = min(backing.visibleFrame.height, backing.contentCanvasSize.height)
                if drawn > min(from, height) + 1, drawn < max(from, height) - 1 { intermediate += 1 }
            }
            if !ready { failures.append("layout resize \(Int(height)) did not reserve its drawing area") }
            if !reduceMotion, intermediate < 3 { failures.append("layout resize \(Int(height)) has no visible intermediate frames") }
            print("MEDIA BACKING from=\(Int(from)) to=\(Int(height)) reserved=\(ready) intermediate=\(intermediate)")
        }
        // A present made from inside AppKit layout cannot flush the layer tree,
        // so the frame probe reads stale there; that must not pass for
        // Mission Control and order the island out on the desktop.
        if backing.concealedFrameChanges != 0 {
            failures.append("layout resizes concealed the island \(backing.concealedFrameChanges) times outside Mission Control")
        }
        backing.close()
        for index in [3, 2, 1, 0, 2, 3] {
            let from = host.visibleFrame.height
            model.trace = []
            model.backingTooSmall = false
            model.select(tool: MediaTool.allCases[index])
            var samples: [CGFloat] = []
            let began = CACurrentMediaTime()
            while CACurrentMediaTime() - began < 0.8 {
                advance(0.008)
                samples.append(min(host.visibleFrame.height, host.contentCanvasSize.height))
            }
            let target = model.size.height
            if model.workspace.tool != MediaTool.allCases[index] || !model.trace.contains("tool") {
                failures.append("tool \(index) state change was not delivered")
            }
            if model.backingTooSmall { failures.append("tool \(index) started with a clipped backing view") }
            let intermediate = samples.filter { $0 > min(from, target) + 1 && $0 < max(from, target) - 1 }
            if abs(from - target) > 4, !reduceMotion, intermediate.count < 3 {
                failures.append("tool \(index) has no continuous resize")
            }
            if abs(host.visibleFrame.height - target) > 1 { failures.append("tool \(index) did not settle") }
            print("MEDIA MOTION tool=\(index) from=\(Int(from)) to=\(Int(target)) intermediate=\(intermediate.count) trace=\(model.trace.joined(separator: ","))")
        }
        NotificationCenter.default.removeObserver(observer)
        host.close()
        defaults.removePersistentDomain(forName: domain)
        flock(lockFD, LOCK_UN)
        close(lockFD)
        print("MEDIA MOTION \(failures.isEmpty ? "OK" : "FAILED") reduceMotion=\(reduceMotion) \(failures.joined(separator: "; "))")
        exit(failures.isEmpty ? 0 : 1)
    }

}
#endif
