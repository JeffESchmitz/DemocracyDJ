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
    private let guestStore = Store(initialState: GuestFeature.State()) {
        GuestFeature()
    }
    @State private var showingGuest = false

    var body: some View {
        Group {
            if showingGuest {
                GuestView(store: guestStore)
            } else {
                HostView(store: store)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(showingGuest ? "Host" : "Guest") {
                showingGuest.toggle()
            }
            .font(.caption)
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding()
            .accessibilityLabel(showingGuest ? "Show host view" : "Show guest view")
        }
    }
}

#Preview {
    ContentView()
}
