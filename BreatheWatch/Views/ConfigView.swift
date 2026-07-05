import SwiftUI

/// Pre-session configuration: time / BPM / rounds pickers depending on protocol.
struct ConfigView: View {
    let type: SessionType
    @State private var config: SessionConfiguration
    @State private var sessionActive = false

    init(type: SessionType) {
        self.type = type
        _config = State(initialValue: .default(for: type))
    }

    var body: some View {
        Form {
            if type.usesRounds {
                Picker("Rounds", selection: $config.rounds) {
                    ForEach(SessionConfiguration.roundChoices, id: \.self) { rounds in
                        Text("\(rounds) rounds").tag(rounds)
                    }
                }
            } else {
                Picker("Time", selection: $config.duration) {
                    ForEach(SessionConfiguration.durationChoices, id: \.self) { seconds in
                        Text("\(Int(seconds / 60)) min").tag(seconds)
                    }
                }
            }

            if type.usesBPM {
                Picker("Pace", selection: $config.breathsPerMinute) {
                    let choices = type == .meditation
                        ? SessionConfiguration.meditationBPMChoices
                        : SessionConfiguration.resonanceBPMChoices
                    ForEach(choices, id: \.self) { bpm in
                        Text(bpm == 0 ? "Unguided" : String(format: "%.1f BPM", bpm)).tag(bpm)
                    }
                }
            }

            Section {
                Button {
                    sessionActive = true
                } label: {
                    Text("Start")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(type.displayName)
        .fullScreenCover(isPresented: $sessionActive) {
            SessionView(configuration: config)
        }
    }
}

#Preview {
    NavigationStack { ConfigView(type: .resonance) }
}
