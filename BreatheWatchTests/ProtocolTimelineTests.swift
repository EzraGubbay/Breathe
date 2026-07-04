import XCTest
@testable import Breathe

final class ProtocolTimelineTests: XCTestCase {

    func testResonanceCycleMatchesBPM() {
        var config = SessionConfiguration.default(for: .resonance)
        config.breathsPerMinute = 6.0
        config.duration = 600

        guard case .timed(let cycle, let total) = ProtocolTimeline.plan(for: config) else {
            return XCTFail("resonance should be a timed plan")
        }
        XCTAssertEqual(total, 600)
        XCTAssertEqual(cycle.map(\.kind), [.inhale, .exhale])
        // 6 BPM → 10s per breath → 5s inhale, 5s exhale.
        XCTAssertEqual(cycle[0].duration, 5.0)
        XCTAssertEqual(cycle[1].duration, 5.0)
    }

    func testResonanceFractionalBPM() {
        var config = SessionConfiguration.default(for: .resonance)
        config.breathsPerMinute = 5.5

        guard case .timed(let cycle, _) = ProtocolTimeline.plan(for: config) else {
            return XCTFail()
        }
        XCTAssertEqual(cycle[0].duration!, 60.0 / 5.5 / 2, accuracy: 0.001)
    }

    func testBoxIsFourEqualSides() {
        let config = SessionConfiguration.default(for: .box)
        guard case .timed(let cycle, _) = ProtocolTimeline.plan(for: config) else {
            return XCTFail()
        }
        XCTAssertEqual(cycle.map(\.kind),
                       [.inhale, .holdAfterInhale, .exhale, .holdAfterExhale])
        XCTAssertTrue(cycle.allSatisfy { $0.duration == ProtocolTimeline.boxSide })
    }

    func testSighIsDoubleInhaleLongExhale() {
        let config = SessionConfiguration.default(for: .sigh)
        guard case .timed(let cycle, _) = ProtocolTimeline.plan(for: config) else {
            return XCTFail()
        }
        XCTAssertEqual(cycle.map(\.kind), [.inhale, .inhale, .exhale, .holdAfterExhale])
        XCTAssertEqual(cycle[0].duration, ProtocolTimeline.sighFirstInhale)
        XCTAssertEqual(cycle[1].duration, ProtocolTimeline.sighSecondInhale)
        XCTAssertEqual(cycle[2].duration, ProtocolTimeline.sighExhale)
        // Extended exhale must dominate the inhales (physiological requirement).
        XCTAssertGreaterThan(cycle[2].duration!, cycle[0].duration! + cycle[1].duration!)
    }

    func testWimHofRoundStructure() {
        var config = SessionConfiguration.default(for: .wimHof)
        config.rounds = 3

        guard case .sequence(let phases) = ProtocolTimeline.plan(for: config) else {
            return XCTFail("wim hof should be a sequence plan")
        }
        let perRound = ProtocolTimeline.wimHofBreathsPerRound * 2 + 2
        XCTAssertEqual(phases.count, perRound * 3)

        // Each round: fast breaths, then open-ended retention, then fixed recovery.
        let firstRound = Array(phases.prefix(perRound))
        XCTAssertTrue(firstRound.dropLast(2).allSatisfy {
            ($0.kind == .inhale || $0.kind == .exhale)
                && $0.duration == ProtocolTimeline.wimHofFastBreathHalf
        })
        XCTAssertEqual(firstRound[perRound - 2].kind, .retention)
        XCTAssertNil(firstRound[perRound - 2].duration, "retention must be open-ended (tap to advance)")
        XCTAssertEqual(firstRound[perRound - 1].kind, .recovery)
        XCTAssertEqual(firstRound[perRound - 1].duration, ProtocolTimeline.wimHofRecoveryHold)
    }

    func testUnguidedMeditationHasNoPacing() {
        var config = SessionConfiguration.default(for: .meditation)
        config.breathsPerMinute = 0
        config.duration = 1200

        guard case .timed(let cycle, let total) = ProtocolTimeline.plan(for: config) else {
            return XCTFail()
        }
        XCTAssertTrue(cycle.isEmpty, "BPM 0 means unguided — no pacing phases")
        XCTAssertEqual(total, 1200)
    }

    func testPacedMeditationUsesBPM() {
        var config = SessionConfiguration.default(for: .meditation)
        config.breathsPerMinute = 4.0

        guard case .timed(let cycle, _) = ProtocolTimeline.plan(for: config) else {
            return XCTFail()
        }
        XCTAssertEqual(cycle.map(\.kind), [.inhale, .exhale])
        XCTAssertEqual(cycle[0].duration, 7.5)
    }
}

final class MetricsCollectorTests: XCTestCase {

    func testHeartRateDelta() {
        var metrics = MetricsCollector()
        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(300)

        // Minute 1: ~80 bpm. Final minute: ~68 bpm.
        metrics.add(bpm: 82, at: start.addingTimeInterval(10))
        metrics.add(bpm: 78, at: start.addingTimeInterval(50))
        metrics.add(bpm: 70, at: end.addingTimeInterval(-40))
        metrics.add(bpm: 66, at: end.addingTimeInterval(-10))

        let delta = metrics.heartRateDelta(sessionStart: start, sessionEnd: end)
        XCTAssertEqual(delta!, -12, accuracy: 0.001)
    }

    func testDeltaNilForShortSessions() {
        var metrics = MetricsCollector()
        let start = Date()
        metrics.add(bpm: 70, at: start)
        XCTAssertNil(metrics.heartRateDelta(sessionStart: start,
                                            sessionEnd: start.addingTimeInterval(90)))
    }

    func testSummaryStatistics() {
        var metrics = MetricsCollector()
        let now = Date()
        for (i, bpm) in [60.0, 70.0, 80.0].enumerated() {
            metrics.add(bpm: bpm, at: now.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(metrics.averageHeartRate, 70)
        XCTAssertEqual(metrics.minHeartRate, 60)
        XCTAssertEqual(metrics.maxHeartRate, 80)
    }
}
