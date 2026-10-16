import SwiftUI
import UIKit
import Combine
import PhotosUI

struct ContactsDesignView: View {
    @Bindable var state: AppState
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var showAddContactSheet = false
    @State private var editingContact: ContactItem? = nil
    @State private var playingURL: URL? = nil
    @State private var recordingContactID: UUID? = nil
    @State private var isRecordingSheetPresented: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var photoPickerContactID: UUID? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil

    enum PickerContext { case doctor, caregiver, family }
    @State private var pickerContext: PickerContext? = nil
    @State private var showContactPicker: Bool = false

    private var doctorContact: ContactItem? {
        state.contacts.first(where: { $0.isDoctor })
    }

    private var caregiverContacts: [ContactItem] {
        state.contacts.filter { $0.isCaregiver }
    }

    /// Everyone who is not the doctor or a caregiver.
    private var otherContacts: [ContactItem] {
        state.contacts.filter { !$0.isCaregiver && !$0.isDoctor }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    TabHeader(state: state, title: "Contacts")

                    emergencyCardSection

                    if state.contacts.isEmpty {
                        importButton
                    }

                    roleSection("Doctor", icon: "stethoscope", contact: doctorContact, picker: .doctor)

                    roleSection("Caregiver", icon: "person.2.fill", contact: caregiverContacts.first, picker: .caregiver)

                    contactSection(title: "Family & friends", icon: "heart.fill", contacts: otherContacts)

                    addNewContactButton
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddContactSheet) {
                AddContactView(state: state, onAdd: { newContact in
                    state.upsertContact(newContact)
                })
            }
        }
        .sheet(item: $editingContact) { contact in
            EditContactView(state: state, contact: contact, onSave: { updated in
                if let idx = state.contacts.firstIndex(where: { $0.id == updated.id }) {
                    state.contacts[idx] = updated
                    state.saveContacts()
                }
            })
        }
        .sheet(isPresented: $isRecordingSheetPresented) {
            if let id = recordingContactID, let contact = state.contacts.first(where: { $0.id == id }) {
                RecordContactVoiceView(contact: contact, onSave: { savedURL in
                    if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                        state.contacts[idx].audioNoteURL = savedURL
                        state.saveContacts()
                    }
                    isRecordingSheetPresented = false
                }, onCancel: {
                    isRecordingSheetPresented = false
                }, onRemove: {
                    if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                        state.contacts[idx].audioNoteURL = nil
                        state.saveContacts()
                    }
                    isRecordingSheetPresented = false
                })
            } else {
                Text("No contact selected")
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Select a photo")
                        .font(.headline)
                }
                .padding()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showContactPicker) {
            VStack(alignment: .leading) {
                HStack {
                    Text(pickerContext == .doctor ? "Select a doctor" : (pickerContext == .caregiver ? "Select a caregiver" : "Select a family contact"))
                        .font(.headline)
                    Spacer()
                    Button("Close") { showContactPicker = false }
                        .font(.subheadline)
                }
                .padding()

                List(filteredContactsForPicker(), id: \.id) { contact in
                    Button {
                        applySelection(contact)
                        showContactPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(photo: contact.photoData)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(contact.relation ?? contact.phone ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task(id: photoPickerItem) {
            guard let item = photoPickerItem else { return }
            do {
                if let data = try await item.loadTransferable(type: Data.self), let id = photoPickerContactID, let idx = state.contacts.firstIndex(where: { $0.id == id }) {
                    state.contacts[idx].photoData = data
                    state.saveContacts()
                }
            } catch {
                // ignore errors silently
            }
            showPhotoPicker = false
            photoPickerItem = nil
            photoPickerContactID = nil
        }
    }
}

private extension ContactsDesignView {
    func setPrimaryCaregiver(_ c: ContactItem) {
        if let index = state.contacts.firstIndex(where: { $0.id == c.id }) {
            let currentlySet = state.contacts[index].isCaregiver
            for i in state.contacts.indices {
                state.contacts[i].isCaregiver = false
            }
            // Toggle off if already true, else set true
            state.contacts[index].isCaregiver = !currentlySet
            state.saveContacts()
        }
    }

    func setPrimaryDoctor(_ c: ContactItem) {
        if let index = state.contacts.firstIndex(where: { $0.id == c.id }) {
            let currentlySet = state.contacts[index].isDoctor
            for i in state.contacts.indices {
                state.contacts[i].isDoctor = false
            }
            // Toggle off if already true, else set true
            state.contacts[index].isDoctor = !currentlySet
            state.saveContacts()
        }
    }

    func filteredContactsForPicker() -> [ContactItem] {
        switch pickerContext {
        case .doctor:
            // Prefer non-doctor contacts to pick from, but allow all
            return state.contacts
        case .caregiver:
            return state.contacts
        case .family:
            // Family are those not doctor/caregiver
            return state.contacts.filter { !$0.isDoctor && !$0.isCaregiver }
        case .none:
            return state.contacts
        }
    }

    func applySelection(_ contact: ContactItem) {
        switch pickerContext {
        case .doctor:
            // Clear others and set this as doctor
            for i in state.contacts.indices { state.contacts[i].isDoctor = false }
            if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                state.contacts[idx].isDoctor = true
                state.saveContacts()
            }
        case .caregiver:
            // Clear others and set this as caregiver
            for i in state.contacts.indices { state.contacts[i].isCaregiver = false }
            if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                state.contacts[idx].isCaregiver = true
                state.saveContacts()
            }
        case .family:
            // Ensure not doctor/caregiver so it appears in Family section
            if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                state.contacts[idx].isDoctor = false
                state.contacts[idx].isCaregiver = false
                state.saveContacts()
            }
        case .none:
            break
        }
    }

    var emergencyCardSection: some View {
        CardDark {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Emergency SOS", systemImage: "sos.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.danger)
                    Text("One tap to call for help")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let sos = state.sosContact {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sos.name).font(.title2.bold()).foregroundStyle(AppTheme.textPrimary)
                            Text(sos.relation ?? "Primary Emergency Contact").font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            CallHelper.call(contact: sos, state: state)
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .accessibilityLabel("Call \(sos.name)")
                                .background(Circle().fill(AppTheme.danger))
                        }
                    }
                } else {
                    Button { showAddContactSheet = true } label: {
                        Label("Add an emergency contact", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var importButton: some View {
        Button {
            ContactsImportService.importFromDevice(existing: state.contacts) { imported in
                guard !imported.isEmpty else { return }
                var toAppend: [ContactItem] = []
                for c in imported {
                    let phoneC = (c.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let nameC = c.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let exists = state.contacts.contains { existing in
                        let phoneE = (existing.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let nameE = existing.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if !phoneC.isEmpty && phoneE == phoneC { return true }
                        return !phoneC.isEmpty && nameE == nameC && phoneE == phoneC
                    }
                    if !exists { toAppend.append(c) }
                }
                if !toAppend.isEmpty {
                    state.contacts.append(contentsOf: toAppend)
                    state.saveContacts()
                }
            }
        } label: {
            Label("Import from device", systemImage: "arrow.down.doc.fill")
                .font(.subheadline.bold()).foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(AppTheme.primary.opacity(0.1)).cornerRadius(12)
        }
    }

    func contactSection(title: String, icon: String, contacts: [ContactItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel(title, icon: icon)
                Spacer()
                Button {
                    pickerContext = .family
                    showContactPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to \(title)")
            }
            CardDark {
                if contacts.isEmpty {
                    Text("No contacts yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(contacts) { contact in
                        contactRow(contact)
                        if contact.id != contacts.last?.id { Divider() }
                    }
                }
            }
        }
    }

    /// Single-contact section (doctor / caregiver) with an empty state that opens the picker.
    func roleSection(_ title: String, icon: String, contact: ContactItem?, picker: PickerContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title, icon: icon)
            CardDark {
                if let contact {
                    contactRow(contact)
                } else {
                    Button {
                        pickerContext = picker
                        showContactPicker = true
                    } label: {
                        Label("Choose a \(title.lowercased())", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(AppTheme.primary)
            .padding(.horizontal, 4)
    }

    func contactRow(_ contact: ContactItem) -> some View {
        let isPlaying = contact.audioNoteURL != nil && playingURL == contact.audioNoteURL

        return HStack(spacing: 14) {
            Button { editingContact = contact } label: {
                HStack(spacing: 14) {
                    Avatar(photo: contact.photoData)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        if let relation = contact.relation, !relation.isEmpty {
                            Text(relation)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let url = contact.audioNoteURL {
                circleButton(isPlaying ? "stop.fill" : "waveform", tint: AppTheme.primary, label: "Play voice of \(contact.name)") {
                    if isPlaying {
                        audioPlayer.stop()
                        playingURL = nil
                    } else {
                        audioPlayer.play(url: url)
                        playingURL = url
                    }
                }
            }

            circleButton("phone.fill", tint: AppTheme.success, label: "Call \(contact.name)") {
                CallHelper.call(contact: contact, state: state)
            }

            Menu {
                Button { setPrimaryCaregiver(contact) } label: { Label("Set as Caregiver", systemImage: "person.2.fill") }
                Button { setPrimaryDoctor(contact) } label: { Label("Set as Doctor", systemImage: "stethoscope") }
                Button { state.setSOSContact(contact) } label: { Label("Set as Emergency SOS", systemImage: "star.fill") }
                Divider()
                Button {
                    photoPickerContactID = contact.id
                    showPhotoPicker = true
                } label: { Label("Change photo", systemImage: "photo") }
                Button {
                    recordingContactID = contact.id
                    isRecordingSheetPresented = true
                } label: { Label("Record voice", systemImage: "mic.fill") }
                Button { editingContact = contact } label: { Label("Edit", systemImage: "pencil") }
                Divider()
                if contact.audioNoteURL != nil {
                    Button(role: .destructive) {
                        if let idx = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                            state.contacts[idx].audioNoteURL = nil
                            state.saveContacts()
                        }
                    } label: { Label("Remove voice", systemImage: "waveform.slash") }
                }
                Button(role: .destructive) {
                    state.contacts.removeAll { $0.id == contact.id }
                    state.saveContacts()
                } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 28, height: 44)
            }
            .accessibilityLabel("More actions for \(contact.name)")
        }
    }

    func circleButton(_ systemImage: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    var addNewContactButton: some View {
        Button { showAddContactSheet = true } label: {
            Label("Add a new contact", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.primary, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

import AVFoundation
struct RecordContactVoiceView: View {
    let contact: ContactItem
    let onSave: (URL) -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void

    @StateObject private var recorder = ContactAudioRecorder()
    @State private var isRecording = false
    @State private var savedURL: URL? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Record voice for \(contact.name)")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button(action: toggleRecording) {
                    VStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 72))
                        Text(isRecording ? "Stop" : "Start Recording")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if let url = savedURL {
                    Text("Recorded: \(url.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Button(role: .cancel, action: { onCancel() }) {
                        Text("Cancel")
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if contact.audioNoteURL != nil {
                        Button(role: .destructive, action: { onRemove() }) { Text("Remove") }
                    }
                    Button(action: {
                        if let url = savedURL {
                            onSave(url)
                        } else {
                            // Ifsi v not explicitly saved after a stop, stop and save now
                            Task { await finalizeRecordingAndSave() }
                        }
                    }) { Text("Save") }
                    .disabled(isRecording)
                }
                .font(.headline)
            }
            .padding()
        }
        .onDisappear {
            if isRecording { recorder.stopRecording() }
        }
    }

    private func toggleRecording() {
        if isRecording {
            let url = recorder.stopRecording()
            savedURL = url
            isRecording = false
        } else {
            Task {
                let filename = "contact_\(contact.id.uuidString).m4a"
                if await recorder.startRecording(fileName: filename) != nil {
                    savedURL = nil
                    isRecording = true
                }
            }
        }
    }

    private func finalizeRecordingAndSave() async {
        if isRecording {
            let url = recorder.stopRecording()
            isRecording = false
            savedURL = url
        }
        if let url = savedURL {
            onSave(url)
        }
    }
}

final class ContactAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?

    @MainActor
    func startRecording(fileName: String) async -> URL? {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return nil
        }

        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        guard granted else { return nil }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            return url
        } catch {
            return nil
        }
    }

    func stopRecording() -> URL? {
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        return url
    }
}

