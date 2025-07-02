import SwiftUI

struct FlashCallCodeEntryView: View {
    let maskedPhoneNumber: String
    let requestId: String
    @State private var codeInput: String = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    // Mock state management - в реальном приложении это будет через Redux
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    private var isCodeValid: Bool {
        codeInput.count == 4 && codeInput.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Back button in top-left corner of content
                    HStack {
                        Button(action: {  }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .offset(x: -10)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    Text("С возвращением!")
                        .font(.title2)
                        .bold()
                    
                    Text("Код из звонка с номера \(maskedPhoneNumber)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    TextField("Последние 4 цифры номера", text: $codeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .submitLabel(.continue)
                        .focused($isCodeFieldFocused)
                        .onChange(of: codeInput) { newValue in
                            let filtered = String(newValue.prefix(4).filter { $0.isNumber })
                            if filtered != newValue {
                                codeInput = filtered
                            }
                        }
                        .onSubmit {
                            if isCodeValid {
                                submitCode()
                            }
                        }
                        .formFieldStyle()
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Group {
                        Text("Не получили звонок?\n[Запросить новый звонок](retry)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.absoluteString == "retry" && !isLoading {
                            requestNewFlashCall()
                        }
                        return .handled
                    })
                    
                    PrimaryButton(
                        "Подтвердить",
                        isEnabled: isCodeValid,
                        action: { submitCode() }
                    )
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal)
                .onAppear {
                    isCodeFieldFocused = true
                }
            }
        }
        .navigationTitle("Flash Call")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
    }
    
    private func submitCode() {
        guard isCodeValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        // В реальном приложении это будет Redux action
        // store.send(.setAuthState(.authenticating(.phone(.verifying(requestId: requestId, code: codeInput)))))
        
        // Mock API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            
            // Mock success/error
            if codeInput == "1234" {
                // Success - navigate to main app
                print("Flash Call verification successful")
            } else {
                // Error
                errorMessage = "Неверный код. Попробуйте еще раз"
                codeInput = ""
                isCodeFieldFocused = true
            }
        }
    }
    
    private func requestNewFlashCall() {
        // В реальном приложении это будет Redux action для повторного запроса
        // store.send(.setAuthState(.authenticating(.phone(.entry(phone: phoneNumber)))))
        print("Requesting new Flash Call")
    }
}

#Preview {
    FlashCallCodeEntryView(
        maskedPhoneNumber: "+33700001234",
        requestId: "mock_request_id"
    )
}
