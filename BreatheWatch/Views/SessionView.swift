import SwiftUI

/// Hosts a running session: routes to the protocol's visual, shows the clock
/// and live heart rate, and handles early termination + the summary handoff.
struct SessionView: View {
    @StateObject private var controller: SessionController
    @Environment(\.dismiss) private var dismiss
    @State private var started = false

    init(configuration: SessionConfiguration) {
        _controller = StateObject(wrappedValue: SessionController(configuration: configuration))
    }

    var body: some View {
        Group {
            if let summary = controller.summary {
                SummaryView(summary: summary) { dismiss() }
            } else {
                activeSession
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            controller.start()
        }
    }

    private var activeSession: some View {
        VStack(spacing: 6) {
            header
            Spacer(minLength: 0)
            visual
            Spacer(minLength: 0)
            Button(role: .destructive) {
                controller.endEarly()
            } label: {
                Text("End")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 4)
    }

    private var header: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(clockText)
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let bpm = controller.workout.latestHeartRate {
                Label("\(Int(bpm))", systemImage: "heart.fill")
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
                    .foregroundStyle(.red)
            }
        }
    }

    private var clockText: String {
        // Timed sessions count down; Wim Hof counts up.
        let seconds: Int
        if let end = controller.engine.scheduledEndDate {
            seconds = max(0, Int(end.timeIntervalSinceNow.rounded()))
        } else {
            seconds = Int(controller.engine.elapsed)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @ViewBuilder
    private var visual: some View {
        switch controller.configuration.type {
        case .resonance:
            ResonanceVisual(engine: controller.engine)
        case .box:
            BoxVisual(engine: controller.engine)
        case .sigh:
            SighVisual(engine: controller.engine)
        case .wimHof:
            WimHofVisual(engine: controller.engine,
                         totalRounds: controller.configuration.rounds)
        case .meditation:
            MeditationVisual(engine: controller.engine)
        }
    }
}
