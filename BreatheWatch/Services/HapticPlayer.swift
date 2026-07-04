import WatchKit
import os

/// Battery-critical (specs.md §Haptic Engine Optimization, SE 2nd Gen):
/// ONLY discrete haptic transients at phase starts. Never continuous rumble,
/// never repeating haptics for the length of a breath.
final class HapticPlayer {
    static let shared = HapticPlayer()
    private let log = Logger(subsystem: "com.ezragubbay.breathe", category: "haptics")

    func playPhaseStart(_ phase: BreathPhase, sessionType: SessionType) {
        let haptic: WKHapticType
        switch phase.kind {
        case .inhale: haptic = .directionUp
        case .exhale: haptic = .directionDown
        case .holdAfterInhale, .holdAfterExhale: haptic = .click
        case .retention: haptic = .stop
        case .recovery: haptic = .start
        }
        // Unpaced meditation gets no per-phase haptics (it has no phases anyway);
        // sigh's "two rapid taps" arise from its two back-to-back inhale phases.
        WKInterfaceDevice.current().play(haptic)
        log.debug("haptic \(String(describing: haptic.rawValue)) for phase \(phase.kind.label, privacy: .public)")
    }

    func playSessionStart() {
        WKInterfaceDevice.current().play(.start)
        log.debug("haptic session start")
    }

    func playSessionEnd() {
        WKInterfaceDevice.current().play(.success)
        log.debug("haptic session end")
    }
}
