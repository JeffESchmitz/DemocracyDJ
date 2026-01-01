import ComposableArchitecture
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
    private let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some View {
        SwitchStore(store.scope(state: \.mode, action: { $0 })) { state in
            switch state {
            case .modeSelection:
                ModeSelectionView(store: store)
            case .host:
                IfLetStore(store.scope(state: \.hostState, action: AppFeature.Action.host)) { hostStore in
                    HostView(store: hostStore)
                }
            case .guest:
                IfLetStore(store.scope(state: \.guestState, action: AppFeature.Action.guest)) { guestStore in
                    GuestView(store: guestStore)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
