import SwiftUI

@main
struct DemocracyDJApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Hello Democracy")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your road trip, your votes")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
