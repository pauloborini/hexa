// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

#if HEXA_DEVELOPMENT
import AppKit

/// Regressão de janela do workspace: pisos/limites, render e fechamento das
/// páginas de sistema.
enum SettingsPresentationProbe {
    static func runAndExit() -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        // Usa a janela de produção, incluindo a barra lateral que crashava.
        for page: SettingsPage in [.general, .features, .notch, .shortcuts, .advanced, .about, .releaseNotes] {
            SettingsRouter.shared.page = page
            FeatureWorkspaceWindow.shared.showSettings()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            guard let window = FeatureWorkspaceWindow.shared.presentationWindow,
                  let view = window.contentView, window.isVisible else {
                print("FALHA: janela dos ajustes ausente em \(page)")
                exit(1)
            }
            // Exercita o piso mesmo quando o bundle de probe tem altura salva maior.
            window.setContentSize(NSSize(width: 800, height: 690))
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            view.layoutSubtreeIfNeeded()
            guard window.contentMinSize == NSSize(width: 800, height: 690),
                  window.contentMaxSize.width == 800,
                  window.contentMaxSize.height > 1400,
                  abs(view.frame.width - 800) < 0.5,
                  view.frame.height >= 690 else {
                print("FALHA: limites da janela em \(page): \(window.contentMinSize), \(window.contentMaxSize), \(view.frame)")
                exit(1)
            }
            if page == .general {
                let initialSize = view.frame.size
                window.setContentSize(NSSize(width: 800, height: initialSize.height + 200))
                view.layoutSubtreeIfNeeded()
                guard abs(view.frame.height - initialSize.height - 200) < 0.5,
                      abs(view.frame.width - 800) < 0.5 else {
                    print("FALHA: crescimento vertical alterou a largura")
                    exit(1)
                }
                window.setContentSize(initialSize)
                view.layoutSubtreeIfNeeded()
            }
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                print("FALHA: renderização ausente em \(page)")
                exit(1)
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if page == .general,
               let png = bitmap.representation(using: .png, properties: [:]) {
                do {
                    try png.write(to: URL(fileURLWithPath: "build/settings-smoke-general.png"))
                } catch {
                    print("FALHA: captura dos ajustes: \(error)")
                    exit(1)
                }
            }
            print("PASS: ajustes \(page), \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
            window.close()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        print("PASS: 7 páginas abertas, renderizadas e fechadas")
        exit(0)
    }
}
#endif
