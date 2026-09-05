import SwiftUI

struct PrimaryButton<Content: View>: View {
    let isEnabled: Bool
    // A `Color` rather than an `AccentTheme`: this is a generic component in `Common`, and it
    // has no business knowing what the app's themes are — only what colour to fill with.
    let accent: Color
    let action: () -> Void
    let content: Content

    init(
        isEnabled: Bool = true,
        accent: Color,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isEnabled = isEnabled
        self.accent = accent
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                content
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RadialGradient(
                    gradient: Gradient(colors: [
                        accent.opacity(0.9),
                        accent
                    ]),
                    center: .center,
                    startRadius: 5,
                    endRadius: 100
                )
            )
            .cornerRadius(16)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// Convenience init для простого текста.
//
// `LocalizedStringKey` rather than `String`: a `String` parameter takes the literal at the call
// site out of Xcode's reach entirely — it is never extracted, so it never reaches the catalog and
// nothing marks it as untranslated. Every text-shaped parameter on a shared component takes the
// key type for that reason.
extension PrimaryButton where Content == Text {
    init(_ title: LocalizedStringKey, isEnabled: Bool = true, accent: Color, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.accent = accent
        self.action = action
        self.content = Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}
