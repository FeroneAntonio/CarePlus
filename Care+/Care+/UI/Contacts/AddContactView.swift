import SwiftUI
import PhotosUI

struct AddContactView: View {
    @Bindable var state: AppState
    var onAdd: (ContactItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = AudioRecorder()
    @State private var name = ""
    @State private var relation = ""
    @State private var phone = ""
    // Predefined roles for quick selection
    private let predefinedRoles: [String] = [
        "Caregiver", "Son", "Daughter", "Doctor", "Friend", "Neighbor", "Nurse", "Therapist", "Partner", "Sibling"
    ]
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var recordedURL: URL?

    var body: some View {
        NavigationStack {
            Screen {
                VStack(spacing: 20) {
                    CardDark {
                        Text("New contact").font(.title2.bold()).foregroundStyle(AppTheme.textPrimary)
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $avatarItem, matching: .images) { Avatar(photo: avatarData).frame(width: 64, height: 64) }
                            Text("Tap avatar to add photo").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                        }
                        LabeledField(label: "Name (required)", placeholder: "Name", text: $name)
                        LabeledField(label: "Role (unique)", placeholder: "e.g. Daughter", text: $relation)
                        // Role dropdown menu (optional)
                        HStack {
                            Menu {
                                ForEach(predefinedRoles, id: \.self) { role in
                                    Button(role) { relation = role }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "list.bullet")
                                    Text(relation.isEmpty ? "Choose role" : relation)
                                        .lineLimit(1)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.surface)
                                .foregroundStyle(AppTheme.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.textSecondary.opacity(0.25), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            Spacer(minLength: 0)
                        }
                        LabeledField(label: "Phone", placeholder: "+39...", text: $phone, keyboard: .phonePad)
                    }

                    CardDark {
                        Text("Voice Note").font(.headline).foregroundStyle(AppTheme.textPrimary)
                        Button {
                            if recorder.isRecording { recorder.stop(); recordedURL = recorder.lastRecordingURL }
                            else { recorder.start() }
                        } label: {
                            HStack {
                                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                Text(recorder.isRecording ? "Stop Recording" : (recordedURL == nil ? "Record voice" : "Record Again"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(recorder.isRecording ? AppTheme.danger : AppTheme.primary)
                            .foregroundStyle(.white)
                            .cornerRadius(15)
                        }
                    }

                    Button {
                        let newItem = ContactItem(name: name, relation: relation.isEmpty ? nil : relation, phone: phone.isEmpty ? nil : phone, photoData: avatarData, audioNoteURL: recordedURL)
                        onAdd(newItem)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(name.isEmpty ? AppTheme.surface : AppTheme.primary)
                            .foregroundStyle(name.isEmpty ? AppTheme.textSecondary : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke((name.isEmpty ? AppTheme.textSecondary.opacity(0.25) : AppTheme.primary.opacity(0.25)), lineWidth: 1)
                            )
                    }.buttonStyle(.plain).disabled(name.isEmpty)
                }
            }
            .navigationTitle("Add Contact")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Indietro")
                        }
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .task(id: avatarItem) { if let data = try? await avatarItem?.loadTransferable(type: Data.self) { avatarData = data } }
    }
}

