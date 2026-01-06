import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var showSplash = true

    var body: some View {
        ZStack {
            SwitchStore(store.scope(state: \.mode, action: { $0 })) { state in
                switch state {
                case .onboarding:
                    IfLetStore(store.scope(state: \.onboardingState, action: AppFeature.Action.onboarding)) { onboardingStore in
                        OnboardingView(store: onboardingStore)
                    }
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

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            store.send(.onAppear)
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}

#Preview("Splash") {
    SplashView()
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}

private struct SplashView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.20),
                    Color(red: 0.18, green: 0.33, blue: 0.56),
                    Color(red: 0.95, green: 0.60, blue: 0.25)
                ],
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .shadow(radius: 12)

                Text("DemocracyDJ")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(radius: 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
