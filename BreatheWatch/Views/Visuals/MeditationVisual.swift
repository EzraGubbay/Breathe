import SwiftUI

struct MeditationVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Angle = .zero

    private var isPaced: Bool { engine.currentPhase != nil }

    var body: some View {
        VStack(spacing: 8) {
            if isPaced {
                PetalView(color: .green, scale: scale, rotationOffset: rotation)
                    .frame(height: 120)
                Text(engine.currentPhase?.kind.label ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Unguided - gentle ambient drift
                PetalView(color: .green, scale: 0.6, rotationOffset: rotation)
                    .frame(height: 120)
                    .onAppear {
                        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                            rotation = .degrees(360)
                        }
                    }
                Text("Be still")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            withAnimation(.easeInOut(duration: duration)) {
                scale = phase.kind == .inhale ? 0.95 : 0.5
                rotation += .degrees(phase.kind == .inhale ? 30 : -30)
            }
        }
    }
}
