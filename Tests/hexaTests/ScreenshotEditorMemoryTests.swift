// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import CoreGraphics
import Foundation
import XCTest

@testable import Hexa

final class ScreenshotEditorMemoryTests: XCTestCase {
    private final class PixelBufferBox {
        let data: NSMutableData

        init(byteCount: Int) {
            data = NSMutableData(length: byteCount) ?? NSMutableData()
        }
    }

    private func preserveEditorDefaults() {
        let keys = [
            DefaultsKey.screenshotLastTool,
            DefaultsKey.screenshotLastColor,
            DefaultsKey.screenshotLastStroke,
            DefaultsKey.screenshotLastTextSize,
            DefaultsKey.screenshotLastBlurLevel,
            DefaultsKey.screenshotLastArrowStyle,
            DefaultsKey.screenshotLastSticker,
        ]
        let defaults = UserDefaults.standard
        let snapshot = keys.map { ($0, defaults.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in snapshot {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }

    private func makeTrackedImage(
        width: Int,
        height: Int,
        fillFirstPixel: (UInt8, UInt8, UInt8, UInt8)? = nil
    ) throws -> (image: CGImage, box: PixelBufferBox) {
        let bytesPerRow = width * 4
        let box = PixelBufferBox(byteCount: bytesPerRow * height)
        if let pixel = fillFirstPixel, box.data.length >= 4 {
            let ptr = box.data.mutableBytes.assumingMemoryBound(to: UInt8.self)
            ptr[0] = pixel.0
            ptr[1] = pixel.1
            ptr[2] = pixel.2
            ptr[3] = pixel.3
        }
        let rawBox = Unmanaged.passRetained(box).toOpaque()
        let provider = try XCTUnwrap(
            CGDataProvider(
                dataInfo: rawBox,
                data: box.data.bytes,
                size: box.data.length
            ) { info, _, _ in
                guard let info else { return }
                Unmanaged<PixelBufferBox>.fromOpaque(info).release()
            }
        )
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try XCTUnwrap(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
        return (image, box)
    }

    private func drawRect(
        in model: ScreenshotEditorModel,
        from start: CGPoint,
        to end: CGPoint
    ) {
        model.tool = .rect
        model.beginDrag(at: start)
        model.continueDrag(to: end)
        model.endDrag(at: end, isTap: false)
    }

    func testIndependentImageReleasesParentFrame() throws {
        weak var weakParent: CGImage?
        weak var weakBox: PixelBufferBox?
        var detached: CGImage?

        try autoreleasepool {
            let created = try makeTrackedImage(width: 1024, height: 768, fillFirstPixel: (12, 34, 56, 255))
            let parent = created.image
            weakParent = parent
            weakBox = created.box
            let cropped = try XCTUnwrap(parent.cropping(to: CGRect(x: 0, y: 0, width: 120, height: 80)))
            detached = ScreenshotSupport.independentImage(cropped)
        }

        let independent = try XCTUnwrap(detached)
        XCTAssertEqual(independent.width, 120)
        XCTAssertEqual(independent.height, 80)
        XCTAssertEqual(independent.bitsPerComponent, 8)
        XCTAssertEqual(independent.alphaInfo, .premultipliedLast)
        XCTAssertNil(weakParent)
        XCTAssertNil(weakBox)

        let data = try XCTUnwrap(independent.dataProvider?.data as Data?)
        XCTAssertGreaterThanOrEqual(data.count, 4)
        XCTAssertEqual([data[0], data[1], data[2], data[3]], [12, 34, 56, 255])
    }

    func testIndependentImageHandlesNonPremultipliedAndOpaqueRGBFormats() throws {
        let rgb = CGColorSpaceCreateDeviceRGB()

        let nonPremultipliedBytes: [UInt8] = [100, 150, 200, 255, 10, 20, 30, 128]
        let nonPremultipliedData = try XCTUnwrap(
            CFDataCreate(nil, nonPremultipliedBytes, nonPremultipliedBytes.count)
        )
        let nonPremultipliedProvider = try XCTUnwrap(CGDataProvider(data: nonPremultipliedData))
        let nonPremultiplied = try XCTUnwrap(
            CGImage(
                width: 2,
                height: 1,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 8,
                space: rgb,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: nonPremultipliedProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
        let independentFromLast = try XCTUnwrap(ScreenshotSupport.independentImage(nonPremultiplied))
        XCTAssertEqual(independentFromLast.alphaInfo, .premultipliedLast)
        XCTAssertEqual(independentFromLast.width, 2)
        XCTAssertEqual(independentFromLast.height, 1)

        let opaqueBytes = [UInt8](repeating: 180, count: 4 * 4 * 3)
        let opaqueData = try XCTUnwrap(CFDataCreate(nil, opaqueBytes, opaqueBytes.count))
        let opaqueProvider = try XCTUnwrap(CGDataProvider(data: opaqueData))
        let opaqueRGB = try XCTUnwrap(
            CGImage(
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bitsPerPixel: 24,
                bytesPerRow: 12,
                space: rgb,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: opaqueProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
        let independentFromRGB = try XCTUnwrap(ScreenshotSupport.independentImage(opaqueRGB))
        XCTAssertEqual(independentFromRGB.width, 4)
        XCTAssertEqual(independentFromRGB.height, 4)
    }

    func testApplyCropReleasesParentAndWeakCleanImagePreservesDirtyState() throws {
        preserveEditorDefaults()
        weak var weakParent: CGImage?
        weak var weakBox: PixelBufferBox?

        let model: ScreenshotEditorModel = try autoreleasepool {
            let created = try makeTrackedImage(width: 10240, height: 7168)
            weakParent = created.image
            weakBox = created.box
            return ScreenshotEditorModel(image: created.image, scale: 1)
        }

        XCTAssertFalse(model.isDirty)
        XCTAssertFalse(model.canUndo)

        autoreleasepool {
            model.tool = .crop
            model.cropDraft = CGRect(x: 10, y: 10, width: 120, height: 120)
            model.applyCrop()
        }

        XCTAssertEqual(model.imageSize, CGSize(width: 120, height: 120))
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(model.canUndo)
        XCTAssertNotNil(weakParent)

        autoreleasepool {
            drawRect(in: model, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 80, y: 80))
        }

        XCTAssertNil(weakParent)
        XCTAssertNil(weakBox)
        XCTAssertTrue(model.canUndo)
        XCTAssertTrue(model.isDirty)

        model.undo()
        XCTAssertTrue(model.annotations.isEmpty)
        XCTAssertEqual(model.imageSize, CGSize(width: 120, height: 120))
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)
        XCTAssertTrue(model.isDirty)
    }

    func testApplyCropIgnoresFullImageSelection() throws {
        preserveEditorDefaults()
        let created = try makeTrackedImage(width: 200, height: 150)
        let model = ScreenshotEditorModel(image: created.image, scale: 1)

        model.tool = .crop
        model.applyCrop()

        XCTAssertEqual(model.imageSize, CGSize(width: 200, height: 150))
        XCTAssertEqual(model.tool, .select)
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.isDirty)
    }

    func testTrimHistoryEnforcesImageByteBudgetAcrossCrops() throws {
        preserveEditorDefaults()
        weak var weakParent: CGImage?
        weak var weakBox: PixelBufferBox?

        let model: ScreenshotEditorModel = try autoreleasepool {
            // 9000 x 4096 RGBA (~140.6 MiB) is individually below 256 MiB.
            let created = try makeTrackedImage(width: 9000, height: 4096)
            weakParent = created.image
            weakBox = created.box
            return ScreenshotEditorModel(image: created.image, scale: 1)
        }

        autoreleasepool {
            // 8500 x 4096 RGBA (~132.8 MiB): combined ~273.4 MiB exceeds 256 MiB.
            model.tool = .crop
            model.cropDraft = CGRect(x: 0, y: 0, width: 8500, height: 4096)
            model.applyCrop()
        }
        XCTAssertNotNil(weakParent)
        XCTAssertTrue(model.canUndo)

        autoreleasepool {
            model.tool = .crop
            model.cropDraft = CGRect(x: 0, y: 0, width: 100, height: 100)
            model.applyCrop()
        }

        XCTAssertNil(weakParent)
        XCTAssertNil(weakBox)
        XCTAssertEqual(model.imageSize, CGSize(width: 100, height: 100))
        XCTAssertTrue(model.canUndo)

        model.undo()
        XCTAssertEqual(model.imageSize, CGSize(width: 8500, height: 4096))
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)
    }

    func testTrimHistoryPreservesAtLeastOneImmediateReverseStep() throws {
        preserveEditorDefaults()
        let created = try makeTrackedImage(width: 10240, height: 7168)
        let model = ScreenshotEditorModel(image: created.image, scale: 1)

        model.tool = .crop
        model.cropDraft = CGRect(x: 0, y: 0, width: 100, height: 100)
        model.applyCrop()

        XCTAssertTrue(model.canUndo)
        model.undo()
        XCTAssertEqual(model.imageSize, CGSize(width: 10240, height: 7168))
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)

        model.redo()
        XCTAssertEqual(model.imageSize, CGSize(width: 100, height: 100))
        XCTAssertTrue(model.canUndo)
        XCTAssertFalse(model.canRedo)
    }

    func testTrimHistoryAccountsForAnnotationBytesAcrossUndoAndRedo() throws {
        preserveEditorDefaults()
        // 8192 x 8191 RGBA = 268,402,688 bytes, leaving 32,768 bytes (64 annotation slots) under 256 MiB.
        let created = try makeTrackedImage(width: 8192, height: 8191)
        let model = ScreenshotEditorModel(image: created.image, scale: 1)

        // Rects are spaced beyond the 12 px handle tolerance so each drag starts a new
        // rect instead of resizing the previous, still selected one.
        for step in 0..<11 {
            let offset = CGFloat(step * 60)
            drawRect(in: model, from: CGPoint(x: offset, y: 10), to: CGPoint(x: offset + 15, y: 40))
        }
        XCTAssertEqual(model.annotations.count, 11)

        for _ in 0..<11 {
            XCTAssertTrue(model.canUndo)
            model.undo()
        }
        XCTAssertEqual(model.annotations.count, 0)
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)

        var redoSteps = 0
        while model.canRedo {
            model.redo()
            redoSteps += 1
        }
        // History holds every state except the current one: 66 slots minus the current count.
        // The tenth undo (current = 1) reached 65 > 64, so the oldest redo entry (11 annotations)
        // was trimmed while the immediate undo and redo steps stayed intact.
        XCTAssertEqual(redoSteps, 10)
        XCTAssertEqual(model.annotations.count, 10)
    }

    func testTapAndCanceledEmptyTextPreserveUndoAndRedoHistory() throws {
        preserveEditorDefaults()
        let created = try makeTrackedImage(width: 500, height: 500)
        let model = ScreenshotEditorModel(image: created.image, scale: 1)

        drawRect(in: model, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 80, y: 80))
        drawRect(in: model, from: CGPoint(x: 120, y: 120), to: CGPoint(x: 180, y: 180))
        model.undo()

        XCTAssertEqual(model.annotations.count, 1)
        XCTAssertTrue(model.canUndo)
        XCTAssertTrue(model.canRedo)

        for tool in [ScreenshotSupport.Tool.rect, .arrow, .freehand, .pixelate] {
            model.tool = tool
            model.beginDrag(at: CGPoint(x: 320, y: 320))
            model.endDrag(at: CGPoint(x: 320, y: 320), isTap: true)
            XCTAssertEqual(model.annotations.count, 1)
            XCTAssertTrue(model.canUndo)
            XCTAssertTrue(model.canRedo)
        }

        for tool in [ScreenshotSupport.Tool.sticker, .counter] {
            model.tool = tool
            model.beginDrag(at: CGPoint(x: 320, y: 320))
            model.continueDrag(to: CGPoint(x: 360, y: 360))
            model.endDrag(at: CGPoint(x: 360, y: 360), isTap: false)
            XCTAssertEqual(model.annotations.count, 1)
            XCTAssertTrue(model.canUndo)
            XCTAssertTrue(model.canRedo)
        }

        model.tool = .text
        model.beginDrag(at: CGPoint(x: 320, y: 320))
        model.endDrag(at: CGPoint(x: 320, y: 320), isTap: true)
        let draftID = try XCTUnwrap(model.editingTextID)
        model.color = .blue
        model.textSize = 36
        model.commitText(draftID, text: "   ")

        XCTAssertNil(model.editingTextID)
        XCTAssertEqual(model.annotations.count, 1)
        XCTAssertTrue(model.canUndo)
        XCTAssertTrue(model.canRedo)

        model.redo()
        XCTAssertEqual(model.annotations.count, 2)
        XCTAssertFalse(model.canRedo)

        model.undo()
        model.undo()
        XCTAssertEqual(model.annotations.count, 0)
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.isDirty)
    }

    func testNewTextCommitAndSelectMoveDragRegisterUndo() throws {
        preserveEditorDefaults()
        let created = try makeTrackedImage(width: 500, height: 500)
        let model = ScreenshotEditorModel(image: created.image, scale: 1)

        model.tool = .text
        model.beginDrag(at: CGPoint(x: 60, y: 60))
        model.endDrag(at: CGPoint(x: 60, y: 60), isTap: true)
        let textID = try XCTUnwrap(model.editingTextID)
        model.color = .green
        model.commitText(textID, text: "Hello")

        XCTAssertEqual(model.annotations.count, 1)
        XCTAssertEqual(model.annotations[0].text, "Hello")
        XCTAssertEqual(model.annotations[0].color, .green)
        XCTAssertTrue(model.canUndo)

        model.undo()
        XCTAssertTrue(model.annotations.isEmpty)
        XCTAssertTrue(model.canRedo)

        model.redo()
        XCTAssertEqual(model.annotations.count, 1)
        XCTAssertEqual(model.annotations[0].text, "Hello")

        drawRect(in: model, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 280, y: 280))
        let originalRect = model.annotations[1].rect
        model.tool = .select
        model.beginDrag(at: CGPoint(x: 240, y: 240))
        model.continueDrag(to: CGPoint(x: 280, y: 270))
        model.endDrag(at: CGPoint(x: 280, y: 270), isTap: false)

        XCTAssertEqual(model.annotations[1].rect, originalRect.offsetBy(dx: 40, dy: 30))
        model.undo()
        XCTAssertEqual(model.annotations[1].rect, originalRect)
    }

    func testCommitActiveTextEditWithNonEmptyDraftMarksDirtyAndCanUndo() throws {
        preserveEditorDefaults()
        let created = try makeTrackedImage(width: 500, height: 500)
        let model = ScreenshotEditorModel(image: created.image, scale: 1)

        model.tool = .text
        model.beginDrag(at: CGPoint(x: 60, y: 60))
        model.endDrag(at: CGPoint(x: 60, y: 60), isTap: true)
        XCTAssertNotNil(model.editingTextID)
        XCTAssertFalse(model.isDirty)
        XCTAssertFalse(model.canUndo)

        model.editingTextDraft = "Uncommitted note"
        model.commitActiveTextEdit()

        XCTAssertNil(model.editingTextID)
        XCTAssertEqual(model.editingTextDraft, "")
        XCTAssertEqual(model.annotations.count, 1)
        XCTAssertEqual(model.annotations[0].text, "Uncommitted note")
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(model.canUndo)

        model.commitActiveTextEdit()
        XCTAssertEqual(model.annotations.count, 1)
    }

    func testCommitActiveTextEditWithEmptyOrWhitespaceDraftKeepsClean() throws {
        preserveEditorDefaults()
        for draft in ["", "   \n\t  "] {
            let created = try makeTrackedImage(width: 500, height: 500)
            let model = ScreenshotEditorModel(image: created.image, scale: 1)

            model.tool = .text
            model.beginDrag(at: CGPoint(x: 60, y: 60))
            model.endDrag(at: CGPoint(x: 60, y: 60), isTap: true)
            XCTAssertNotNil(model.editingTextID)

            model.editingTextDraft = draft
            model.commitActiveTextEdit()

            XCTAssertNil(model.editingTextID)
            XCTAssertEqual(model.editingTextDraft, "")
            XCTAssertTrue(model.annotations.isEmpty)
            XCTAssertFalse(model.isDirty)
            XCTAssertFalse(model.canUndo)
        }
    }
}
