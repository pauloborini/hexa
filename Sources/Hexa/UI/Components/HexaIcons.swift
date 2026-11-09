// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import AppKit
import CoreText
import SwiftUI

/// Família única. Nomes legados são apenas chaves semânticas, não SF Symbols.
enum HexaIcons {
    private static let glyphs: [String: Int] = {
        guard let url = Bundle.module.url(forResource: "glyphs", withExtension: "json", subdirectory: "Icons"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: Int].self, from: data) else {
            preconditionFailure("Catálogo de ícones ausente")
        }
        return values
    }()
    private static let fontName: String = {
        guard let url = Bundle.module.url(forResource: "lucide", withExtension: "ttf", subdirectory: "Icons"),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first else { preconditionFailure("Fonte de ícones ausente") }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return CTFontCopyPostScriptName(CTFontCreateWithFontDescriptor(descriptor, 16, nil)) as String
    }()
    private static let cache = NSCache<NSString, NSImage>()

    static func nsImage(named name: String, accessibilityDescription: String? = nil,
                        size: CGFloat = HexaIconMetrics.standard) -> NSImage? {
        guard let code = glyphs[name], let scalar = UnicodeScalar(code),
              let font = NSFont(name: fontName, size: size) else { return nil }
        let key = "\(code):\(size)" as NSString
        let image: NSImage
        if let cached = cache.object(forKey: key) {
            image = cached.copy() as! NSImage
        } else {
            let text = NSAttributedString(string: String(scalar), attributes: [.font: font, .foregroundColor: NSColor.black])
            let glyphSize = text.size()
            let rendered = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.saveGState()
                context.scaleBy(x: rect.width / size, y: rect.height / size)
                text.draw(at: NSPoint(x: (size - glyphSize.width) / 2,
                                      y: (size - glyphSize.height) / 2))
                context.restoreGState()
                return true
            }
            rendered.isTemplate = true
            cache.setObject(rendered, forKey: key)
            image = rendered.copy() as! NSImage
        }
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    static func image(_ name: String, size: CGFloat = HexaIconMetrics.standard) -> Image {
        guard let image = nsImage(named: name, size: size) else {
            assertionFailure("Ícone sem mapeamento: \(name)")
            return Image(nsImage: NSImage(size: .zero))
        }
        return Image(nsImage: image).renderingMode(.template)
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: String, hexaIcon: String) {
        self.init { Text(title) } icon: { HexaIcons.image(hexaIcon, size: HexaIconMetrics.label) }
    }
}


extension NSImage {
    func hexaSized(_ side: CGFloat) -> NSImage? {
        let image = copy() as! NSImage
        image.size = NSSize(width: side, height: side)
        return image
    }
}


extension NSImage {
    func hexaTinted(_ color: NSColor) -> NSImage {
        let source = self
        return NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
