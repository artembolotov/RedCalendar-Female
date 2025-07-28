import SwiftUI

struct PrimaryButton<Content: View>: View {
    let isEnabled: Bool
    let action: () -> Void
    let content: Content
    
    init(isEnabled: Bool = true, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isEnabled = isEnabled
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
                        Color.accentColor.opacity(0.9),
                        Color.accentColor
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

// Convenience init для простого текста
extension PrimaryButton where Content == Text {
    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.action = action
        self.content = Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}
