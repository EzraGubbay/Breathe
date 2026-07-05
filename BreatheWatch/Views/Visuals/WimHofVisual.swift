import SwiftUI

struct WimHofVisual: View {
    @ObservedObject var engine: BreathingEngine
    let totalRounds: Int
    @State private var scale: CGFloat = 0.5
    @State private var pulseOpacity: Double = 0.8

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
                    pulseOpacity = phase.kind == .inhale ? 1.0 : 0.6
                }
            }
        }
    }

    private var pacingPulse: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .scaleEffect(scale * 1.1)
                    .blur(radius: 10)
                
                Circle()
                    .stroke(.orange.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(.orange.gradient.opacity(pulseOpacity))
                    .frame(width: 100, height: 100)
                    .scaleEffect(scale)
                    .shadow(color: .orange.opacity(0.5), radius: 8)
            }
            .frame(width: 120, height: 120)
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
                    .shadow(color: .orange.opacity(0.3), radius: 2)
            }
            Text("Hold — tap when you\nneed to breathe")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
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
                    .shadow(color: .green.opacity(0.3), radius: 2)
            }
            Text("Deep inhale — hold")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 120)
    }
}
