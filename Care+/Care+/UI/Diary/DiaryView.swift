//
//  DiaryView.swift
//  Care+
//

import SwiftUI
import UIKit
import PhotosUI
import AVKit

struct DiaryView: View {
    @Bindable var state: AppState
    @Environment(\.colorScheme) private var scheme

    @State private var text = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var pickedVideoURL: URL?
    @State private var selectedMood: Mood? = nil

    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()

    @State private var entryToDelete: DiaryEntry?
    @State private var showDeleteEntryConfirm = false

    // ✅ Header (same as Hub / Tasks)
    @State private var showAccount = false
    @State private var showSettings = false
    @State private var showMenu = false

    // ✅ Same header colors as TasksTabView (kept)
    private var textPrimary: Color { scheme == .dark ? .white : AppTheme.iconLight }
    private var textSecondary: Color { scheme == .dark ? .white.opacity(0.75) : AppTheme.iconLight.opacity(0.70) }
    private var iconColor: Color { scheme == .dark ? .white : AppTheme.iconLight }

    private var canAddEntry: Bool {
        Validators.nonEmpty(text)
        || pickedImageData != nil
        || pickedVideoURL != nil
        || recorder.lastRecordingURL != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                // ✅ Same container logic as Home (one single horizontal padding)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {

                        header

                        VStack(spacing: 10) {

                            // Mood selector
                            CardDark {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Color.clear
                                            .frame(width: 20, height: 20)
                                        Text("How was your day?")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                    }

                                    HStack(spacing: 10) {
                                        moodButton(title: "Not good", icon: Mood.notGood.emoji, mood: .notGood)
                                        moodButton(title: "Okay", icon: Mood.okay.emoji, mood: .okay)
                                        moodButton(title: "Perfect", icon: Mood.perfect.emoji, mood: .perfect)
                                    }

                                    if let m = selectedMood {
                                        Text("Selected mood: \(m == .notGood ? "Not good" : m == .okay ? "Okay" : "Perfect")")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }

                            // Today's memory
                            CardDark {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "calendar")
                                            .foregroundStyle(AppTheme.primary)
                                        Text("Today's memory")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .font(.caption)
                                    }

                                    HStack(spacing: 10) {
                                        PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "photo")
                                                Text("Add a photo")
                                                    .lineLimit(1)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .frame(height: 36)
                                            .background(AppTheme.primary.opacity(0.14))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(AppTheme.stroke, lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                        .simultaneousGesture(TapGesture().onEnded {
                                            if recorder.isRecording { recorder.stop() }
                                        })

                                        Button {
                                            recorder.isRecording ? recorder.stop() : recorder.start()
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                                Text(recorder.isRecording ? "Stop" : "Record a note")
                                                    .lineLimit(1)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .frame(height: 36)
                                            .background(AppTheme.primary.opacity(recorder.isRecording ? 0.22 : 0.14))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(
                                                        recorder.isRecording
                                                        ? AppTheme.danger.opacity(0.7)
                                                        : AppTheme.stroke,
                                                        lineWidth: recorder.isRecording ? 2 : 1
                                                    )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // Attachments previews
                                    if let data = pickedImageData, let ui = UIImage(data: data) {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 160)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    pickedImageData = nil
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(AppTheme.textPrimary)
                                                        .shadow(radius: 8)
                                                        .padding(8)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                    }

                                    if let url = pickedVideoURL {
                                        VideoPlayer(player: AVPlayer(url: url))
                                            .frame(height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    pickedVideoURL = nil
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(AppTheme.textPrimary)
                                                        .shadow(radius: 8)
                                                        .padding(8)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                    }

                                    if let url = recorder.lastRecordingURL {
                                        HStack(spacing: 10) {
                                            MiniChip(icon: "waveform", text: "Audio ready")
                                            Spacer()

                                            Button {
                                                player.isPlaying ? player.stop() : player.play(url: url)
                                            } label: {
                                                Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(AppTheme.textPrimary)

                                            Button {
                                                if player.isPlaying { player.stop() }
                                                recorder.lastRecordingURL = nil
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(AppTheme.danger)
                                        }
                                    }

                                    Text("Write a memory")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .padding(.top, 4)

                                    TextEditor(text: $text)
                                        .frame(height: 140)
                                        .scrollContentBackground(.hidden)
                                        .padding(10)
                                        .background(AppTheme.surface)
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppTheme.stroke, lineWidth: 1)
                                        )

                                    HStack(spacing: 10) {
                                        PrimaryButton("Cancel", style: .soft, color: AppTheme.secondary) {
                                            text = ""
                                            pickedItem = nil
                                            pickedImageData = nil
                                            pickedVideoURL = nil

                                            if recorder.isRecording { recorder.stop() }
                                            recorder.lastRecordingURL = nil
                                            if player.isPlaying { player.stop() }

                                            selectedMood = nil
                                        }

                                        PrimaryButton("Confirm", style: .filled, color: AppTheme.primary) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            addEntry()
                                        }
                                        .disabled(!canAddEntry)
                                    }
                                    .padding(.top, 2)
                                }
                            }

                            // Previous days
                            CardDark {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("Last memories")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                }

                                if state.diary.isEmpty {
                                    Text("No entries yet.")
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .padding(.top, 6)
                                } else {
                                    VStack(spacing: 10) {
                                        let calendar = Calendar.current
                                        let groups = Dictionary(grouping: state.diary) { entry in
                                            calendar.startOfDay(for: entry.date)
                                        }
                                        .sorted { $0.key > $1.key }

                                        ForEach(groups, id: \.key) { day, entries in
                                            CollapsibleDaySection(
                                                day: day,
                                                entries: entries,
                                                onDelete: { entry in
                                                    entryToDelete = entry
                                                    showDeleteEntryConfirm = true
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 140)
                        }
                    }
                    .padding(.horizontal, 18) // ✅ matches Home
                    .padding(.top, 12)        // ✅ matches Home
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            // ✅ Header sheets (Account / Settings)
            .sheet(isPresented: $showAccount) {
                AccountView(state: state)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(state: state)
            }

            .alert("Delete this entry?", isPresented: $showDeleteEntryConfirm) {
                Button("Delete", role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if let e = entryToDelete {
                        FileStore.removeManagedFile(at: e.videoURL)
                        FileStore.removeManagedFile(at: e.audioURL)
                        state.diary.removeAll { $0.id == e.id }
                        state.saveDiary()
                        Task { await SyncEngine.deleteDiaryEntry(id: e.id, state: state) }
                    }
                    entryToDelete = nil
                }
                Button("Cancel", role: .cancel) { entryToDelete = nil }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .task(id: pickedItem) {
            guard pickedItem != nil else { return }
            let res = await MediaLoader.load(from: pickedItem)
            if let img = res.imageData {
                pickedImageData = img
                pickedVideoURL = nil
            } else if let v = res.videoURL {
                pickedVideoURL = v
                pickedImageData = nil
            }
        }
        .onTapGesture { dismissKeyboard() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
    }

    // MARK: - Header (same as Hub / Tasks)
    private var header: some View {
        ZStack {
            HStack(spacing: 10) {
                Button { showAccount = true } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 28, height: 28, alignment: .center)
                }
                .buttonStyle(.plain)

                Spacer()

                Button { showMenu = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 28, height: 28, alignment: .center)
                }
                .buttonStyle(.plain)
            }

            Text("Diary")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
        }
        .confirmationDialog("Menu", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Settings") { showSettings = true }
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Diary header")
    }

    // MARK: - UI helpers
    private func moodButton(title: String, icon: String, mood: Mood) -> some View {
        let isSelected = (selectedMood == mood)

        return Button {
            selectedMood = mood
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 26))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                ? AppTheme.primary.opacity(scheme == .dark ? 0.22 : 0.16)
                                : AppTheme.secondary.opacity(scheme == .dark ? 0.10 : 0.08)
                            )
                    )

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .frame(width: 104, height: 86)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AppTheme.primary.opacity(0.16) : AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        AppTheme.primary.opacity(isSelected ? 0.36 : 0.22),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(AppTheme.primary.opacity(scheme == .dark ? 0.25 : 0.18))
                        )
                        .padding(6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // Visual preview for the "Last memories" list
    private struct DiaryLeadingPreview: View {
        let entry: DiaryEntry

        var body: some View {
            Group {
                if let data = entry.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else if entry.videoURL != nil {
                    ZStack {
                        Rectangle().fill(AppTheme.surface)
                        Image(systemName: "video.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if entry.audioURL != nil {
                    ZStack {
                        Rectangle().fill(AppTheme.surface)
                        Image(systemName: "waveform")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    ZStack {
                        Rectangle().fill(AppTheme.surface)
                        Text(entry.mood?.emoji ?? "🙂").font(.title3)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
        }
    }

    private struct CollapsibleDaySection: View {
        let day: Date
        let entries: [DiaryEntry]
        let onDelete: (DiaryEntry) -> Void

        @Environment(\.colorScheme) private var scheme
        @State private var isExpanded: Bool = false

        var body: some View {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        HStack(spacing: 10) {
                            NavigationLink {
                                DiaryEntryDetailView(entry: entry)
                            } label: {
                                HStack(spacing: 10) {
                                    DiaryLeadingPreview(entry: entry)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.text.isEmpty ? "(No text)" : entry.text)
                                            .lineLimit(1)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)

                                        HStack(spacing: 6) {
                                            if entry.imageData != nil { MiniChip(icon: "photo", text: "Photo") }
                                            if entry.videoURL != nil { MiniChip(icon: "video", text: "Video") }
                                            if entry.audioURL != nil { MiniChip(icon: "waveform", text: "Audio") }
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                onDelete(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(AppTheme.stroke),
                            alignment: .bottom
                        )
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 10) {
                    Text(formattedDay(day))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { isExpanded.toggle() } }
            }
            .tint(AppTheme.primary)
        }

        private func formattedDay(_ date: Date) -> String {
            date.formatted(.dateTime.weekday().month().day())
        }
    }

    private struct DiaryEntryDetailView: View {
        let entry: DiaryEntry
        @StateObject private var player = AudioPlayer()

        private var moodLabel: String {
            switch entry.mood {
            case .some(.notGood): return "Not good"
            case .some(.okay): return "Okay"
            case .some(.perfect): return "Perfect"
            case .none:
                let count = entry.text.count
                return count > 40 ? "Great" : (count > 10 ? "Okay" : "Not good")
            }
        }

        var body: some View {
            ScrollView {
                VStack(spacing: 14) {
                    CardDark {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(entry.date.formatted(.dateTime.weekday().month().day()))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Text(entry.mood?.emoji ?? "🙂")
                                .font(.title2)
                            Text(moodLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                        }
                    }

                    if let data = entry.imageData, let ui = UIImage(data: data) {
                        CardDark {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    if let url = entry.videoURL {
                        CardDark {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    if let url = entry.audioURL {
                        CardDark {
                            HStack(spacing: 12) {
                                Button {
                                    player.isPlaying ? player.stop() : player.play(url: url)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        Text(player.isPlaying ? "Pause" : "Play")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(AppTheme.primary.opacity(0.14))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                        }
                    }

                    CardDark {
                        Text(entry.text.isEmpty ? "(No text)" : entry.text)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Diary Entry")
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func addEntry() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let persistentVideoURL = pickedVideoURL.flatMap {
            FileStore.persist(url: $0, folder: "videos")
        }
        let persistentAudioURL = recorder.lastRecordingURL.flatMap {
            FileStore.persist(url: $0, folder: "audio")
        }

        state.diary.insert(
            DiaryEntry(
                date: .now,
                text: trimmed,
                imageData: pickedImageData,
                videoURL: persistentVideoURL,
                audioURL: persistentAudioURL,
                mood: selectedMood
            ),
            at: 0
        )
        state.saveDiary()

        text = ""
        pickedItem = nil
        pickedImageData = nil
        pickedVideoURL = nil

        if recorder.isRecording { recorder.stop() }
        recorder.lastRecordingURL = nil

        selectedMood = nil
        if player.isPlaying { player.stop() }
    }
}
