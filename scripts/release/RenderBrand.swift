// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini
// Renderiza os elementos do SVG canônico e a arte do instalador, sem rasterização com matte branco.
import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2, ["icons", "background"].contains(args[0]) else {
    fatalError("Uso: swift scripts/release/RenderBrand.swift icons|background <diretório>")
}
let output = URL(fileURLWithPath: args[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ hex: String) -> NSColor {
    let number = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16)!
    return NSColor(srgbRed: CGFloat((number >> 16) & 255) / 255,
                   green: CGFloat((number >> 8) & 255) / 255,
                   blue: CGFloat(number & 255) / 255, alpha: 1)
}
final class Brand: NSObject, XMLParserDelegate {
    var elements: [(String, [String: String])] = []
    var stroke = "#F6F4EE"
    var width: CGFloat = 2
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "g", let value = attributes["stroke"] { stroke = value }
        if name == "g", let value = attributes["stroke-width"] { width = CGFloat(Double(value)!) }
        if ["rect", "line", "circle"].contains(name) {
            var values = attributes
            if values["stroke"] == nil { values["stroke"] = stroke }
            elements.append((name, values))
        }
    }
    func draw(_ ctx: CGContext, x: CGFloat, y: CGFloat, size: CGFloat) {
        ctx.saveGState(); defer { ctx.restoreGState() }
        ctx.translateBy(x: x, y: y + size)
        ctx.scaleBy(x: size / 48, y: -size / 48)
        ctx.setLineWidth(width); ctx.setLineCap(.round)
        for (name, values) in elements {
            func number(_ key: String) -> CGFloat { CGFloat(Double(values[key] ?? "0")!) }
            if name == "rect" {
                ctx.setFillColor(color(values["fill"]!).cgColor)
                ctx.fill(CGRect(x: number("x"), y: number("y"), width: number("width"), height: number("height")))
            } else if name == "line" {
                ctx.setStrokeColor(color(values["stroke"]!).cgColor)
                ctx.move(to: CGPoint(x: number("x1"), y: number("y1")))
                ctx.addLine(to: CGPoint(x: number("x2"), y: number("y2")))
                ctx.strokePath()
            } else {
                ctx.setFillColor(color(values["fill"]!).cgColor)
                let r = number("r")
                ctx.fillEllipse(in: CGRect(x: number("cx") - r, y: number("cy") - r, width: r * 2, height: r * 2))
            }
        }
    }
}
let svg = try Data(contentsOf: root.appendingPathComponent("Sources/Hexa/Resources/Brand/AppIcon.svg"))
let brand = Brand(); let parser = XMLParser(data: svg); parser.delegate = brand
guard parser.parse(), brand.elements.count == 8 else { fatalError("SVG da marca incompatível") }
func render(width: Int, height: Int, scale: Int, name: String, fill: String = "#17140F", draw: (CGContext) -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
    let ctx = graphics.cgContext; ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    ctx.setFillColor(color(fill).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
if args[0] == "icons" {
    for size in [16, 32, 128, 256, 512] {
        for factor in [1, 2] {
            let pixels = size * factor
            let suffix = factor == 2 ? "@2x" : ""
            try render(width: pixels, height: pixels, scale: 1, name: "icon_\(size)x\(size)\(suffix).png") {
                brand.draw($0, x: 0, y: 0, size: CGFloat(pixels))
            }
        }
    }
} else {
    for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic", "Manrope-Regular"] {
        let url = root.appendingPathComponent("Sources/Hexa/Resources/Fonts/\(name).ttf")
        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) else { fatalError("Fonte indisponível: \(name)") }
    }
    let serif = NSFont(name: "InstrumentSerif-Regular", size: 64)!
    let italic = NSFont(name: "InstrumentSerif-Italic", size: 64)!
    let manrope = NSFont(name: "Manrope-Regular", size: 13)!
    // Fundo claro: o Finder escreve o nome dos arquivos na cor do tema do sistema e nao aceita
    // que o instalador a defina. Sobre superficie clara o nome escuro fica legivel.
    // O retangulo do SVG e o fundo do icone do app; aqui ele sairia como quadrado escuro sobre
    // o creme, entao a marca do instalador usa so o traco, escuro e com o segmento dourado.
    brand.elements = brand.elements.filter { $0.0 != "rect" }
    for index in brand.elements.indices {
        var values = brand.elements[index].1
        for key in ["stroke", "fill"] where values[key]?.uppercased() == "#F6F4EE" {
            values[key] = "#17140F"
        }
        if values["stroke"]?.uppercased() == "#CFA955" { values["stroke"] = "#A8823A" }
        if values["fill"]?.uppercased() == "#CFA955" { values["fill"] = "#A8823A" }
        brand.elements[index].1 = values
    }
    try render(width: 720, height: 500, scale: 2, name: "background.png", fill: "#F6F4EE") { ctx in
        brand.draw(ctx, x: 304, y: 244, size: 112)
        let word = NSMutableAttributedString(string: "hex", attributes: [.font: serif, .foregroundColor: color("#17140F"), .kern: -1.28])
        word.append(NSAttributedString(string: "a", attributes: [.font: italic, .foregroundColor: color("#A8823A"), .kern: -1.28]))
        word.draw(at: NSPoint(x: (720 - word.size().width) / 2, y: 500 - 294))
        func caption(_ text: String, y: CGFloat, alpha: CGFloat = 1) {
            let string = NSAttributedString(string: text, attributes: [.font: manrope, .foregroundColor: color("#17140F").withAlphaComponent(alpha)])
            string.draw(at: NSPoint(x: (720 - string.size().width) / 2, y: 500 - y))
        }
        caption("Arraste o hexa para Aplicativos", y: 457, alpha: 0.78)
        caption("Drag hexa to Applications", y: 478, alpha: 0.62)
        ctx.setStrokeColor(color("#17140F").withAlphaComponent(0.72).cgColor)
        ctx.setLineWidth(2); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 310, y: 142)); ctx.addLine(to: CGPoint(x: 410, y: 142))
        ctx.move(to: CGPoint(x: 398, y: 154)); ctx.addLine(to: CGPoint(x: 410, y: 142)); ctx.addLine(to: CGPoint(x: 398, y: 130))
        ctx.strokePath()
    }
}
