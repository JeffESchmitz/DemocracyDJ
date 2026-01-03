import ComposableArchitecture
import SwiftUI

struct ModeSelectionView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Democracy DJ")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your road trip, your votes")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField(
                        "Enter your name",
                        text: viewStore.binding(
                            get: \.displayName,
                            send: AppFeature.Action.displayNameChanged
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                }

                VStack(spacing: 16) {
                    modeButton(
                        title: "I'm Driving",
                        subtitle: "Control the music",
                        systemImage: "steeringwheel",
                        isPrimary: true,
                        action: { viewStore.send(.hostSelected) }
                    )
                    .accessibilityIdentifier("host_start_session_button")

                    modeButton(
                        title: "I'm a Passenger",
                        subtitle: "Vote on songs",
                        systemImage: "hand.raised",
                        isPrimary: false,
                        action: { viewStore.send(.guestSelected) }
                    )
                    .accessibilityIdentifier("peer_join_session_button")
                }
                .disabled(isNameEmpty(viewStore.displayName))

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private func isNameEmpty(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func modeButton(
        title: String,
        subtitle: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isPrimary ? .accentColor : .secondary)
        .controlSize(.large)
        .accessibilityLabel(isPrimary ? "Start hosting as driver" : "Join as passenger")
    }
}

#Preview {
    ModeSelectionView(
        store: Store(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        }
    )
}
