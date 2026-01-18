import SwiftUI
import UIKit

struct ToastView: View {
    let message: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    var transition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .move(edge: .top).combined(with: .opacity)
        }
    }
}

#Preview {
    VStack {
        ToastView(message: "\"Hotel California\" was removed") {}
        Spacer()
    }
    .padding(.top, 50)
}
