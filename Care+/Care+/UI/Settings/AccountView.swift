import SwiftUI

struct AccountView: View {
    @Bindable var state: AppState
    @Environment(\.colorScheme) private var scheme

    private var textPrimary: Color { AppTheme.textPrimary }
    private var textSecondary: Color { AppTheme.textSecondary }
    private var iconColor: Color { AppTheme.primary }

    var body: some View {
        NavigationStack {
            Screen {
                CardDark {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(AppTheme.primary)
                        Text("Account")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    if let user = state.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(user.name)")
                                .foregroundStyle(textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(AppTheme.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                            Text("Email: \(user.email)")
                                .foregroundStyle(textSecondary)
                            if let role = state.userRole {
                                Label(role.capitalized, systemImage: role == "caregiver" ? "person.2.fill" : "person.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textSecondary)
                            }
                            if state.userRole == "caregiver", let patientName = state.careDataOwnerName {
                                Label("Caring for \(patientName)", systemImage: "heart.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)
                            }
                            if state.careLinkStatus == "pending" {
                                Label("Care connection awaiting confirmation", systemImage: "clock.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.warning)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Name: Guest")
                                .foregroundStyle(textPrimary)
                            Text("You are using the app as a guest.")
                                .foregroundStyle(textSecondary)

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                state.setGuest(false)
                            } label: {
                                Text("Exit Guest")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .background(AppTheme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppTheme.stroke, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .appCardStyle()

                CardDark {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(AppTheme.primary)
                        Text(state.isGuest ? "Exit Guest" : "Logout")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        if state.isGuest {
                            state.setGuest(false)
                        } else {
                            Task { await state.logout() }
                        }
                    } label: {
                        Text(state.isGuest ? "Exit Guest" : "Logout")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(Color.red)
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .appCardStyle()
            }
            .navigationTitle("Account")
        }
        .task {
            guard !state.isGuest else { return }
            await state.refreshProfileFromSupabase()
            await SyncEngine.fullSync(state: state)
        }
    }
}
