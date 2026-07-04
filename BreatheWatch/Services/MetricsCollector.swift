import Foundation

/// Buffers live heart rate samples during a session and derives summary
/// metrics: min/avg/max HR and the acute stress-reduction signal for the
/// Physiological Sigh — resting HR delta from minute 1 to the final minute
/// (specs.md §2C).
struct MetricsCollector {
    private(set) var samples: [(date: Date, bpm: Double)] = []

    mutating func add(bpm: Double, at date: Date) {
        samples.append((date, bpm))
    }

    var averageHeartRate: Double? { average(of: samples.map(\.bpm)) }
    var minHeartRate: Double? { samples.map(\.bpm).min() }
    var maxHeartRate: Double? { samples.map(\.bpm).max() }

    /// avg(final minute) - avg(first minute); negative = HR dropped (good).
    /// Nil until the session spans at least two distinct minutes of data.
    func heartRateDelta(sessionStart: Date, sessionEnd: Date) -> Double? {
        guard sessionEnd.timeIntervalSince(sessionStart) >= 120 else { return nil }
        let firstMinute = samples.filter {
            $0.date >= sessionStart && $0.date < sessionStart.addingTimeInterval(60)
        }
        let lastMinute = samples.filter {
            $0.date >= sessionEnd.addingTimeInterval(-60) && $0.date <= sessionEnd
        }
        guard let first = average(of: firstMinute.map(\.bpm)),
              let last = average(of: lastMinute.map(\.bpm)) else { return nil }
        return last - first
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
