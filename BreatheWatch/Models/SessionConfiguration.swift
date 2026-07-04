import Foundation

/// User-selected knobs for a session, validated per protocol.
struct SessionConfiguration: Equatable {
    var type: SessionType
    /// Total session length for time-based protocols.
    var duration: TimeInterval
    /// Breaths per minute. Resonance: 4.0–7.0. Meditation: 0 means unguided.
    var breathsPerMinute: Double
    /// Wim Hof only.
    var rounds: Int

    static let durationChoices: [TimeInterval] = [1, 5, 10, 20, 30, 45, 60, 90].map { $0 * 60 }
    static let resonanceBPMChoices: [Double] = stride(from: 4.0, through: 7.0, by: 0.5).map { $0 }
    static let meditationBPMChoices: [Double] = [0] + stride(from: 4.0, through: 7.0, by: 0.5).map { $0 }
    static let roundChoices: [Int] = [3, 4, 5]

    static func `default`(for type: SessionType) -> SessionConfiguration {
        switch type {
        case .resonance:
            return .init(type: type, duration: 10 * 60, breathsPerMinute: 5.5, rounds: 0)
        case .box:
            return .init(type: type, duration: 5 * 60, breathsPerMinute: 0, rounds: 0)
        case .sigh:
            return .init(type: type, duration: 5 * 60, breathsPerMinute: 0, rounds: 0)
        case .wimHof:
            return .init(type: type, duration: 0, breathsPerMinute: 0, rounds: 3)
        case .meditation:
            return .init(type: type, duration: 10 * 60, breathsPerMinute: 0, rounds: 0)
        }
    }
}
