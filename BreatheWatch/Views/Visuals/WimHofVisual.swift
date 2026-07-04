import SwiftUI

/// High-energy pacing pulse for hyperventilation, an open-ended retention
/// timer advanced by tap, and a recovery-hold countdown (specs.md §2D).
struct WimHofVisual: View {
    @ObservedObject var engine: BreathingEngine
    let totalRounds: Int
    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 6) {
            Text("Round \(engine.currentRound)/\(totalRounds)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            switch engine.currentPhase?.kind {
            case .retention:
                retention
            case .recovery:
                recovery
            default:
                pacingPulse
            }
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            if phase.kind == .inhale || phase.kind == .exhale {
                withAnimation(.easeInOut(duration: duration)) {
                    scale = phase.kind == .inhale ? 1.0 : 0.5
                }
            }
        }
    }

    private var pacingPulse: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.orange.opacity(0.25), lineWidth: 2)
                Circle().fill(.orange.gradient.opacity(0.8)).scaleEffect(scale)
            }
            .frame(width: 96, height: 96)
            Text(engine.currentPhase?.kind.label ?? "Breathe")
                .font(.headline)
        }
    }

    private var retention: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: engine.phaseStartDate, by: 1)) { context in
                let held = max(0, Int(context.date.timeIntervalSince(engine.phaseStartDate)))
                Text(String(format: "%d:%02d", held / 60, held % 60))
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Text("Hold — tap when you\nneed to breathe")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .contentShape(Rectangle())
        .onTapGesture { engine.tapAdvance() }
    }

    private var recovery: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: engine.phaseStartDate, by: 1)) { context in
                let total = ProtocolTimeline.wimHofRecoveryHold
                let left = max(0, Int((total - context.date.timeIntervalSince(engine.phaseStartDate)).rounded()))
                Text("\(left)")
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .foregroundStyle(.green)
            }
            Text("Deep inhale — hold")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 100)
    }
}
