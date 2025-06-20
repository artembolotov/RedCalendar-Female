import SwiftUI

struct WaitingView: View {
    let message: String
    
    init(_ message: String) {
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
    WaitingView("Проверка авторизации")
}
