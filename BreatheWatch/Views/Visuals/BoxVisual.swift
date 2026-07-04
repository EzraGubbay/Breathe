import SwiftUI

/// Segmented square loop: one side traced per phase (specs.md §2B).
struct BoxVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var sideIndex = 0      // 0 inhale, 1 hold, 2 exhale, 3 hold
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.teal.opacity(0.25), lineWidth: 4)
                RoundedRectangle(cornerRadius: 8)
                    .trim(from: CGFloat(sideIndex) * 0.25, to: progress)
                    .stroke(.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            .frame(width: 96, height: 96)
            Text(engine.currentPhase?.kind.label ?? "")
                .font(.headline)
        }
        .onChange(of: engine.phaseStartDate) {
            guard let phase = engine.currentPhase, let duration = phase.duration else { return }
            sideIndex = segment(for: phase.kind, previous: sideIndex)
            progress = CGFloat(sideIndex) * 0.25
            withAnimation(.linear(duration: duration)) {
                progress = CGFloat(sideIndex + 1) * 0.25
            }
        }
    }

    private func segment(for kind: BreathPhaseKind, previous: Int) -> Int {
        switch kind {
        case .inhale: return 0
        case .holdAfterInhale: return 1
        case .exhale: return 2
        case .holdAfterExhale: return 3
        default: return previous
        }
    }
}
