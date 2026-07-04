import SwiftUI

/// Minimalist meditation view (specs.md §2E). Paced mode shows a gentle
/// breathing circle; unguided (BPM = 0) shows only a still leaf.
struct MeditationVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var scale: CGFloat = 0.5

    private var isPaced: Bool { engine.currentPhase != nil }

    var body: some View {
        VStack(spacing: 8) {
            if isPaced {
                ZStack {
                    Circle().stroke(.green.opacity(0.2), lineWidth: 1)
                    Circle().fill(.green.gradient.opacity(0.5)).scaleEffect(scale)
                }
                .frame(width: 100, height: 100)
                Text(engine.currentPhase?.kind.label ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green.opacity(0.7))
                Text("Be still")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            withAnimation(.easeInOut(duration: duration)) {
                scale = phase.kind == .inhale ? 0.95 : 0.5
            }
        }
    }
}
