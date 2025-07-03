//
//  FlashCallCodeEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 03.07.2025.
//

import SwiftUI

struct FlashCallCodeEntryView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var codeInput: String = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        switch store.state.authState {
        case .authenticating(.phone(.verification(let prettyPhoneNumber, let e164PhoneNumber, let maskedCallerNumber, let requestId, let error))):
            buildView(
                prettyPhoneNumber: prettyPhoneNumber,
                e164PhoneNumber: e164PhoneNumber,
                maskedCallerNumber: maskedCallerNumber,
                requestId: requestId,
                error: error
            )
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func buildView(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
        maskedCallerNumber: String,
        requestId: String,
        error: AuthenticationError?
    ) -> some View {
        let isCodeValid = codeInput.count == 4 && codeInput.allSatisfy { $0.isNumber }
        
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Back button in top-left corner of content
                    HStack {
                        Button(action: { goBackToPhoneEntry(prettyPhoneNumber: prettyPhoneNumber) }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .offset(x: -10)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    Text("Дождитесь звонка")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        Text("Мы звоним на номер:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text(prettyPhoneNumber)
                            .font(.headline)
                        
                        Text("Номер звонящего:")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        Text(maskedCallerNumber)
                            .font(.headline)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Text("Введите последние 4 цифры номера звонящего:")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        TextField("Последние 4 цифры", text: $codeInput)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .submitLabel(.continue)
                            .focused($isCodeFieldFocused)
                            .onChange(of: codeInput) { newValue in
                                // Limit to 4 digits only
                                let filtered = String(newValue.prefix(4).filter { $0.isNumber })
                                if filtered != newValue {
                                    codeInput = filtered
                                }
                            }
                            .onSubmit {
                                if isCodeValid {
                                    submitCode(prettyPhoneNumber: prettyPhoneNumber, e164PhoneNumber: e164PhoneNumber, requestId: requestId)
                                }
                            }
                            .formFieldStyle()
                    }
                    .padding(.horizontal)
                    
                    if let error = error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Group {
                        Text("Не получили звонок?\n[Запросить новый звонок](retry)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.absoluteString == "retry" {
                            requestNewFlashCall(prettyPhoneNumber: prettyPhoneNumber)
                        }
                        return .handled
                    })
                    
                    PrimaryButton(
                        "Подтвердить",
                        isEnabled: isCodeValid,
                        action: { submitCode(prettyPhoneNumber: prettyPhoneNumber, e164PhoneNumber: e164PhoneNumber, requestId: requestId) }
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
        .navigationTitle("Подтверждение Flash Call")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
    }
    
    private func goBackToPhoneEntry(prettyPhoneNumber: String) {
        store.send(.setAuthState(.authenticating(.phone(.entry(
            prettyPhoneNumber: prettyPhoneNumber,
            error: nil
        )))))
    }
    
    private func submitCode(prettyPhoneNumber: String, e164PhoneNumber: String, requestId: String) {
        guard codeInput.count == 4 && codeInput.allSatisfy({ $0.isNumber }) else { return }
        
        // Send Redux action to verify flash call code
        store.send(.setAuthState(.authenticating(.phone(.verifying(
            prettyPhoneNumber: prettyPhoneNumber,
            e164PhoneNumber: e164PhoneNumber,
            requestId: requestId,
            verificationCode: codeInput
        )))))
    }
    
    private func requestNewFlashCall(prettyPhoneNumber: String) {
        // Go back to phone entry to request new flash call
        store.send(.setAuthState(.authenticating(.phone(.entry(
            prettyPhoneNumber: prettyPhoneNumber,
            error: nil
        )))))
    }
}

#Preview("Flash Call Code Entry - Normal") {
    FlashCallCodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.phone(.verification(
                        prettyPhoneNumber: "+7 (999) 123-45-67",
                        e164PhoneNumber: "+79991234567",
                        maskedCallerNumber: "+33700001234",
                        requestId: "fp9RPWDGZkskBrVeTc4lgNCc4e79fc65",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Flash Call Code Entry - With Error") {
    FlashCallCodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.phone(.verification(
                        prettyPhoneNumber: "+7 (999) 123-45-67",
                        e164PhoneNumber: "+79991234567",
                        maskedCallerNumber: "+33700001234",
                        requestId: "fp9RPWDGZkskBrVeTc4lgNCc4e79fc65",
                        error: AuthenticationError.phoneVerificationFailed
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
