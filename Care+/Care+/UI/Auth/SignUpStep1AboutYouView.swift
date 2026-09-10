import SwiftUI

struct SignUpStep1AboutYouView: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var password: String
    var isLoading: Bool
    var errorMessage: String?
    var onContinue: () -> Void

    private var isFirstNameValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isLastNameValid: Bool {
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEmailValid: Bool {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Basic email validation
        return emailTrimmed.contains("@") && emailTrimmed.contains(".") && emailTrimmed.count >= 5
    }

    private var isPasswordValid: Bool {
        password.count >= 6
    }

    private var isContinueEnabled: Bool {
        isFirstNameValid && isLastNameValid && isEmailValid && isPasswordValid && !isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tell us about yourself")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                SignUpRoundedTextField(
                    title: "First name",
                    text: $firstName,
                    keyboardType: .default,
                    textContentType: .givenName,
                    autocapitalization: .words
                )
                SignUpRoundedTextField(
                    title: "Last name",
                    text: $lastName,
                    keyboardType: .default,
                    textContentType: .familyName,
                    autocapitalization: .words
                )
                SignUpRoundedTextField(
                    title: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalization: .never
                )
                SignUpRoundedTextField(
                    title: "Password",
                    text: $password,
                    isSecure: true,
                    keyboardType: .default,
                    textContentType: .newPassword,
                    autocapitalization: .never
                )
            }

            Button(action: {
                onContinue()
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isContinueEnabled ? AppTheme.primary : AppTheme.primary.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!isContinueEnabled)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
    }
}

private struct SignUpRoundedTextField: View {
    var title: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
                    .padding(12)
                    .background(AppTheme.background)
                    .foregroundColor(AppTheme.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
            } else {
                TextField(title, text: $text)
                    .padding(12)
                    .background(AppTheme.background)
                    .foregroundColor(AppTheme.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
    }
}
