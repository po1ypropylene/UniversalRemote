import SwiftUI

/// Keeps custom controls usable with a pointer or a future touch interface.
struct ComfortableButtonStyle: ButtonStyle {
    var iconOnly = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .lineLimit(1)
            .padding(.horizontal, iconOnly ? 0 : 10)
            .frame(minWidth: 36, minHeight: iconOnly ? 36 : 34)
            .background(
                .quaternary.opacity(configuration.isPressed ? 1 : 0.5),
                in: RoundedRectangle(cornerRadius: 9)
            )
            // The transparent margin is clickable without enlarging the visible chrome.
            .padding(.vertical, iconOnly ? 4 : 5)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.5)
    }
}

struct IconActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 36)
        }
        .buttonStyle(ComfortableButtonStyle(iconOnly: true))
        .accessibilityLabel(title)
        .help(title)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                // Native glass padding completes the primary action's 44-point target.
                .frame(minWidth: 44, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .accessibilityLabel(title)
    }
}
