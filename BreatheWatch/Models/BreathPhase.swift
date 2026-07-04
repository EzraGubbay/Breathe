import Foundation

enum BreathPhaseKind: Equatable {
    case inhale
    case holdAfterInhale
    case exhale
    case holdAfterExhale
    /// Wim Hof breath retention (hold on empty lungs). Open-ended: user taps to advance.
    case retention
    /// Wim Hof recovery breath (hold on full lungs, fixed length).
    case recovery

    var label: String {
        switch self {
        case .inhale: return "Inhale"
        case .holdAfterInhale, .holdAfterExhale: return "Hold"
        case .exhale: return "Exhale"
        case .retention: return "Hold — tap to breathe"
        case .recovery: return "Recovery hold"
        }
    }
}

/// One step of a breathing protocol. `duration == nil` means open-ended
/// (advances only on user tap — Wim Hof retention).
struct BreathPhase: Equatable {
    var kind: BreathPhaseKind
    var duration: TimeInterval?

    init(_ kind: BreathPhaseKind, duration: TimeInterval?) {
        self.kind = kind
        self.duration = duration
    }
}

/// How a session's phases unfold over time.
enum SessionPlan: Equatable {
    /// A short cycle repeated until `totalDuration` elapses (Resonance, Box, Sigh,
    /// paced Meditation). An empty cycle means unpaced (unguided Meditation).
    case timed(cycle: [BreathPhase], totalDuration: TimeInterval)
    /// A finite phase sequence (Wim Hof rounds, retention phases open-ended).
    case sequence(phases: [BreathPhase])
}
