import Foundation

/// Pure mapping from a `SessionConfiguration` to a `SessionPlan`.
/// No timers, no UI, no HealthKit — fully unit-testable.
enum ProtocolTimeline {

    // Wim Hof tuning constants.
    static let wimHofBreathsPerRound = 35
    static let wimHofFastBreathHalf: TimeInterval = 0.85   // inhale and exhale each
    static let wimHofRecoveryHold: TimeInterval = 15

    // Physiological sigh tuning constants (specs.md §2C).
    static let sighFirstInhale: TimeInterval = 1.5
    static let sighSecondInhale: TimeInterval = 1.0
    static let sighExhale: TimeInterval = 6.0
    static let sighRest: TimeInterval = 3.0                // relaxed pause between sighs

    static let boxSide: TimeInterval = 4.0

    static func plan(for config: SessionConfiguration) -> SessionPlan {
        switch config.type {
        case .resonance:
            return .timed(cycle: resonanceCycle(bpm: config.breathsPerMinute),
                          totalDuration: config.duration)

        case .box:
            let cycle = [
                BreathPhase(.inhale, duration: boxSide),
                BreathPhase(.holdAfterInhale, duration: boxSide),
                BreathPhase(.exhale, duration: boxSide),
                BreathPhase(.holdAfterExhale, duration: boxSide),
            ]
            return .timed(cycle: cycle, totalDuration: config.duration)

        case .sigh:
            let cycle = [
                BreathPhase(.inhale, duration: sighFirstInhale),
                BreathPhase(.inhale, duration: sighSecondInhale),
                BreathPhase(.exhale, duration: sighExhale),
                BreathPhase(.holdAfterExhale, duration: sighRest),
            ]
            return .timed(cycle: cycle, totalDuration: config.duration)

        case .wimHof:
            var phases: [BreathPhase] = []
            for _ in 0..<max(1, config.rounds) {
                for _ in 0..<wimHofBreathsPerRound {
                    phases.append(BreathPhase(.inhale, duration: wimHofFastBreathHalf))
                    phases.append(BreathPhase(.exhale, duration: wimHofFastBreathHalf))
                }
                phases.append(BreathPhase(.retention, duration: nil))
                phases.append(BreathPhase(.recovery, duration: wimHofRecoveryHold))
            }
            return .sequence(phases: phases)

        case .meditation:
            let cycle = config.breathsPerMinute > 0
                ? resonanceCycle(bpm: config.breathsPerMinute)
                : []
            return .timed(cycle: cycle, totalDuration: config.duration)
        }
    }

    /// Symmetric inhale/exhale cycle at the given pace.
    private static func resonanceCycle(bpm: Double) -> [BreathPhase] {
        let period = 60.0 / bpm
        return [
            BreathPhase(.inhale, duration: period / 2),
            BreathPhase(.exhale, duration: period / 2),
        ]
    }
}
