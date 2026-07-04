import SwiftUI

@main
struct BreatheApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .task {
                await HealthKitService.shared.requestAuthorization()
            }
        }
    }
}
