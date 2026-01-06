import ComposableArchitecture
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.currentPage.sending(\.pageChanged)) {
                WelcomePage()
                    .tag(OnboardingFeature.State.Page.welcome)

                HowItWorksPage()
                    .tag(OnboardingFeature.State.Page.howItWorks)

                DisplayNamePage(
                    displayName: $store.displayName.sending(\.displayNameChanged),
                    isValid: store.isNameValid
                )
                .tag(OnboardingFeature.State.Page.displayName)

                GetStartedPage()
                    .tag(OnboardingFeature.State.Page.getStarted)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            OnboardingNavigation(store: store)
        }
    }
}

// MARK: - Navigation

private struct OnboardingNavigation: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        HStack {
            if store.currentPage != .welcome {
                Button("Back") {
                    store.send(.backTapped)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if store.currentPage == .getStarted {
                Button("Get Started") {
                    store.send(.getStartedTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.isNameValid)
            } else if store.currentPage != .displayName {
                Button("Next") {
                    store.send(.nextTapped)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // On displayName page, show Next but disable until valid
                Button("Next") {
                    store.send(.nextTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.isNameValid)
            }
        }
        .padding()
        .padding(.bottom, 16)
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // TODO: Swap to final onboarding artwork during UI refresh.
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 90))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Welcome to Democracy DJ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("The road trip jukebox where everyone gets a vote")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - How It Works Page

private struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How It Works")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "steeringwheel",
                    title: "Driver Hosts",
                    description: "The driver controls the music queue"
                )

                FeatureRow(
                    icon: "person.3.fill",
                    title: "Passengers Join",
                    description: "Connect via Bluetooth - no internet needed"
                )

                FeatureRow(
                    icon: "hand.thumbsup.fill",
                    title: "Vote for Songs",
                    description: "Songs with the most votes play first"
                )
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 40)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Display Name Page

private struct DisplayNamePage: View {
    @Binding var displayName: String
    let isValid: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("What's your name?")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This is how you'll appear to other riders")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Enter your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 40)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    isFocused = false
                }

            if !displayName.isEmpty && !isValid {
                Text("Name must be 1-20 characters")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
            Spacer()
        }
        .padding()
        .onTapGesture {
            isFocused = false
        }
    }
}

// MARK: - Get Started Page

private struct GetStartedPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // TODO: Add permissions prompt (MusicKit) in Part 2 onboarding.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tap \"Get Started\" to begin your road trip")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Welcome") {
    OnboardingView(
        store: Store(
            initialState: OnboardingFeature.State(currentPage: .welcome)
        ) {
            OnboardingFeature()
        }
    )
}

#Preview("How It Works") {
    OnboardingView(
        store: Store(
            initialState: OnboardingFeature.State(currentPage: .howItWorks)
        ) {
            OnboardingFeature()
        }
    )
}

#Preview("Display Name") {
    OnboardingView(
        store: Store(
            initialState: OnboardingFeature.State(currentPage: .displayName)
        ) {
            OnboardingFeature()
        }
    )
}

#Preview("Get Started") {
    OnboardingView(
        store: Store(
            initialState: OnboardingFeature.State(
                currentPage: .getStarted,
                displayName: "Jeff"
            )
        ) {
            OnboardingFeature()
        }
    )
}
