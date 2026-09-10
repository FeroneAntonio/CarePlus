import SwiftUI
import Observation
import Supabase

struct PatientSetupView: View {
    @Environment(AppState.self) private var app

    @State private var birthYear: String = ""
    @State private var notes: String = ""
    @State private var caregiverEmail: String = ""

    @State private var isSubmitting = false
    @State private var error: String? = nil

    var body: some View {
        Form {
            Section("Patient details") {
                TextField("Birth year", text: $birthYear)
                    .keyboardType(.numberPad)

                TextField("Notes (optional)", text: $notes)
            }

            Section("Caregiver") {
                TextField("Caregiver email", text: $caregiverEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("For privacy, the connection activates only after the caregiver enters your email from their account.")
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
        .navigationTitle("Patient setup")
    }

    @MainActor
    private func submitAsync() async {
        guard !isSubmitting else { return }
        error = nil
        guard let session = await AuthService.shared.currentSession() else {
            error = "Not authenticated"
            return
        }

        let patientId = session.user.id.uuidString

        let currentYear = Calendar.current.component(.year, from: .now)
        guard let by = Int(birthYear), by >= 1900, by <= currentYear else {
            error = "Enter a valid birth year"
            return
        }

        let email = caregiverEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Validators.isValidEmail(email) else {
            error = "Enter a valid caregiver email"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // 1) Save patient details
            try await DetailsService.shared.upsertPatientDetails(
                birthYear: by,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )

            // 2) Resolve caregiver id by email via RPC (bypasses RLS safely)
            let caregiver = try await ProfilesService.shared.findProfile(byEmail: email)
            guard let caregiver else {
                error = "Caregiver not found"
                return
            }
            guard caregiver.role?.lowercased() == "caregiver" else {
                error = "That account is not registered as a caregiver"
                return
            }

            // 3) Request care link (the caregiver confirms from their account)
            try await CareLinksService.shared.requestLink(
                patientId: patientId,
                caregiverId: caregiver.id
            )

            // 4) Activate profile (CHECK wants active + role not null; role already set in RoleChoice)
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
