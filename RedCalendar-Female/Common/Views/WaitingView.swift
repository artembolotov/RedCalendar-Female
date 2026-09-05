import SwiftUI

struct WaitingView: View {
    let message: LocalizedStringKey

    init(_ message: LocalizedStringKey) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
        }
    }
}

#Preview {
    WaitingView("Migration.CheckingAuth")
}
