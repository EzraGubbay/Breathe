import Foundation
import HealthKit
import os

/// HealthKit authorization, mindful-minutes logging with rich metadata,
/// and post-session HRV (SDNN) reads (specs.md §3 HealthKit Integration).
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    let store = HKHealthStore()
    private let log = Logger(subsystem: "com.ezragubbay.breathe", category: "healthkit")

    // Custom metadata keys — HealthKit permits arbitrary custom String keys.
    // (specs.md originally suggested HKMetadataKeyWasUserEntered, but that key
    // is a Bool; custom keys are the supported way to store session context.)
    enum MetadataKey {
        static let sessionType = "SessionType"
        static let bpm = "BPM"
        static let rounds = "Rounds"
    }

    var mindfulType: HKCategoryType { HKCategoryType(.mindfulSession) }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // workoutType is required for HKLiveWorkoutBuilder.beginCollection even
        // though the workout is always discarded, never saved.
        let toShare: Set<HKSampleType> = [mindfulType, HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
        ]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            log.info("HealthKit authorization requested")
        } catch {
            log.error("HealthKit authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Writes the session as Mindful Minutes with session context preserved
    /// in metadata. Returns the saved sample's UUID.
    @discardableResult
    func saveMindfulSession(configuration: SessionConfiguration,
                            start: Date,
                            end: Date) async throws -> UUID {
        let sessionID = UUID()
        var metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: sessionID.uuidString,
            MetadataKey.sessionType: configuration.type.rawValue,
        ]
        if configuration.type.usesBPM {
            metadata[MetadataKey.bpm] = String(configuration.breathsPerMinute)
        }
        if configuration.type.usesRounds {
            metadata[MetadataKey.rounds] = String(configuration.rounds)
        }

        let sample = HKCategorySample(type: mindfulType,
                                      value: HKCategoryValue.notApplicable.rawValue,
                                      start: start,
                                      end: end,
                                      metadata: metadata)
        try await store.save(sample)
        log.info("saved mindful sample \(sample.uuid, privacy: .public) metadata: \(String(describing: metadata), privacy: .public)")
        return sample.uuid
    }

    /// Most recent SDNN reading at/after the session start, if the system has
    /// produced one. Queried immediately post-session (specs.md §3 HRV Extraction).
    func latestHRV(since start: Date) async -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: 1,
                                      sortDescriptors: [sort]) { [log] _, samples, error in
                if let error {
                    log.error("HRV query failed: \(error.localizedDescription, privacy: .public)")
                }
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .secondUnit(with: .milli))
                log.info("post-session SDNN query returned \(value.map { String($0) } ?? "nil", privacy: .public)")
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
