import SwiftUI

struct HomeView: View {
    var body: some View {
        List(SessionType.allCases) { type in
            NavigationLink(value: type) {
                HStack(spacing: 10) {
                    Image(systemName: type.systemImage)
                        .font(.title3)
                        .foregroundStyle(.teal)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.displayName)
                            .font(.headline)
                        Text(type.tagline)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Breathe")
        .navigationDestination(for: SessionType.self) { type in
            ConfigView(type: type)
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
