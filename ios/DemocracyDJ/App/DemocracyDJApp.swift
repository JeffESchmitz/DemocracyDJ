import ComposableArchitecture
import Shared
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
    private let store = Store(initialState: HostFeature.State(myPeer: Peer(name: "Host"))) {
        HostFeature()
    }

    var body: some View {
        HostView(store: store)
    }
}

#Preview {
    ContentView()
}
