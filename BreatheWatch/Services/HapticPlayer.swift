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
                playDynamicPattern(for: phase.kind, duration: duration)
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

    private func playDynamicPattern(for kind: BreathPhaseKind, duration: TimeInterval) {
        dynamicHapticTask = Task {
            var t: TimeInterval = 0
            let minGap: TimeInterval = 0.08 // Denser, rapid peak
            let maxGap: TimeInterval = 1.2  // Slow start/end
            let decelerationDuration: TimeInterval = 0.4 // Closer to the edge
            
            let heavyHaptic: WKHapticType = (kind == .inhale) ? .directionUp : .directionDown
            let lightHaptic: WKHapticType = .click
            let hardwareLimit: TimeInterval = 0.22 // Threshold to switch to clicks to avoid queue grouping
            
            while t < duration && !Task.isCancelled {
                
                let gap: TimeInterval
                let remaining = duration - t
                
                if remaining <= decelerationDuration {
                    // Deceleration: gap increases from minGap to maxGap as lungs reach full capacity
                    let progress = 1.0 - (remaining / decelerationDuration) // 0.0 to 1.0
                    gap = minGap + (maxGap - minGap) * (progress * progress)
                } else {
                    // Acceleration: gap decreases from maxGap to minGap as they take in breath
                    let accelerationDuration = duration - decelerationDuration
                    let progress = (accelerationDuration > 0) ? (t / accelerationDuration) : 1.0
                    gap = maxGap - (maxGap - minGap) * progress
                }
                
                // Play heavy bump if gap is wide enough, otherwise switch to rapid light clicks
                let hapticToPlay = (gap < hardwareLimit) ? lightHaptic : heavyHaptic
                WKInterfaceDevice.current().play(hapticToPlay)
                
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
