import SwiftUI
import Observation
import Supabase

struct CaregiverSetupView: View {
    @Environment(AppState.self) private var app

    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var relationship: String = ""
    @State private var patientEmail: String = ""

    @State private var isSubmitting = false
    @State private var error: String? = nil

    var body: some View {
        Form {
            Section("Caregiver details") {
                TextField("Full name", text: $fullName)

                TextField("Phone (optional)", text: $phone)
                    .keyboardType(.phonePad)

                TextField("Relationship (optional)", text: $relationship)
            }

            Section("Patient") {
                TextField("Patient email", text: $patientEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("For privacy, the connection activates only after the patient enters your email from their account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await submitAsync() }
            } label: {
                if isSubmitting { ProgressView() } else { Text("Save & Continue") }
            }
            .disabled(isSubmitting)

            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .navigationTitle("Caregiver setup")
    }

    @MainActor
    private func submitAsync() async {
        guard !isSubmitting else { return }
        error = nil
        guard let session = await AuthService.shared.currentSession() else {
            error = "Not authenticated"
            return
        }

        let caregiverId = session.user.id.uuidString

        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Enter your full name"
            return
        }

        let email = patientEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Validators.isValidEmail(email) else {
            error = "Enter a valid patient email"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // 1) Save caregiver details
            try await DetailsService.shared.upsertCaregiverDetails(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )

            // 2) Resolve patient id by email via RPC
            let patient = try await ProfilesService.shared.findProfile(byEmail: email)
            guard let patient else {
                error = "Patient not found"
                return
            }
            guard patient.role?.lowercased() == "patient" else {
                error = "That account is not registered as a patient"
                return
            }

            // 3) Request care link (the patient confirms from their account)
            try await CareLinksService.shared.requestLink(
                patientId: patient.id,
                caregiverId: caregiverId
            )

            // 4) Activate profile
            try await setProfileStatusActive()
            await app.refreshProfileFromSupabase()

        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func setProfileStatusActive() async throws {
        guard let session = await AuthService.shared.currentSession() else { return }
        let userId = session.user.id.uuidString

        struct StatusUpdate: Encodable {
            let status: String
        }

        let payload = StatusUpdate(status: "active")

        _ = try await SupabaseClientProvider.shared.client.database
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
