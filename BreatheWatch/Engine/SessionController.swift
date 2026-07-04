import Foundation
import Combine
import os

/// Everything a session needs to know at the end, for SummaryView.
struct SessionSummary {
    let configuration: SessionConfiguration
    let start: Date
    let end: Date
    let averageHeartRate: Double?
    let minHeartRate: Double?
    let maxHeartRate: Double?
    /// Resonance only: post-session SDNN (ms), if the system produced a reading.
    let hrvSDNN: Double?
    /// Sigh only: final-minute minus first-minute average HR (negative = calmer).
    let heartRateDelta: Double?
    /// Wim Hof only: measured retention hold per round.
    let retentionDurations: [TimeInterval]
    let savedToHealth: Bool

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Orchestrates one session: breathing engine + sensor keep-alive workout +
/// extended runtime session + haptics + metrics + HealthKit write-out.
@MainActor
final class SessionController: ObservableObject {
    let configuration: SessionConfiguration
    let engine: BreathingEngine
    let workout: WorkoutSessionManager

    @Published private(set) var summary: SessionSummary?
    @Published private(set) var isFinishing = false

    private let runtime = ExtendedRuntimeManager()
    private let healthKit = HealthKitService.shared
    private var metrics = MetricsCollector()
    private let log = Logger(subsystem: "com.ezragubbay.breathe", category: "session")

    init(configuration: SessionConfiguration) {
        self.configuration = configuration
        self.engine = BreathingEngine(plan: ProtocolTimeline.plan(for: configuration),
                                      totalRounds: configuration.rounds)
        self.workout = WorkoutSessionManager(healthStore: healthKit.store)

        engine.onPhaseStart = { [configuration] phase in
            HapticPlayer.shared.playPhaseStart(phase, sessionType: configuration.type)
        }
        engine.onFinish = { [weak self] in
            self?.sessionDidFinish()
        }
        workout.onHeartRateSample = { [weak self] bpm, date in
            self?.metrics.add(bpm: bpm, at: date)
        }
    }

    func start() {
        log.info("starting \(self.configuration.type.rawValue, privacy: .public) session")
        runtime.start()
        workout.start()
        HapticPlayer.shared.playSessionStart()
        engine.start()
    }

    /// User hit End early.
    func endEarly() {
        engine.finish()
    }

    private func sessionDidFinish() {
        guard !isFinishing else { return }
        isFinishing = true
        HapticPlayer.shared.playSessionEnd()
        workout.stop()
        runtime.stop()

        let start = engine.sessionStart ?? Date()
        let end = engine.sessionEnd ?? Date()

        Task {
            var saved = false
            do {
                try await healthKit.saveMindfulSession(configuration: configuration,
                                                       start: start, end: end)
                saved = true
            } catch {
                log.error("mindful sample save failed: \(error.localizedDescription, privacy: .public)")
            }

            let hrv = configuration.type.tracksHRV
                ? await healthKit.latestHRV(since: start)
                : nil

            summary = SessionSummary(
                configuration: configuration,
                start: start,
                end: end,
                averageHeartRate: metrics.averageHeartRate,
                minHeartRate: metrics.minHeartRate,
                maxHeartRate: metrics.maxHeartRate,
                hrvSDNN: hrv,
                heartRateDelta: configuration.type.tracksHeartRateDelta
                    ? metrics.heartRateDelta(sessionStart: start, sessionEnd: end)
                    : nil,
                retentionDurations: engine.retentionDurations,
                savedToHealth: saved
            )
        }
    }
}
