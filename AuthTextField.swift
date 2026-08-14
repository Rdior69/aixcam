import SwiftUI

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
                    .focused($isFocused)
            }
        }
        .font(.body)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

#Preview("Email Field") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            AuthTextField(
                placeholder: "Email",
                text: .constant(""),
                keyboardType: .emailAddress
            )
            
            AuthTextField(
                placeholder: "email@example.com",
                text: .constant("test@example.com"),
                keyboardType: .emailAddress
            )
        }
        .padding(.horizontal, 32)
    }
}

#Preview("Password Field") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            AuthTextField(
                placeholder: "Password",
                text: .constant(""),
                isSecure: true
            )
            
            AuthTextField(
                placeholder: "Password",
                text: .constant("mypassword123"),
                isSecure: true
            )
        }
        .padding(.horizontal, 32)
    }
}

#Preview("All Fields") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 14) {
            AuthTextField(
                placeholder: "Email",
                text: .constant("user@example.com"),
                keyboardType: .emailAddress,
                isSecure: false
            )
            
            AuthTextField(
                placeholder: "Password",
                text: .constant("password"),
                keyboardType: .default,
                isSecure: true
            )
            
            AuthTextField(
                placeholder: "Confirm Password",
                text: .constant("password"),
                keyboardType: .default,
                isSecure: true
            )
        }
        .padding(.horizontal, 32)
    }
}
