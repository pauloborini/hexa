// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import XCTest

@testable import Hexa

/// Pins the pure decisions behind the write-only verdict cache and the
/// per-monitor path keys: a verdict expires so a channel misjudged on a bad
/// wake is probed again instead of staying written off forever, connections
/// without an IORegistry location still get a key that carries the manual
/// dimming choices, and a key that two identical monitors share carries no
/// one's choices. Also pins the phased display-to-service
/// matching: identical monitors never receive each other's service by the
/// order of a sort.
final class BrightnessSupportTests: XCTestCase {

    // MARK: Write-only verdict expiry

    func testVerdictYoungerThanTTLSkipsProbe() {
        XCTAssertFalse(BrightnessSupport.shouldProbeDDC(
            pathKey: "1552:a019:0", verdictAge: BrightnessSupport.writeOnlyVerdictTTL - 1))
    }

    func testExpiredVerdictProbesAgain() {
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(
            pathKey: "1552:a019:0", verdictAge: BrightnessSupport.writeOnlyVerdictTTL))
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(
            pathKey: "1552:a019:0", verdictAge: BrightnessSupport.writeOnlyVerdictTTL + 1))
    }

    func testMissingVerdictOrPathKeyAlwaysProbes() {
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(pathKey: nil, verdictAge: 0))
        // The legacy undated cache leaves no age either, so it reads as
        // already expired on the first rebuild.
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(pathKey: "1552:a019:0", verdictAge: nil))
    }

    func testClockMovedBackProbesAgain() {
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(pathKey: "1552:a019:0", verdictAge: -60))
    }

    // MARK: Dated verdict store

    func testRecordingAPathStampsIt() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(BrightnessSupport.updatedWriteOnlyDDCVerdicts(
            [:], path: "1552:a019:0", now: now, isWriteOnly: true),
                       ["1552:a019:0": now])
    }

    func testRecordingAnExistingPathRestampsIt() {
        let old = Date(timeIntervalSince1970: 900_000)
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(BrightnessSupport.updatedWriteOnlyDDCVerdicts(
            ["1552:a019:0": old], path: "1552:a019:0", now: now, isWriteOnly: true),
                       ["1552:a019:0": now])
    }

    func testDisprovenVerdictIsRemoved() {
        let other = Date(timeIntervalSince1970: 950_000)
        XCTAssertEqual(BrightnessSupport.updatedWriteOnlyDDCVerdicts(
            ["1552:a019:0": Date(timeIntervalSince1970: 900_000),
             "4104:b0e:0": other],
            path: "1552:a019:0", now: Date(), isWriteOnly: false),
                       ["4104:b0e:0": other])
    }

    func testBoundKeepsTheNewestVerdicts() {
        var stored: [String: Date] = [:]
        for index in 0..<16 {
            stored["path\(index)"] = Date(timeIntervalSince1970: Double(index))
        }
        let now = Date(timeIntervalSince1970: 1_000)
        let updated = BrightnessSupport.updatedWriteOnlyDDCVerdicts(
            stored, path: "newest", now: now, isWriteOnly: true)
        XCTAssertEqual(updated.count, 16)
        XCTAssertEqual(updated["newest"], now)
        XCTAssertEqual(updated["path15"], Date(timeIntervalSince1970: 15))
        XCTAssertNil(updated["path0"])
    }

    func testVerdictDatesDropValuesThatAreNotDates() {
        let date = Date(timeIntervalSince1970: 5)
        XCTAssertEqual(BrightnessSupport.writeOnlyVerdictDates(
            ["dated": date, "edited": "not a date", "number": 42]),
                       ["dated": date])
        XCTAssertEqual(BrightnessSupport.writeOnlyVerdictDates(nil), [:])
    }

    // MARK: Path keys without a location

    func testMissingLocationFallsBackToFingerprint() {
        XCTAssertEqual(BrightnessSupport.ddcPathKey(displayFingerprint: "1552:a019:0",
                                                    ioDisplayLocation: ""),
                       "1552:a019:0 (no location)")
    }

    func testFallbackNeverCollidesWithACombinedKey() {
        let fallback = BrightnessSupport.ddcPathKey(displayFingerprint: "1552:a019:0",
                                                    ioDisplayLocation: "")
        let combined = BrightnessSupport.ddcPathKey(displayFingerprint: "1552:a019:0",
                                                    ioDisplayLocation: "IOService:/Ports/1")
        XCTAssertNotEqual(fallback, combined)
        // The fallback carries no separator, so no "fingerprint|location"
        // string can ever equal it.
        XCTAssertFalse(fallback?.contains("|") ?? true)
    }

    func testEmptyFingerprintHasNoKey() {
        XCTAssertNil(BrightnessSupport.ddcPathKey(displayFingerprint: "",
                                                  ioDisplayLocation: "IOService:/Ports/1"))
        XCTAssertNil(BrightnessSupport.ddcPathKey(displayFingerprint: "",
                                                  ioDisplayLocation: ""))
    }

    // MARK: Key ambiguity

    func testSharedFallbackKeyCarriesNoChoices() {
        let shared = BrightnessSupport.ddcPathKey(displayFingerprint: "4104:b0e:0",
                                                  ioDisplayLocation: "")
        XCTAssertTrue(BrightnessSupport.unambiguousPathKeys([shared, shared]).isEmpty)
    }

    func testDistinctKeysStayUnambiguous() {
        let fallback = BrightnessSupport.ddcPathKey(displayFingerprint: "4104:b0e:0",
                                                    ioDisplayLocation: "")
        let combined = BrightnessSupport.ddcPathKey(displayFingerprint: "4104:b0e:0",
                                                    ioDisplayLocation: "IOService:/Ports/2")
        XCTAssertEqual(BrightnessSupport.unambiguousPathKeys([fallback, combined]),
                       Set(["4104:b0e:0 (no location)", "4104:b0e:0|IOService:/Ports/2"]))
    }

    func testNilAndEmptyCandidatesAreIgnored() {
        XCTAssertEqual(BrightnessSupport.unambiguousPathKeys([nil, "", "solo"]),
                       Set(["solo"]))
    }

    func testSharedKeyVerdictNeverSuppressesTheTwinProbe() {
        guard let shared = BrightnessSupport.ddcPathKey(displayFingerprint: "4104:b0e:0",
                                                        ioDisplayLocation: "") else {
            return XCTFail("a non-empty fingerprint must produce a fallback key")
        }
        // Two identical monitors share the fallback key, so no key is
        // unambiguous: the fresh verdict reads as absent and both twins get
        // their probe on the next rebuild.
        let age = BrightnessSupport.verdictAge(
            for: shared,
            unambiguousKeys: [],
            verdicts: [shared: Date(timeIntervalSince1970: 60)],
            now: Date(timeIntervalSince1970: 120))
        XCTAssertNil(age)
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(pathKey: shared, verdictAge: age))
    }

    func testOwnedKeyVerdictAgeIsRead() {
        guard let solo = BrightnessSupport.ddcPathKey(displayFingerprint: "4104:b0e:0",
                                                      ioDisplayLocation: "IOService:/Ports/3") else {
            return XCTFail("a fingerprint with a location must produce a key")
        }
        XCTAssertEqual(BrightnessSupport.verdictAge(
            for: solo,
            unambiguousKeys: [solo],
            verdicts: [solo: Date(timeIntervalSince1970: 60)],
            now: Date(timeIntervalSince1970: 120)), 60)
    }

    // MARK: Post-write readback verdict

    func testDivergingReadbacksReachNonApplyingAtTheThreshold() {
        var streak = 0
        var verdict: BrightnessSupport.ReadbackVerdict?
        for _ in 0..<BrightnessSupport.nonApplyingDivergenceThreshold {
            let decision = BrightnessSupport.readbackVerdict(
                writeAccepted: true, confirmingRead: .replied(current: 30),
                written: 80, consecutiveDivergences: streak)
            verdict = decision.verdict
            streak = decision.divergences
        }
        XCTAssertEqual(verdict, .nonApplying)
        XCTAssertEqual(streak, BrightnessSupport.nonApplyingDivergenceThreshold)
    }

    func testDivergenceBeforeTheThresholdOnlyCounts() {
        let decision = BrightnessSupport.readbackVerdict(
            writeAccepted: true, confirmingRead: .replied(current: 30),
            written: 80, consecutiveDivergences: 0)
        XCTAssertEqual(decision.verdict, .diverged(streak: 1))
        XCTAssertEqual(decision.divergences, 1)
    }

    func testMatchingReadbackConfirmsAndResetsTheStreak() {
        let decision = BrightnessSupport.readbackVerdict(
            writeAccepted: true, confirmingRead: .replied(current: 80),
            written: 80, consecutiveDivergences: 2)
        XCTAssertEqual(decision.verdict, .confirmed)
        XCTAssertEqual(decision.divergences, 0)
    }

    func testReadbackWithinToleranceStillConfirms() {
        // Monitors round to their own hardware step, so one unit off the
        // written value still counts as applied.
        let decision = BrightnessSupport.readbackVerdict(
            writeAccepted: true, confirmingRead: .replied(current: 81),
            written: 80, consecutiveDivergences: 1)
        XCTAssertEqual(decision.verdict, .confirmed)
        XCTAssertEqual(decision.divergences, 0)
    }

    func testFailedReadbackIsInconclusiveAndKeepsTheCount() {
        let decision = BrightnessSupport.readbackVerdict(
            writeAccepted: true, confirmingRead: .failed,
            written: 80, consecutiveDivergences: 1)
        XCTAssertEqual(decision.verdict, .inconclusive)
        XCTAssertEqual(decision.divergences, 1)
    }

    func testUnacceptedWriteHasNoConfirmation() {
        let decision = BrightnessSupport.readbackVerdict(
            writeAccepted: false, confirmingRead: .replied(current: 80),
            written: 80, consecutiveDivergences: 1)
        XCTAssertEqual(decision.verdict, .inconclusive)
        XCTAssertEqual(decision.divergences, 1)
    }

    func testDivergenceAfterAnInconclusiveReadCountsFromWhereItLeft() {
        let held = BrightnessSupport.readbackVerdict(
            writeAccepted: true, confirmingRead: .failed,
            written: 80, consecutiveDivergences: 1)
        let resumed = BrightnessSupport.readbackVerdict(
            writeAccepted: true, confirmingRead: .replied(current: 30),
            written: 80, consecutiveDivergences: held.divergences)
        XCTAssertEqual(resumed.verdict, .diverged(streak: 2))
        XCTAssertEqual(resumed.divergences, 2)
    }

    // MARK: Extended dimming readback

    func testExtendedDimmingReadbackComparesAgainstTheHardwareValue() {
        // A slider level inside the extended range parks the monitor at its
        // hardware minimum, so the confirming read expects that device
        // value, not the slider level the write came from.
        XCTAssertEqual(BrightnessSupport.readbackDeviceValue(
            sliderValue: 0.1, extendedDimming: true, maximum: 100), 0)
        // Mid slider, the hardware component differs from the level itself.
        XCTAssertEqual(BrightnessSupport.readbackDeviceValue(
            sliderValue: 0.5, extendedDimming: true, maximum: 100), 33)
        XCTAssertEqual(BrightnessSupport.readbackDeviceValue(
            sliderValue: 0.5, extendedDimming: false, maximum: 100), 50)
    }

    // MARK: Non-applying verdict

    func testNonApplyingVerdictSharesTheDatedFormatAndTTL() {
        XCTAssertEqual(BrightnessSupport.nonApplyingVerdictTTL,
                       BrightnessSupport.writeOnlyVerdictTTL)
        let now = Date(timeIntervalSince1970: 1_000_000)
        // The dated store format is the write-only one, reused: stamping and
        // disproving work the same.
        XCTAssertEqual(BrightnessSupport.updatedWriteOnlyDDCVerdicts(
            [:], path: "1552:a019:0", now: now, isWriteOnly: true),
                       ["1552:a019:0": now])
        XCTAssertEqual(BrightnessSupport.updatedWriteOnlyDDCVerdicts(
            ["1552:a019:0": now], path: "1552:a019:0", now: now, isWriteOnly: false), [:])
    }

    func testFreshNonApplyingVerdictStaysOnPictureDimming() {
        XCTAssertFalse(BrightnessSupport.shouldProbeDDC(
            pathKey: "1552:a019:0", verdictAge: BrightnessSupport.nonApplyingVerdictTTL - 1,
            ttl: BrightnessSupport.nonApplyingVerdictTTL))
    }

    func testExpiredNonApplyingVerdictProbesAgain() {
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(
            pathKey: "1552:a019:0", verdictAge: BrightnessSupport.nonApplyingVerdictTTL,
            ttl: BrightnessSupport.nonApplyingVerdictTTL))
    }

    func testSharedKeyNeverCarriesANonApplyingVerdict() {
        guard let shared = BrightnessSupport.ddcPathKey(displayFingerprint: "4104:b0e:0",
                                                        ioDisplayLocation: "") else {
            return XCTFail("a non-empty fingerprint must produce a fallback key")
        }
        // Two identical monitors share the fallback key, so the gate reads no
        // verdict at all and neither twin is held on picture dimming by the
        // other's channel.
        let age = BrightnessSupport.verdictAge(
            for: shared,
            unambiguousKeys: [],
            verdicts: [shared: Date(timeIntervalSince1970: 60)],
            now: Date(timeIntervalSince1970: 120))
        XCTAssertNil(age)
        XCTAssertTrue(BrightnessSupport.shouldProbeDDC(
            pathKey: shared, verdictAge: age, ttl: BrightnessSupport.nonApplyingVerdictTTL))
    }

    // MARK: Phased display-to-service matching

    private func pair(_ displayIndex: Int, _ serviceOrdinal: Int,
                      score: Int, sameLocation: Bool = false)
        -> BrightnessSupport.DisplayServicePair {
        BrightnessSupport.DisplayServicePair(displayIndex: displayIndex,
                                             serviceOrdinal: serviceOrdinal,
                                             score: score, sameLocation: sameLocation)
    }

    func testIdenticalDisplaysWithDistinctLocationsMatchTheirOwnServices() {
        // Two identical monitors whose connections still name themselves:
        // the location pairs settle first and cannot cross.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 16, sameLocation: true),
            pair(0, 2, score: 6),
            pair(1, 1, score: 6),
            pair(1, 2, score: 16, sameLocation: true),
        ])
        XCTAssertEqual(assignment.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(assignment.matches[0]?.basis, .location)
        XCTAssertEqual(assignment.matches[1]?.serviceOrdinal, 2)
        XCTAssertEqual(assignment.matches[1]?.basis, .location)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testIdenticalDisplaysWithoutDiscriminantStayAmbiguous() {
        // Same EDID, no location, serial zero: every pair ties with every
        // other, so neither display receives a service by sort order.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 6), pair(0, 2, score: 6),
            pair(1, 1, score: 6), pair(1, 2, score: 6),
        ])
        XCTAssertTrue(assignment.matches.isEmpty)
        XCTAssertEqual(assignment.ambiguousDisplayIndices, [0, 1])
    }

    func testSingletonDisplayAndServiceMatchWithAndWithoutLocation() {
        let byLocation = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 11, sameLocation: true),
        ])
        XCTAssertEqual(byLocation.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(byLocation.matches[0]?.basis, .location)
        let byScore = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 4),
        ])
        XCTAssertEqual(byScore.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(byScore.matches[0]?.basis, .score)
    }

    func testSingletonWithSparseEDIDMatchesByExclusion() {
        // The legacy fallback: one display, one service, EDID too sparse to
        // score at all.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 0),
        ])
        XCTAssertEqual(assignment.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(assignment.matches[0]?.basis, .exclusion)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testResidualAfterALocationMatchClosesByExclusion() {
        // One display settles by location; the leftover display and service
        // can only belong to each other, even when the residual pair is too
        // sparse to score.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 16, sameLocation: true),
            pair(0, 2, score: 6),
            pair(1, 1, score: 6),
            pair(1, 2, score: 0),
        ])
        XCTAssertEqual(assignment.matches[0]?.basis, .location)
        XCTAssertEqual(assignment.matches[1]?.serviceOrdinal, 2)
        XCTAssertEqual(assignment.matches[1]?.basis, .exclusion)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testDistinctSerialsBreakTheTieBetweenSameModelMonitors() {
        // Each diagonal pair is strictly better than its alternatives, so
        // both settle by score and nothing stays ambiguous.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 6), pair(0, 2, score: 5),
            pair(1, 1, score: 5), pair(1, 2, score: 6),
        ])
        XCTAssertEqual(assignment.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(assignment.matches[1]?.serviceOrdinal, 2)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testPartialTieLeavesOnlyTheTiedCycleAmbiguous() {
        // One dominant pair settles; the remaining cycle of ties stays
        // ambiguous without affecting the settled match.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 7),
            pair(0, 2, score: 4), pair(0, 3, score: 3),
            pair(1, 1, score: 3), pair(1, 2, score: 4), pair(1, 3, score: 4),
            pair(2, 1, score: 3), pair(2, 2, score: 4), pair(2, 3, score: 4),
        ])
        XCTAssertEqual(assignment.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(assignment.matches[0]?.basis, .score)
        XCTAssertNil(assignment.matches[1])
        XCTAssertNil(assignment.matches[2])
        XCTAssertEqual(assignment.ambiguousDisplayIndices, [1, 2])
    }

    func testDistinctDisplaysWithDifferentScoresAllMatch() {
        // The everyday case: no ties anywhere, everything settles by score.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 5), pair(0, 2, score: 2),
            pair(1, 1, score: 1), pair(1, 2, score: 4),
        ])
        XCTAssertEqual(assignment.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(assignment.matches[1]?.serviceOrdinal, 2)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testDominantMatchSettlesThePairLeftBesideIt() {
        // Display 0 has two services at the same score, which would tie, but
        // the dominant pair on the other side takes one of them and the
        // leftover settles without any ambiguity.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 5), pair(0, 2, score: 5),
            pair(1, 2, score: 7),
        ])
        XCTAssertEqual(assignment.matches[0]?.serviceOrdinal, 1)
        XCTAssertEqual(assignment.matches[1]?.serviceOrdinal, 2)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testZeroScorePairsNeverMatchOutsideTheSingletonCase() {
        // Two displays and two services with nothing in common: no match for
        // any of them, and no ambiguity either, because there is nothing to
        // tie over.
        let assignment = BrightnessSupport.assignServices(pairs: [
            pair(0, 1, score: 0), pair(0, 2, score: 0),
            pair(1, 1, score: 0), pair(1, 2, score: 0),
        ])
        XCTAssertTrue(assignment.matches.isEmpty)
        XCTAssertTrue(assignment.ambiguousDisplayIndices.isEmpty)
    }

    func testEmptyLocationIsNeverALocationMatch() {
        var service = BrightnessSupport.ServiceIdentity()
        var display = BrightnessSupport.DisplayIdentity()
        // Two connections that both lack a location must not read as a
        // location match with each other.
        service.ioDisplayLocation = ""
        display.ioDisplayLocation = ""
        XCTAssertFalse(BrightnessSupport.sharesLocation(service: service, display: display))
        service.ioDisplayLocation = "IOService:/Ports/1"
        display.ioDisplayLocation = nil
        XCTAssertFalse(BrightnessSupport.sharesLocation(service: service, display: display))
        display.ioDisplayLocation = "IOService:/Ports/1"
        XCTAssertTrue(BrightnessSupport.sharesLocation(service: service, display: display))
    }

    // MARK: DDC VCP reply parsing

    private func makeDDCReply(code: UInt8, current: UInt16, maximum: UInt16) -> [UInt8] {
        var bytes: [UInt8] = [
            0x6E, 0x88, 0x02, 0x00,
            code, 0x00,
            UInt8(maximum >> 8), UInt8(maximum & 0xFF),
            UInt8(current >> 8), UInt8(current & 0xFF),
        ]
        let checksum = bytes.reduce(UInt8(0x50)) { $0 ^ $1 }
        bytes.append(checksum)
        return bytes
    }

    func testParseReplyAcceptsMatchingVCPCodeAndRejectsOtherCodes() {
        let luminanceReply = makeDDCReply(code: BrightnessSupport.luminanceCode,
                                          current: 45,
                                          maximum: 100)
        let parsed = BrightnessSupport.parseReply(luminanceReply)
        XCTAssertEqual(parsed?.current, 45)
        XCTAssertEqual(parsed?.maximum, 100)

        let contrastReply = makeDDCReply(code: 0x12, current: 70, maximum: 100)
        XCTAssertNil(BrightnessSupport.parseReply(contrastReply))

        var corruptedReply = luminanceReply
        corruptedReply[corruptedReply.count - 1] ^= 0xFF
        XCTAssertNil(BrightnessSupport.parseReply(corruptedReply))
    }
}
