import SwiftUI

struct SighVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var scale: CGFloat = 0.35
    @State private var rotation: Angle = .zero
    @State private var seenFirstInhale = false

    var body: some View {
        VStack(spacing: 8) {
            PetalView(color: .cyan, scale: scale, rotationOffset: rotation)
                .frame(height: 120)
            Text(label)
                .font(.headline)
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            switch phase.kind {
            case .inhale:
                let target: CGFloat = seenFirstInhale ? 1.0 : 0.72
                seenFirstInhale = true
                withAnimation(.easeOut(duration: duration)) { 
                    scale = target
                    rotation += .degrees(30)
                }
            case .exhale:
                seenFirstInhale = false
                withAnimation(.easeInOut(duration: duration)) { 
                    scale = 0.35
                    rotation -= .degrees(60)
                }
            default:
                seenFirstInhale = false
            }
        }
    }

    private var label: String {
        guard let kind = engine.currentPhase?.kind else { return "" }
        switch kind {
        case .inhale: return seenFirstInhale ? "Inhale — top up" : "Inhale"
        case .exhale: return "Long exhale"
        case .holdAfterExhale: return "Rest"
        default: return kind.label
        }
    }
}
