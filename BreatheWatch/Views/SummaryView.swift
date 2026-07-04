import SwiftUI

struct SummaryView: View {
    let summary: SessionSummary
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label(summary.configuration.type.displayName,
                      systemImage: summary.configuration.type.systemImage)
                    .font(.headline)

                row("Duration", formatDuration(summary.duration))

                if let avg = summary.averageHeartRate {
                    row("Avg HR", "\(Int(avg)) bpm")
                }
                if let min = summary.minHeartRate, let max = summary.maxHeartRate {
                    row("Range", "\(Int(min))–\(Int(max)) bpm")
                }
                if let hrv = summary.hrvSDNN {
                    row("HRV (SDNN)", String(format: "%.0f ms", hrv))
                } else if summary.configuration.type.tracksHRV {
                    row("HRV (SDNN)", "pending")
                }
                if let delta = summary.heartRateDelta {
                    row("HR change", String(format: "%+.0f bpm", delta))
                }
                if !summary.retentionDurations.isEmpty {
                    ForEach(Array(summary.retentionDurations.enumerated()), id: \.offset) { index, hold in
                        row("Hold \(index + 1)", formatDuration(hold))
                    }
                }

                Label(summary.savedToHealth ? "Saved to Health" : "Not saved to Health",
                      systemImage: summary.savedToHealth ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(summary.savedToHealth ? .green : .orange)
                    .padding(.top, 4)

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Summary")
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.footnote)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
