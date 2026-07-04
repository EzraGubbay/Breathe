import SwiftUI

/// Double-pulse inflation then a long, slow deflation (specs.md §2C).
struct SighVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var scale: CGFloat = 0.35
    @State private var seenFirstInhale = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.cyan.opacity(0.25), lineWidth: 2)
                Circle()
                    .fill(.cyan.gradient.opacity(0.75))
                    .scaleEffect(scale)
            }
            .frame(width: 110, height: 110)
            Text(label)
                .font(.headline)
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            switch phase.kind {
            case .inhale:
                let target: CGFloat = seenFirstInhale ? 1.0 : 0.72
                seenFirstInhale = true
                withAnimation(.easeOut(duration: duration)) { scale = target }
            case .exhale:
                seenFirstInhale = false
                withAnimation(.easeInOut(duration: duration)) { scale = 0.35 }
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
