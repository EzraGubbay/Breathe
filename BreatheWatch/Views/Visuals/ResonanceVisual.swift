import SwiftUI

/// Smooth, continuous expanding/contracting circle (specs.md §2A).
struct ResonanceVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var scale: CGFloat = 0.45

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.teal.opacity(0.25), lineWidth: 2)
                Circle()
                    .fill(.teal.gradient.opacity(0.75))
                    .scaleEffect(scale)
            }
            .frame(width: 110, height: 110)
            Text(engine.currentPhase?.kind.label ?? "")
                .font(.headline)
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            withAnimation(.easeInOut(duration: duration)) {
                scale = phase.kind == .inhale ? 1.0 : 0.45
            }
        }
    }
}
