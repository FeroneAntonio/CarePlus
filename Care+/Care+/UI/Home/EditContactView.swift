import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var state: AppState

    // Original contact to edit
    let contact: ContactItem
    // Completion on save
    var onSave: (ContactItem) -> Void

    // Editable fields
    @State private var name: String
    @State private var relation: String
    @State private var phone: String
    @State private var email: String

    // Photo editing
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    @StateObject private var audioPlayer = AudioPlayer()
    @State private var playingURL: URL? = nil
    @State private var isRecording: Bool = false
    @State private var tempRecordedURL: URL? = nil
    @State private var showRecorderSheet: Bool = false
    @State private var showDeleteAlert: Bool = false

    init(state: AppState, contact: ContactItem, onSave: @escaping (ContactItem) -> Void) {
        self._state = Bindable(wrappedValue: state)
        self.contact = contact
        self.onSave = onSave
        _name = State(initialValue: contact.name)
        _relation = State(initialValue: contact.relation ?? "")
        _phone = State(initialValue: contact.phone ?? "")
        _email = State(initialValue: contact.email ?? "")
        _photoData = State(initialValue: contact.photoData) // start from existing photo
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Info")) {
                    TextField("Name", text: $name)
                    TextField("Relation", text: $relation)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                }

                // PHOTO (editable)
                Section(header: Text("Photo")) {
                    HStack(spacing: 12) {
                        avatarPreview
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(photoData == nil ? "No photo selected" : "Photo selected")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                                Label(photoData == nil ? "Add photo" : "Change photo", systemImage: "photo")
                            }

                            if photoData != nil {
                                Button(role: .destructive) {
                                    photoData = nil
                                    photoPickerItem = nil
                                } label: {
                                    Label("Remove photo", systemImage: "trash")
                                }
                                .font(.footnote)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .task(id: photoPickerItem) {
                    guard let item = photoPickerItem else { return }
                    do {
                        if let data = try await item.loadTransferable(type: Data.self) {
                            photoData = data
                        }
                    } catch {
                        // ignore
                    }
                }

                Section(header: Text("Voice note")) {
                    if contact.audioNoteURL == nil && tempRecordedURL == nil {
                        Text("No voice note yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button {
                            showRecorderSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Record voice")
                            }
                        }
                    } else {
                        Text("Voice note saved")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                let url = tempRecordedURL ?? contact.audioNoteURL!
                                if playingURL == url {
                                    audioPlayer.stop()
                                    playingURL = nil
                                } else {
                                    audioPlayer.play(url: url)
                                    playingURL = url
                                }
                            } label: {
                                HStack {
                                    Image(systemName: (playingURL == (tempRecordedURL ?? contact.audioNoteURL)) ? "stop.fill" : "play.fill")
                                    Text((playingURL == (tempRecordedURL ?? contact.audioNoteURL)) ? "Stop" : "Play")
                                }
                            }

                            Button {
                                showRecorderSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Re-record")
                                }
                            }

                            Button(role: .destructive) {
                                tempRecordedURL = nil
                                if playingURL != nil { audioPlayer.stop(); playingURL = nil }
                                var updated = contact
                                updated.audioNoteURL = nil
                                onSave(updated)
                                if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                                    state.contacts[idx].audioNoteURL = nil
                                    state.saveContacts()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove voice note")
                                }
                            }
                        }
                    }
                }

                if let url = contact.audioNoteURL {
                    Section(header: Text("Audio Note")) {
                        Text(url.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if state.sosContact?.id == contact.id {
                    Section {
                        Label("Primary Emergency Contact", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Text("Delete contact")
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showRecorderSheet) {
            RecordContactVoiceView(contact: contact) { savedURL in
                tempRecordedURL = savedURL
                showRecorderSheet = false
            } onCancel: {
                showRecorderSheet = false
            } onRemove: {
                tempRecordedURL = nil
                var updated = contact
                updated.audioNoteURL = nil
                onSave(updated)
                if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                    state.contacts[idx].audioNoteURL = nil
                    state.saveContacts()
                }
                showRecorderSheet = false
            }
        }
        .alert("Delete this contact?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let index = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                    state.contacts.remove(at: index)
                    state.saveContacts()
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var avatarPreview: some View {
        Group {
            if let data = photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                    Image(systemName: "person.crop.square")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        var updated = contact
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.relation = relation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : relation
        updated.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : phone
        updated.email = email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : email

        // SAVE PHOTO
        updated.photoData = photoData

        // SAVE AUDIO
        if let tempURL = tempRecordedURL {
            updated.audioNoteURL = tempURL
        }

        onSave(updated)
        dismiss()
    }
}
