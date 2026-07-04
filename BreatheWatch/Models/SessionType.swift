import Foundation

/// The five core respiratory and meditation protocols (specs.md §2).
enum SessionType: String, CaseIterable, Identifiable, Codable {
    case resonance = "Resonance"
    case box = "Box"
    case sigh = "Sigh"
    case wimHof = "WimHof"
    case meditation = "Meditation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .resonance: return "Resonance"
        case .box: return "Box Breathing"
        case .sigh: return "Physiological Sigh"
        case .wimHof: return "Wim Hof"
        case .meditation: return "Meditation"
        }
    }

    var tagline: String {
        switch self {
        case .resonance: return "Coherent breathing for HRV"
        case .box: return "Inhale · Hold · Exhale · Hold"
        case .sigh: return "Double inhale, long exhale"
        case .wimHof: return "Hyperventilate, then hold"
        case .meditation: return "Open mindfulness"
        }
    }

    var systemImage: String {
        switch self {
        case .resonance: return "waveform.path.ecg"
        case .box: return "square"
        case .sigh: return "wind"
        case .wimHof: return "bolt.fill"
        case .meditation: return "leaf.fill"
        }
    }

    /// Wim Hof is configured by rounds; everything else by total time.
    var usesRounds: Bool { self == .wimHof }

    /// Protocols where the user picks a breaths-per-minute pace.
    var usesBPM: Bool { self == .resonance || self == .meditation }

    /// Resonance must explicitly trigger and track HRV (specs.md §2A).
    var tracksHRV: Bool { self == .resonance }

    /// Sigh tracks the minute-1 → final-minute heart rate delta (specs.md §2C).
    var tracksHeartRateDelta: Bool { self == .sigh }
}
