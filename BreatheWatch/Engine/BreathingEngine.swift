import Foundation
import Combine

/// Walks a `SessionPlan` in real time. Schedules one timer per phase transition
/// (no high-frequency ticking — SE battery constraint). Views derive continuous
/// animation from `phaseStartDate` + phase duration via SwiftUI's animation clock,
/// so the engine only publishes at phase boundaries.
@MainActor
final class BreathingEngine: ObservableObject {

    enum State: Equatable {
        case idle
        case running
        /// Open-ended phase (Wim Hof retention) — waiting for user tap.
        case awaitingTap
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentPhase: BreathPhase?
    @Published private(set) var phaseStartDate: Date = .distantPast
    /// 1-based round counter for sequence plans (Wim Hof).
    @Published private(set) var currentRound: Int = 1

    private(set) var sessionStart: Date?
    private(set) var sessionEnd: Date?
    /// Measured length of each completed retention hold (Wim Hof summary).
    private(set) var retentionDurations: [TimeInterval] = []

    /// Fired at the start of every phase — drives haptics.
    var onPhaseStart: ((BreathPhase) -> Void)?
    var onFinish: (() -> Void)?

    private let plan: SessionPlan
    private let totalRounds: Int
    private var phaseTimer: Timer?
    private var endTimer: Timer?
    private var sequenceIndex: Int = 0

    init(plan: SessionPlan, totalRounds: Int = 1) {
        self.plan = plan
        self.totalRounds = totalRounds
    }

    var elapsed: TimeInterval {
        guard let start = sessionStart else { return 0 }
        return (sessionEnd ?? Date()).timeIntervalSince(start)
    }

    /// Scheduled end for timed plans; nil for round-based plans.
    var scheduledEndDate: Date? {
        guard case .timed(_, let total) = plan, let start = sessionStart else { return nil }
        return start.addingTimeInterval(total)
    }

    func start() {
        guard state == .idle else { return }
        sessionStart = Date()
        state = .running
        switch plan {
        case .timed(let cycle, let total):
            endTimer = Timer.scheduledTimer(withTimeInterval: total, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.finish() }
            }
            // Empty cycle = unguided (silent) session: just run the clock.
            if !cycle.isEmpty { beginPhase(nextTimedPhase()) }
        case .sequence(let phases):
            sequenceIndex = 0
            beginPhase(phases.first)
        }
    }

    /// User tap during an open-ended retention phase.
    func tapAdvance() {
        guard state == .awaitingTap else { return }
        retentionDurations.append(Date().timeIntervalSince(phaseStartDate))
        state = .running
        advanceSequence()
    }

    /// User-initiated or scheduled end.
    func finish() {
        guard state != .finished else { return }
        phaseTimer?.invalidate()
        endTimer?.invalidate()
        sessionEnd = Date()
        state = .finished
        currentPhase = nil
        onFinish?()
    }

    // MARK: - Phase advancement

    private func beginPhase(_ phase: BreathPhase?) {
        guard state == .running || state == .awaitingTap else { return }
        guard let phase else {
            finish()
            return
        }
        currentPhase = phase
        phaseStartDate = Date()
        onPhaseStart?(phase)

        if let duration = phase.duration {
            phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.phaseElapsed() }
            }
        } else {
            state = .awaitingTap
        }
    }

    private func phaseElapsed() {
        guard state == .running else { return }
        switch plan {
        case .timed:
            beginPhase(nextTimedPhase())
        case .sequence:
            advanceSequence()
        }
    }

    private var timedCycleIndex = 0

    private func nextTimedPhase() -> BreathPhase? {
        guard case .timed(let cycle, _) = plan, !cycle.isEmpty else { return nil }
        let phase = cycle[timedCycleIndex % cycle.count]
        timedCycleIndex += 1
        return phase
    }

    private func advanceSequence() {
        guard case .sequence(let phases) = plan else { return }
        // A recovery hold ending means a round just completed.
        if sequenceIndex < phases.count, phases[sequenceIndex].kind == .recovery {
            currentRound = min(currentRound + 1, totalRounds)
        }
        sequenceIndex += 1
        beginPhase(sequenceIndex < phases.count ? phases[sequenceIndex] : nil)
    }
}
