import Foundation
import HealthKit
import os

/// Sensor keep-alive (specs.md §3): runs an HKWorkoutSession so the optical
/// heart rate sensor fires continuously for the whole session. The workout is
/// DISCARDED at the end — never saved — so Activity Rings are not polluted
/// and no active calories are logged.
final class WorkoutSessionManager: NSObject, ObservableObject {
    @Published private(set) var latestHeartRate: Double?

    /// Called on every batch of new heart rate samples: (value bpm, sample date).
    var onHeartRateSample: ((Double, Date) -> Void)?

    private let healthStore: HKHealthStore
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let log = Logger(subsystem: "com.ezragubbay.breathe", category: "workout")

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func start() {
        let configuration = HKWorkoutConfiguration()
        // Mind & body: closest classification, minimal energy accounting.
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                         workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [log] success, error in
                if let error {
                    log.error("beginCollection failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    log.info("workout collection started (sensor keep-alive active)")
                }
            }
        } catch {
            log.error("could not create workout session: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        guard let session, let builder else { return }
        session.end()
        builder.endCollection(withEnd: Date()) { [log] _, _ in
            // Crucial: discard, don't save — keeps Activity Rings clean.
            builder.discardWorkout()
            log.info("workout ended and DISCARDED (rings untouched)")
        }
        self.session = nil
        self.builder = nil
    }
}

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        log.info("workout state \(fromState.rawValue) -> \(toState.rawValue)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        log.error("workout session failed: \(error.localizedDescription, privacy: .public)")
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRateType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity() else { return }

        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let date = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
        DispatchQueue.main.async {
            self.latestHeartRate = bpm
            self.onHeartRateSample?(bpm, date)
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
