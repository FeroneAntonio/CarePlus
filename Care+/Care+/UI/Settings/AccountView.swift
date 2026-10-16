import SwiftUI

struct AccountView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.currentUser?.name ?? "Guest")
                                .font(.headline)
                            Text(state.currentUser?.email ?? "Data is stored only on this iPhone.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let role = state.userRole {
                    Section("Care connection") {
                        LabeledContent("Role", value: role.capitalized)
                        if role == "caregiver", let patient = state.careDataOwnerName {
                            LabeledContent("Caring for", value: patient)
                        }
                        if state.careLinkStatus == "pending" {
                            Label("Waiting for the other person to confirm", systemImage: "clock.fill")
                                .foregroundStyle(AppTheme.warning)
                        }
                    }
                }

                Section {
                    Button(state.isGuest ? "Exit guest mode" : "Log out", role: .destructive) {
                        if state.isGuest {
                            state.setGuest(false)
                        } else {
                            Task { await state.logout() }
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(AppTheme.primary)
        .task {
            guard !state.isGuest else { return }
            await state.refreshProfileFromSupabase()
            await SyncEngine.fullSync(state: state)
        }
    }
}
