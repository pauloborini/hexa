// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import CoreImage

enum QuickToolsSupport {
    static func sampledColor(in image: CGImage, x: Int, y: Int) -> NSColor? {
        guard let pixel = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1))
        else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: pixel)
        guard let color = bitmap.colorAt(x: 0, y: 0) else { return nil }
        // colorAt returns the pixel's components tagged as a generic color
        // space. Preserve the bitmap's profile before converting to sRGB.
        var components = [CGFloat](repeating: 0, count: color.numberOfComponents)
        color.getComponents(&components)
        guard components.count == bitmap.colorSpace.numberOfColorComponents + 1
        else { return nil }
        return NSColor(colorSpace: bitmap.colorSpace,
                       components: components,
                       count: components.count)
    }

    // MARK: - Quick launcher

    enum GridDirection {
        case up, down, left, right
    }

    /// Which way a grid fills: row by row with a fixed column count, or
    /// column by column with a fixed row count, as a rail in the island does.
    enum GridFlow: Equatable {
        case rows(columns: Int)
        case columns(rows: Int)
    }

    /// Keyboard navigation over a row-major grid: arrows move by one cell,
    /// clamped to the existing items (no wrapping, so the selection never
    /// jumps surprisingly from one edge to the other).
    static func gridIndex(after index: Int,
                          count: Int,
                          columns: Int,
                          direction: GridDirection) -> Int {
        guard count > 0, columns > 0 else { return 0 }
        let current = min(max(index, 0), count - 1)
        let candidate: Int
        switch direction {
        case .left: candidate = current - 1
        case .right: candidate = current + 1
        case .up: candidate = current - columns
        case .down: candidate = current + columns
        }
        guard candidate >= 0, candidate < count else { return current }
        if direction == .left, current % columns == 0 { return current }
        if direction == .right, current % columns == columns - 1 { return current }
        return candidate
    }

    /// A column-major rail is the row-major walk with the axes swapped.
    static func gridIndex(after index: Int, count: Int, flow: GridFlow, direction: GridDirection) -> Int {
        switch flow {
        case .rows(let columns):
            return gridIndex(after: index, count: count, columns: columns, direction: direction)
        case .columns(let rows):
            let transposed: GridDirection
            switch direction {
            case .up: transposed = .left
            case .down: transposed = .right
            case .left: transposed = .up
            case .right: transposed = .down
            }
            return gridIndex(after: index, count: count, columns: max(1, rows), direction: transposed)
        }
    }

    /// The launcher's hidden-item set travels as a comma-joined string.
    static func hiddenIDs(from raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func serializeHiddenIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    /// One recognized line of screen text with its normalized position
    /// (bottom-left origin, as Vision reports it) and optional full bounding box.
    struct RecognizedLine {
        let text: String
        let x: Double
        let y: Double
        let boundingBox: CGRect?

        init(text: String, x: Double, y: Double, boundingBox: CGRect? = nil) {
            self.text = text
            self.x = x
            self.y = y
            self.boundingBox = boundingBox
        }
    }

    /// Joins recognized lines in natural reading order: top to bottom, left
    /// to right within the same visual row, or column-by-column left to right
    /// when lines form distinct multi-row columns separated by a real gutter.
    static func joinedRecognizedText(_ lines: [RecognizedLine],
                                     removingLineBreaks: Bool) -> String {
        let nonEmpty = lines.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !nonEmpty.isEmpty else { return "" }

        if nonEmpty.allSatisfy({ $0.boundingBox != nil }) {
            if let columns = partitionColumns(nonEmpty) {
                let columnTexts = columns.map {
                    joinParagraphLines($0, removingLineBreaks: removingLineBreaks)
                }
                return joinSectionTexts(columnTexts, removingLineBreaks: removingLineBreaks)
            }
            if let sections = splitVerticalBandsAroundWideRows(nonEmpty) {
                let sectionTexts = sections.map {
                    joinParagraphLines($0, removingLineBreaks: removingLineBreaks)
                }
                return joinSectionTexts(sectionTexts, removingLineBreaks: removingLineBreaks)
            }
        }

        return joinParagraphLines(nonEmpty, removingLineBreaks: removingLineBreaks)
    }

    private static func joinParagraphLines(_ lines: [RecognizedLine],
                                           removingLineBreaks: Bool) -> String {
        let texts = sortInReadingRows(lines).flatMap { $0 }.map(\.text)
        guard removingLineBreaks else { return texts.joined(separator: "\n") }
        return texts.reduce(into: "") { joined, line in
            appendJoinedSegment(&joined, segment: line)
        }
    }

    private static func joinSectionTexts(_ sections: [String],
                                         removingLineBreaks: Bool) -> String {
        let nonEmpty = sections.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard removingLineBreaks else { return nonEmpty.joined(separator: "\n\n") }
        return nonEmpty.reduce(into: "") { joined, section in
            appendJoinedSegment(&joined, segment: section)
        }
    }

    private static func appendJoinedSegment(_ joined: inout String, segment: String) {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !joined.isEmpty else {
            joined = trimmed
            return
        }
        let joinsTightly = joined.unicodeScalars.last.map(isTightScriptScalar) == true
            && trimmed.unicodeScalars.first.map(isTightScriptScalar) == true
        joined.append(joinsTightly ? "" : " ")
        joined.append(trimmed)
    }

    private static func sortInReadingRows(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
        let byYDesc = lines.sorted {
            if $0.y != $1.y { return $0.y > $1.y }
            return $0.x < $1.x
        }
        var rows: [[RecognizedLine]] = []
        var anchorY: Double = 0
        var anchorBox: CGRect?

        for line in byYDesc {
            if let lastIndex = rows.indices.last,
               isSameVisualRow(anchorBox: anchorBox, anchorY: anchorY, candidate: line) {
                rows[lastIndex].append(line)
                continue
            }
            rows.append([line])
            anchorY = line.y
            anchorBox = line.boundingBox?.standardized
        }

        return rows.map { row in
            row.sorted { $0.x < $1.x }
        }
    }

    private static func isSameVisualRow(anchorBox: CGRect?,
                                        anchorY: Double,
                                        candidate: RecognizedLine) -> Bool {
        if let boxA = anchorBox,
           let boxB = candidate.boundingBox?.standardized,
           boxA.height > 0,
           boxB.height > 0 {
            let minHeight = min(Double(boxA.height), Double(boxB.height))
            let overlap = max(0.0, min(Double(boxA.maxY), Double(boxB.maxY)) - max(Double(boxA.minY), Double(boxB.minY)))
            return overlap >= minHeight * 0.4 || abs(Double(boxA.midY) - Double(boxB.midY)) < minHeight * 0.45
        }
        return abs(anchorY - candidate.y) < 0.01
    }

    private static func partitionColumns(_ lines: [RecognizedLine]) -> [[RecognizedLine]]? {
        let boxed = lines.compactMap { line -> (line: RecognizedLine, box: CGRect)? in
            guard let box = line.boundingBox?.standardized else { return nil }
            return (line, box)
        }
        guard boxed.count == lines.count, boxed.count >= 4 else { return nil }

        let sortedByX = boxed.sorted {
            if $0.box.minX != $1.box.minX { return $0.box.minX < $1.box.minX }
            return $0.box.maxX > $1.box.maxX
        }

        let minimumGutter = 0.03
        var clusters: [(minX: Double, maxX: Double, lines: [RecognizedLine], minY: Double, maxY: Double)] = []
        for item in sortedByX {
            let minX = Double(item.box.minX)
            let maxX = Double(item.box.maxX)
            let itemMinY = item.box.height > 0 ? Double(item.box.minY) : item.line.y
            let itemMaxY = item.box.height > 0 ? Double(item.box.maxY) : item.line.y
            if let last = clusters.indices.last, minX <= clusters[last].maxX + minimumGutter {
                clusters[last].maxX = max(clusters[last].maxX, maxX)
                clusters[last].minY = min(clusters[last].minY, itemMinY)
                clusters[last].maxY = max(clusters[last].maxY, itemMaxY)
                clusters[last].lines.append(item.line)
            } else {
                clusters.append((minX: minX, maxX: maxX, lines: [item.line], minY: itemMinY, maxY: itemMaxY))
            }
        }

        guard clusters.count >= 2 else { return nil }

        let rowCounts = clusters.map { sortInReadingRows($0.lines).count }
        let multiRowIndices = clusters.indices.filter { rowCounts[$0] >= 2 }
        guard multiRowIndices.count >= 2 else { return nil }

        for offset in 1..<multiRowIndices.count {
            let prev = clusters[multiRowIndices[offset - 1]]
            let curr = clusters[multiRowIndices[offset]]
            guard max(prev.minY, curr.minY) <= min(prev.maxY, curr.maxY) else { return nil }
        }

        // A grid where every visual row holds a cell of each multi-row column
        // is a table: it keeps row-by-row reading. Prose columns flow on their
        // own, so their baselines or line counts break this alignment.
        let multiRowClusters = multiRowIndices.map { clusters[$0] }
        let isTable = sortInReadingRows(multiRowClusters.flatMap(\.lines)).allSatisfy { row in
            multiRowClusters.allSatisfy { cluster in
                row.contains { line in
                    guard let minX = line.boundingBox?.standardized.minX else { return false }
                    return Double(minX) >= cluster.minX && Double(minX) <= cluster.maxX
                }
            }
        }
        guard !isTable else { return nil }

        let unionMinY = multiRowIndices.map { clusters[$0].minY }.min() ?? 0
        let unionMaxY = multiRowIndices.map { clusters[$0].maxY }.max() ?? 1
        for index in clusters.indices where rowCounts[index] < 2 {
            let cluster = clusters[index]
            guard max(cluster.minY, unionMinY) <= min(cluster.maxY, unionMaxY) else { return nil }
        }

        return clusters.map(\.lines)
    }

    private static func splitVerticalBandsAroundWideRows(_ lines: [RecognizedLine]) -> [[RecognizedLine]]? {
        let rows = sortInReadingRows(lines)
        guard rows.count >= 3 else { return nil }

        let boxes = lines.compactMap { $0.boundingBox?.standardized }
        guard let globalMinX = boxes.map({ Double($0.minX) }).min(),
              let globalMaxX = boxes.map({ Double($0.maxX) }).max() else {
            return nil
        }
        let totalSpan = globalMaxX - globalMinX
        guard totalSpan > 0 else { return nil }

        let wideThreshold = CGFloat(totalSpan * 0.65)
        var rawBands: [[RecognizedLine]] = []
        var currentBand: [RecognizedLine] = []

        for row in rows {
            let hasWideLine = row.contains { ($0.boundingBox?.standardized.width ?? 0) > wideThreshold }
            if hasWideLine {
                if !currentBand.isEmpty {
                    rawBands.append(currentBand)
                    currentBand.removeAll(keepingCapacity: true)
                }
                rawBands.append(row)
            } else {
                currentBand.append(contentsOf: row)
            }
        }
        if !currentBand.isEmpty {
            rawBands.append(currentBand)
        }

        var foundMultiColumnBand = false
        var sections: [[RecognizedLine]] = []
        for band in rawBands {
            if let columns = partitionColumns(band) {
                foundMultiColumnBand = true
                sections.append(contentsOf: columns)
            } else {
                sections.append(band)
            }
        }
        return foundMultiColumnBand ? sections : nil
    }

    // CJK punctuation, kana, Han. Hangul syllables and halfwidth Hangul jamo
    // stay out on purpose because Korean keeps its word spaces.
    private static func isTightScriptScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3000...0x312F,
             0x3190...0x9FFF,
             0xF900...0xFAFF,
             0xFF01...0xFF9F,
             0x20000...0x2FA1F:
            return true
        default:
            return false
        }
    }

    // MARK: - CoreImage OCR / Barcode enhancement

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    static func invertedImage(_ image: CGImage) -> CGImage? {
        autoreleasepool {
            let source = CIImage(cgImage: image)
            guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
            filter.setValue(source, forKey: kCIInputImageKey)
            guard let output = filter.outputImage else { return nil }
            return ciContext.createCGImage(output, from: source.extent)
        }
    }

    static func contrastNormalizedImage(_ image: CGImage, invert: Bool = false) -> CGImage? {
        autoreleasepool {
            let source = CIImage(cgImage: image)
            let avgLuminance = averageLuminance(of: source) ?? 0.5
            let brightnessShift = min(0.45, max(-0.45, 0.5 - avgLuminance))

            guard let normalizeFilter = CIFilter(name: "CIColorControls") else { return nil }
            normalizeFilter.setValue(source, forKey: kCIInputImageKey)
            normalizeFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            normalizeFilter.setValue(brightnessShift, forKey: kCIInputBrightnessKey)
            normalizeFilter.setValue(1.0, forKey: kCIInputContrastKey)
            guard let normalized = normalizeFilter.outputImage else { return nil }

            guard let contrastFilter = CIFilter(name: "CIColorControls") else { return nil }
            contrastFilter.setValue(normalized, forKey: kCIInputImageKey)
            contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            contrastFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
            contrastFilter.setValue(2.5, forKey: kCIInputContrastKey)
            guard var output = contrastFilter.outputImage else { return nil }

            if invert {
                guard let invertFilter = CIFilter(name: "CIColorInvert") else { return nil }
                invertFilter.setValue(output, forKey: kCIInputImageKey)
                guard let inverted = invertFilter.outputImage else { return nil }
                output = inverted
            }
            return ciContext.createCGImage(output, from: source.extent)
        }
    }

    private static func averageLuminance(of ciImage: CIImage) -> Double? {
        let extent = ciImage.extent
        guard !extent.isEmpty,
              let filter = CIFilter(name: "CIAreaAverage")
        else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ciContext.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // MARK: - QR codes

    /// One decoded 2D code with its normalized position (bottom-left origin,
    /// as Vision reports it) so several codes join in reading order.
    struct DecodedBarcode {
        let payload: String
        let x: Double
        let y: Double
    }

    /// Orders decoded codes from top to bottom, left to right, dropping empty
    /// and duplicate payloads while preserving reading order.
    static func orderedUniqueBarcodes(_ codes: [DecodedBarcode]) -> [DecodedBarcode] {
        let byYDesc = codes
            .filter { !$0.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.y != $1.y { return $0.y > $1.y }
                return $0.x < $1.x
            }
        var rows: [[DecodedBarcode]] = []
        var anchorY: Double = 0
        for code in byYDesc {
            if let lastIndex = rows.indices.last, abs(anchorY - code.y) < 0.01 {
                rows[lastIndex].append(code)
            } else {
                rows.append([code])
                anchorY = code.y
            }
        }
        var seen = Set<String>()
        return rows
            .flatMap { $0.sorted { $0.x < $1.x } }
            .filter { seen.insert($0.payload).inserted }
    }

    /// Joins decoded codes in natural reading order (top to bottom, left to
    /// right), dropping empty and duplicate payloads. Several codes are newline separated.
    static func joinedBarcodePayloads(_ codes: [DecodedBarcode]) -> String {
        orderedUniqueBarcodes(codes)
            .map(\.payload)
            .joined(separator: "\n")
    }

    // MARK: - Paste as plain text

    /// Whether a menu item is an app's own matching-style paste, judged by its
    /// key equivalent instead of its localized title. The universal
    /// convention is ⌥⇧⌘V; in the AX menu attributes that is command
    /// character "V" with the shift (1) and option (2) bits set and nothing
    /// else (0 alone means a plain ⌘ equivalent). ⇧⌘V and ⌃ variants are
    /// deliberately out: in several apps those are different edit commands,
    /// and pressing one would touch the document.
    static func isMatchStyleEquivalent(commandCharacter: String?,
                                       modifierMask: UInt32?,
                                       isEnabled: Bool) -> Bool {
        let shiftAndOption: UInt32 = 1 | 2
        return commandCharacter?.uppercased() == "V"
            && modifierMask == shiftAndOption
            && isEnabled
    }

    /// The payload as a web link for the optional open action. Limited to
    /// https on purpose: a scanned code must never be able to launch an
    /// arbitrary URL scheme (mailto, tel, custom app schemes and so on),
    /// and plaintext http is not offered for direct navigation.
    static func openableURL(from payload: String) -> URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    /// Whether an asynchronous OCR pass may still write its recognized text to
    /// the clipboard. A newer OCR session or any clipboard write performed by
    /// the user while recognition was running keeps the existing clipboard.
    static func shouldCopyRecognizedText(
        recognitionGeneration: Int,
        currentGeneration: Int,
        initialPasteboardChangeCount: Int,
        currentPasteboardChangeCount: Int
    ) -> Bool {
        recognitionGeneration == currentGeneration
            && initialPasteboardChangeCount == currentPasteboardChangeCount
    }
}
