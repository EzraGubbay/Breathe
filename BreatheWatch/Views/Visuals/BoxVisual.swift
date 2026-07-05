import SwiftUI

struct BoxVisual: View {
    @ObservedObject var engine: BreathingEngine
    @State private var sideIndex = 0
    @State private var progress: CGFloat = 0
    @State private var innerScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background blurred glow
                RoundedRectangle(cornerRadius: 16)
                    .fill(.teal.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                
                // Pulsating inner core
                RoundedRectangle(cornerRadius: 12)
                    .fill(.teal.gradient.opacity(0.4))
                    .frame(width: 80, height: 80)
                    .scaleEffect(innerScale)
                    .blendMode(.screen)
                
                // Track
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.teal.opacity(0.2), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                // Animated segment
                RoundedRectangle(cornerRadius: 16)
                    .trim(from: CGFloat(sideIndex) * 0.25, to: progress)
                    .stroke(.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 100, height: 100)
                    .shadow(color: .teal, radius: 5)
            }
            .frame(width: 120, height: 120)
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
            withAnimation(.easeInOut(duration: duration)) {
                innerScale = (phase.kind == .inhale || phase.kind == .holdAfterInhale) ? 1.0 : 0.8
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
