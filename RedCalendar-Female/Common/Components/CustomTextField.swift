import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var previousText: String = ""
    
    init(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .submitLabel(submitLabel)
            .focused($isFocused)
            .onSubmit {
                onSubmit()
            }
            .onChange(of: text) { newValue in
                // Only check for auto-replacement if field was not empty
                if previousText.isEmpty {
                    previousText = newValue
                    return
                }
                
                // Detect potential auto-replacement (significant length increase)
                if newValue.count > previousText.count + 5 {
                    // Likely auto-replacement happened, revert to previous text
                    text = previousText
                } else {
                    previousText = newValue
                }
            }
    }
    
    func focus() {
        isFocused = true
    }
}
