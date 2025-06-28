//
//  PhoneNumberKitField.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 27.06.2025.
//

import SwiftUI
import PhoneNumberKit

struct PhoneNumberKitField: UIViewRepresentable {
    @Binding var phoneNumber: String
    @Binding var e164PhoneNumber: String?
    let onSubmit: () -> Void
    
    private let phoneUtil = PhoneNumberUtility()
    
    init(
        phoneNumber: Binding<String>,
        e164PhoneNumber: Binding<String?>,
        onSubmit: @escaping () -> Void = {}
    ) {
        self._phoneNumber = phoneNumber
        self._e164PhoneNumber = e164PhoneNumber
        self.onSubmit = onSubmit
    }
    
    func makeUIView(context: Context) -> PhoneNumberTextField {
        let textField = PhoneNumberTextField()
        
        // Configure PhoneNumberKit features
        textField.withFlag = false
        textField.withPrefix = true
        textField.withExamplePlaceholder = true
        textField.placeholder = "Номер телефона"
        
        // Basic styling
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.cornerRadius = 8
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        
        // Padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
        
        // Keyboard and autofill
        textField.keyboardType = .phonePad
        textField.returnKeyType = .continue
        textField.textContentType = .telephoneNumber // For QuickType suggestions
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        
        // Delegate and targets
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textFieldDidChange(_:)),
            for: .editingChanged
        )
        
        // Prevent text field from expanding beyond reasonable bounds
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Auto focus when created
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        
        return textField
    }
    
    func updateUIView(_ uiView: PhoneNumberTextField, context: Context) {
        // Update coordinator first
        context.coordinator.parent = self
        
        // Sync text and validate if needed
        if uiView.text != phoneNumber {
            uiView.text = phoneNumber
            
            context.coordinator.validatePhoneNumber(phoneNumber)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PhoneNumberKitField
        
        init(_ parent: PhoneNumberKitField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            let text = textField.text ?? ""
            parent.phoneNumber = text
            validatePhoneNumber(text)
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
        
        // Сделали метод внутренним для использования из updateUIView
        func validatePhoneNumber(_ text: String) {
            guard !text.isEmpty else {
                parent.e164PhoneNumber = nil
                return
            }
            
            do {
                let phoneNumber = try parent.phoneUtil.parse(text)
                parent.e164PhoneNumber = parent.phoneUtil.format(phoneNumber, toType: .e164)
                parent.phoneNumber = parent.phoneUtil.format(phoneNumber, toType: .international)
            } catch {
                parent.e164PhoneNumber = nil
            }
        }
    }
}
