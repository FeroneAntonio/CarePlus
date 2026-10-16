import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Calming reminders", isOn: Binding(
                        get: { state.calmingRemindersEnabled },
                        set: { state.setCalmingReminders(enabled: $0) }
                    ))

                    if state.calmingRemindersEnabled {
                        Picker("Every", selection: Binding(
                            get: { state.calmingIntervalMinutes },
                            set: { state.setCalmingInterval(minutes: $0) }
                        )) {
                            ForEach(Set([10, 20, 30, 60, 120, state.calmingIntervalMinutes]).sorted(), id: \.self) { Text("\($0) min").tag($0) }
                        }
                    }
                } footer: {
                    Text("Gentle messages that help to calm down and refocus during the day.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(AppTheme.primary)
    }
}
