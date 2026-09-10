import SwiftUI

struct SignUpFlowView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var requiresEmailConfirmation = false

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                switch step {
                case 1:
                    SignUpStep1AboutYouView(
                        firstName: $firstName,
                        lastName: $lastName,
                        email: $email,
                        password: $password,
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        onContinue: {
                            isLoading = true
                            errorMessage = nil
                            Task {
                                do {
                                    try await createAccount()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isLoading = false
                            }
                        }
                    )
                case 2:
                    SignUpStep3WelcomeView(
                        title: requiresEmailConfirmation ? "Check your email" : "Welcome!",
                        message: requiresEmailConfirmation
                            ? "Confirm your email, then return here and sign in."
                            : "Your account is ready. Next, choose whether you are a patient or caregiver.",
                        buttonTitle: requiresEmailConfirmation ? "Back to login" : "Choose my role",
                        onStart: {
                            dismiss()
                        }
                    )
                default:
                    EmptyView()
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Helpers

    private func createAccount() async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let session = try await AuthService.shared.signUp(email: normalizedEmail, password: password)

        guard session != nil else {
            requiresEmailConfirmation = true
            step = 2
            return
        }

        let displayName = "\(firstName) \(lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try await ProfilesService.shared.ensureProfile(
            displayName: displayName,
            email: normalizedEmail
        )
        await state.loadSupabaseSession()
        requiresEmailConfirmation = false
        step = 2
    }
}

