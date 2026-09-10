import SwiftUI
import UIKit

struct HomeView: View {
    @Bindable var state: AppState
    @Binding var selectedTab: AppTab

    @StateObject private var homeAudioPlayer = AudioPlayer()
    @State private var currentlyPlayingURL: URL? = nil

    @Environment(\.colorScheme) private var scheme

    private var textPrimary: Color { scheme == .dark ? .white : AppTheme.iconLight }
    private var textSecondary: Color { scheme == .dark ? .white.opacity(0.75) : AppTheme.iconLight.opacity(0.70) }
    private var iconColor: Color { scheme == .dark ? .white : AppTheme.iconLight }

    private var firstName: String {
        state.currentUser?.name.split(separator: " ").first.map(String.init) ?? "there"
    }

    // Design target: "You completed X/3"
    private var gamesCompletedToday: Int {
        min(3, state.gameSessions(on: .now).count)
    }

    var body: some View {
        NavigationStack {
            Screen {
                topIconsRow

                calendarCard

                HStack(spacing: 14) {
                    smallActionCard(
                        title: "Medication",
                        systemIcon: "pill",
                        action: { UIImpactFeedbackGenerator(style: .light).impactOccurred() } // haptic only
                    )

                    smallActionCard(
                        title: "Listen voice",
                        systemIcon: "speaker.wave.2.fill",
                        action: { UIImpactFeedbackGenerator(style: .light).impactOccurred() } // haptic only
                    )
                }

                quickTasksCard

                audioNotesCard

                contactsImportCard

                eventsCard

                activitiesCard
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Subviews
private extension HomeView {

    var topIconsRow: some View {
        HStack {
            // Left: profile icon
            Menu {
                NavigationLink {
                    AccountView(state: state)
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }

                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await state.logout() }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: brain icon (logo placeholder)
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)

            Spacer()

            // Right: ellipsis menu
            Button {
                // Placeholder: puoi aprire sheet/azioni rapide
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    var calendarCard: some View {
        CardDark {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.headline)
                            .foregroundStyle(iconColor)

                        Text("Calendar")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(iconColor)

                        Spacer()
                    }

                    Text(Date.now.formatted(.dateTime.weekday().month().day()))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(textPrimary)

                    Text("Good morning, \(firstName)")
                        .font(.headline)
                        .foregroundStyle(textPrimary)

                    // Nel design è testo statico
                    Text("Today is a sunny day!")
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }

                Spacer()

                Button {
                    // Changed to haptic only
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }.appCardStyle()
    }

    func smallActionCard(title: String, systemIcon: String, action: @escaping () -> Void) -> some View {
        CardDark {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: systemIcon)
                        .font(.headline)
                        .foregroundStyle(iconColor)

                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(iconColor)

                    Spacer()
                }

                Spacer(minLength: 0)

                Button(action: {
                    // Override action to haptic only
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
            }
            .frame(height: 110) // [Inferenza] altezza per match visivo
        }.appCardStyle()
    }

    var eventsCard: some View {
        CardDark {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textOnSurfacePrimary)

                Text("Tasks")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textOnSurfacePrimary)

                Spacer()
            }

            Button {
                // Changed to haptic only
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textOnSurfacePrimary)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.surface.opacity(0.92))
                    .overlay(
                        Circle().stroke(AppTheme.secondary.opacity(0.32), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }.appCardStyle()
    }

    var activitiesCard: some View {
        CardDark {
            HStack(spacing: 10) {
                Image(systemName: "puzzlepiece.fill")
                    .font(.headline)
                    .foregroundStyle(iconColor)

                Text("Today's activities")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconColor)

                Spacer()
            }

            Text("You completed \(gamesCompletedToday)/3 memory games")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textPrimary)

            ProgressView(value: Double(gamesCompletedToday), total: 3.0)
                .tint(Color.white.opacity(0.9))

            Button {
                // Changed to haptic only
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("Play games")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(scheme == .dark ? Color.white.opacity(0.92) : AppTheme.lavenderButtonLight)
                    .foregroundStyle(scheme == .dark ? .black : AppTheme.iconLight)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(scheme == .dark ? Color.black.opacity(0.15) : AppTheme.iconLight.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }.appCardStyle()
    }

    var quickTasksCard: some View {
        CardDark {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundStyle(iconColor)

                Text("Today's tasks")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconColor)

                Spacer()
            }

            if todaysTasks.isEmpty {
                Text("No tasks for today.")
                    .font(.subheadline)
                    .foregroundStyle(textSecondary)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(todaysTasks.prefix(4)) { task in
                        Button {
                            toggleDoneHome(task)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? AppTheme.success : Color.white.opacity(0.85))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(textPrimary)

                                    if let t = task.scheduledAt {
                                        Text(t.formatted(.dateTime.hour().minute()))
                                            .font(.caption2)
                                            .foregroundStyle(textSecondary)
                                    }
                                }

                                Spacer()

                                if task.kind == .medication {
                                    Image(systemName: "pill")
                                        .foregroundStyle(iconColor.opacity(0.85))
                                } else {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(iconColor.opacity(0.85))
                                }
                            }
                            .padding(.vertical, 6)
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.white.opacity(0.12)),
                                alignment: .bottom
                            )
                        }
                        .buttonStyle(.plain)

                        if let url = task.audioURL {
                            HStack(spacing: 8) {
                                Button {
                                    if currentlyPlayingURL == url && homeAudioPlayer.isPlaying {
                                        homeAudioPlayer.stop()
                                        currentlyPlayingURL = nil
                                    } else {
                                        homeAudioPlayer.stop()
                                        homeAudioPlayer.play(url: url)
                                        currentlyPlayingURL = url
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: (currentlyPlayingURL == url && homeAudioPlayer.isPlaying) ? "stop.fill" : "play.fill")
                                        Text((currentlyPlayingURL == url && homeAudioPlayer.isPlaying) ? "Stop" : "Listen")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(scheme == .dark ? Color.white.opacity(0.92) : AppTheme.lavenderButtonLight)
                                    .foregroundStyle(scheme == .dark ? .black : AppTheme.iconLight)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(scheme == .dark ? Color.black.opacity(0.15) : AppTheme.iconLight.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                        }
                    }
                }
                .padding(.top, 6)

                Button {
                    // Changed to haptic only
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("Manage tasks")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(scheme == .dark ? Color.white.opacity(0.92) : AppTheme.lavenderButtonLight)
                        .foregroundStyle(scheme == .dark ? .black : AppTheme.iconLight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(scheme == .dark ? Color.black.opacity(0.15) : AppTheme.iconLight.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }.appCardStyle()
    }

    var audioNotesCard: some View {
        CardDark {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.headline)
                    .foregroundStyle(iconColor)

                Text("Audio notes")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconColor)

                Spacer()
            }

            if audioContacts.isEmpty {
                Text("No audio notes available.")
                    .font(.subheadline)
                    .foregroundStyle(textSecondary)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(audioContacts.prefix(3), id: \.contact.id) { item in
                        let contact = item.contact
                        let url = item.url
                        Button {
                            togglePlay(url: url)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: (currentlyPlayingURL == url && homeAudioPlayer.isPlaying) ? "stop.fill" : "play.fill")
                                    .foregroundStyle(scheme == .dark ? .black : AppTheme.iconLight)
                                    .frame(width: 36, height: 36)
                                    .background(scheme == .dark ? Color.white.opacity(0.92) : AppTheme.lavenderButtonLight)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(scheme == .dark ? Color.black.opacity(0.15) : AppTheme.iconLight.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                            }

                            Text(contact.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(textPrimary)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.white.opacity(0.12)),
                            alignment: .bottom
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            }
        }.appCardStyle()
    }

    var contactsImportCard: some View {
        CardDark {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .foregroundStyle(iconColor)
                Text("Contacts")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconColor)

                Spacer()
            }

            Button {
                importDeviceContacts()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import from Contacts")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            NavigationLink {
                DialPadView(state: state)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "circle.grid.3x3.fill")
                    Text("Dial pad")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("You can import your address book; then optionally add photos and audios.")
                .font(.caption)
                .foregroundStyle(textSecondary)
        }.appCardStyle()
    }

    // MARK: - Helpers
    private var todayBounds: (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? .now
        return (start, end)
    }

    private var todaysTasks: [TaskItem] {
        state.tasks
            .filter { t in
                guard let d = t.scheduledAt else { return false }
                let (start, end) = todayBounds
                return d >= start && d < end
            }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    private var audioContacts: [(contact: ContactItem, url: URL)] {
        state.contacts.compactMap { c in
            if let u = c.audioNoteURL { return (c, u) }
            return nil
        }
    }

    private func toggleDoneHome(_ task: TaskItem) {
        if let idx = state.tasks.firstIndex(where: { $0.id == task.id }) {
            state.tasks[idx].isDone.toggle()
            state.tasks[idx].updatedAt = .now
            state.saveTasks()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func togglePlay(url: URL) {
        if currentlyPlayingURL == url && homeAudioPlayer.isPlaying {
            homeAudioPlayer.stop()
            currentlyPlayingURL = nil
        } else {
            homeAudioPlayer.stop()
            homeAudioPlayer.play(url: url)
            currentlyPlayingURL = url
        }
    }

    private func importDeviceContacts() {
        ContactsImportService.importFromDevice(existing: state.contacts) { imported in
            guard !imported.isEmpty else { return }
            var appended: [ContactItem] = []
            for c in imported {
                let phoneC = (c.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let exists = state.contacts.contains { existing in
                    if existing.id == c.id { return true }
                    let phoneE = (existing.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return !phoneC.isEmpty && phoneE == phoneC
                }
                if !exists {
                    appended.append(c)
                }
            }
            if !appended.isEmpty {
                state.contacts.append(contentsOf: appended)
                state.saveContacts()
                print("Imported contacts count: \(state.contacts.count)")
            }
        }
    }
}

