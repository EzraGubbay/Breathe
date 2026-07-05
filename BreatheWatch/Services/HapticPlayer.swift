import WatchKit
import os

/// Battery-critical (specs.md §Haptic Engine Optimization, SE 2nd Gen):
/// Since watchOS doesn't support CoreHaptics, we manually pace WKHapticType.click 
/// using an async Task. The HKWorkoutSession keeps the app alive to fire these.
final class HapticPlayer {
    static let shared = HapticPlayer()
    private let log = Logger(subsystem: "com.ezragubbay.breathe", category: "haptics")
    
    private var dynamicHapticTask: Task<Void, Never>?

    func playPhaseStart(_ phase: BreathPhase, sessionType: SessionType) {
        dynamicHapticTask?.cancel()
        
        if sessionType == .resonance || sessionType == .sigh {
            if let duration = phase.duration, (phase.kind == .inhale || phase.kind == .exhale) {
                playDynamicPattern(duration: duration)
                return
            }
        }

        let haptic: WKHapticType
        switch phase.kind {
        case .inhale: haptic = .directionUp
        case .exhale: haptic = .directionDown
        case .holdAfterInhale, .holdAfterExhale: haptic = .click
        case .retention: haptic = .stop
        case .recovery: haptic = .start
        }
        WKInterfaceDevice.current().play(haptic)
        log.debug("haptic \(String(describing: haptic.rawValue)) for phase \(phase.kind.label, privacy: .public)")
    }

    private func playDynamicPattern(duration: TimeInterval) {
        dynamicHapticTask = Task {
            var t: TimeInterval = 0
            let minGap: TimeInterval = 0.5
            let maxGap: TimeInterval = 1.6
            let flutterDuration: TimeInterval = 1.5
            
            while t < duration && !Task.isCancelled {
                WKInterfaceDevice.current().play(.click)
                
                let gap: TimeInterval
                let remaining = duration - t
                
                if remaining <= flutterDuration {
                    let progress = 1.0 - (remaining / flutterDuration)
                    gap = 0.15 + (0.35 * progress)
                } else {
                    let mainDuration = duration - flutterDuration
                    if mainDuration > 0 {
                        let normalized = t / mainDuration
                        let centered = (normalized - 0.5) * 2.0
                        gap = maxGap - (maxGap - minGap) * (centered * centered)
                    } else {
                        gap = minGap
                    }
                }
                
                t += gap
                
                do {
                    try await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    func playSessionStart() {
        WKInterfaceDevice.current().play(.start)
        log.debug("haptic session start")
    }

    func playSessionEnd() {
        dynamicHapticTask?.cancel()
        WKInterfaceDevice.current().play(.success)
        log.debug("haptic session end")
    }
}
