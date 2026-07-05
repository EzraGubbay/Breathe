import SwiftUI

struct ResonanceVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var scale: CGFloat = 0.45
    @State private var rotation: Angle = .zero

    var body: some View {
        VStack(spacing: 8) {
            PetalView(color: .teal, scale: scale, rotationOffset: rotation)
                .frame(height: 120)
            Text(engine.currentPhase?.kind.label ?? "")
                .font(.headline)
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            withAnimation(.easeInOut(duration: duration)) {
                scale = phase.kind == .inhale ? 1.0 : 0.45
                rotation += .degrees(phase.kind == .inhale ? 45 : -45)
            }
        }
    }
}
