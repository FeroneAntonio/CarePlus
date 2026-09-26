import SwiftUI
import UIKit

fileprivate func dismissKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

struct TasksTabView: View {
    @Bindable var state: AppState

    @State private var selectedDate: Date = .now
    @State private var showCreateSheet = false
    @State private var showMedicineInventory = false
    @State private var createPrefillKind: TaskKind = .event

    @State private var taskToDelete: TaskItem? = nil
    @State private var showFirstDeleteConfirm = false
    @State private var showSecondDeleteConfirm = false
    @StateObject private var taskAudioPlayer = AudioPlayer()
    @State private var playingTaskURL: URL? = nil

    // ✅ Header (same as Hub)
    @State private var showAccount = false
    @State private var showSettings = false
    @State private var showMenu = false

    @Environment(\.colorScheme) private var scheme
    private var textPrimary: Color { AppTheme.textPrimary }
    private var textSecondary: Color { AppTheme.textSecondary }
    private var iconColor: Color { AppTheme.primary }

    // MARK: - Date helpers
    private var dayBounds: (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? selectedDate
        return (start, end)
    }

    private func isSameSelectedDay(_ d: Date?) -> Bool {
        guard let d else { return false }
        let (start, end) = dayBounds
        return d >= start && d < end
    }

    // MARK: - Lists
    private var todayEvents: [TaskItem] {
        state.tasks
            .filter { $0.kind == .event }
            .filter { isSameSelectedDay($0.scheduledAt) }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    private var todayMedications: [TaskItem] {
        state.tasks
            .filter { $0.kind == .medication }
            .filter { isSameSelectedDay($0.scheduledAt) }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    private var subtitleDateString: String {
        selectedDate.formatted(.dateTime.weekday().month().day())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                // ✅ Same container logic as Home/Diary:
                // one ScrollView + one horizontal padding (18) + top padding (12)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        header

                        addNewTaskButton
                        medicationCard
                        calendarCard

                        if !todayEvents.isEmpty {
                            tasksCard
                        }

                        Spacer(minLength: 140)
                    }
                    .padding(.horizontal, 18) // ✅ matches Home
                    .padding(.top, 12)        // ✅ matches Home
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            // Create sheet
            .sheet(isPresented: $showCreateSheet) {
                CreateTaskSheet(
                    state: state,
                    selectedDate: selectedDate,
                    prefillKind: createPrefillKind
                )
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }

            .sheet(isPresented: $showMedicineInventory) {
                MedicineInventoryView(state: state)
            }

            // ✅ Header sheets (Account / Settings)
            .sheet(isPresented: $showAccount) {
                AccountView(state: state)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(state: state)
            }

            .alert("Delete this item?", isPresented: $showFirstDeleteConfirm) {
                Button("Continue", role: .destructive) { showSecondDeleteConfirm = true }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Are you absolutely sure?", isPresented: $showSecondDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let t = taskToDelete {
                        if let nid = t.notificationId {
                            NotificationManager.cancel(id: nid)
                        }
                        state.tasks.removeAll { $0.id == t.id }
                        state.saveTasks()
                        Task { await SyncEngine.deleteTask(id: t.id, state: state) }
                    }
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } message: {
                Text("Double check: deleting will permanently remove this task/medication.")
            }
        }
    }
}

// MARK: - Header (same as Hub)
private extension TasksTabView {
    var header: some View {
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

            Text("Tasks")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
        }
        .confirmationDialog("Menu", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Settings") { showSettings = true }
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tasks header")
    }
}

// MARK: - Cards
private extension TasksTabView {

    var tasksCard: some View {
        CardDark {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primary)
                    Text("Tasks")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(todayEvents.prefix(4)) { task in
                    eventRow(task)
                }
            }
            .padding(.top, 6)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                createPrefillKind = .event
                showCreateSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("Add task")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(AppTheme.surface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
        }
        .appCardStyle()
    }

    func eventRow(_ task: TaskItem) -> some View {
        let time = task.scheduledAt?.formatted(.dateTime.hour().minute()) ?? ""

        return Button {
            toggleDone(task)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? AppTheme.success : AppTheme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitleDateString)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text(time)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                if let url = task.audioURL {
                    playPill(
                        isPlaying: (playingTaskURL == url && taskAudioPlayer.isPlaying),
                        title: nil
                    ) {
                        togglePlay(url: url)
                    }
                }

                Button(role: .destructive) {
                    taskToDelete = task
                    showFirstDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(AppTheme.stroke),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }

    var medicationCard: some View {
        CardDark {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "pill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primary)
                    Text("Medication")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()

                Button {
                    showMedicineInventory = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Cabinet", systemImage: "cross.case.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your medicine inventory")
            }

            Button {
                showMedicineInventory = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: medicineInventoryStatus.icon)
                        .font(.headline)
                        .foregroundStyle(medicineInventoryStatus.color)
                        .frame(width: 36, height: 36)
                        .background(medicineInventoryStatus.color.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(medicineInventoryStatus.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(medicineInventoryStatus.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
                .background(AppTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Medicine cabinet, \(medicineInventoryStatus.subtitle)")

            if todayMedications.isEmpty {
                Text("No medication for this day.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 10)
            } else {
                VStack(spacing: 10) {
                    ForEach(todayMedications) { med in
                        HStack(spacing: 12) {
                            Image(systemName: med.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(med.isDone ? AppTheme.success : AppTheme.warning)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(med.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(subtitleDateString)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            Text(med.scheduledAt?.formatted(.dateTime.hour().minute()) ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            Button(role: .destructive) {
                                taskToDelete = med
                                showFirstDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(AppTheme.stroke),
                            alignment: .bottom
                        )
                    }
                }
                .padding(.top, 6)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                createPrefillKind = .medication
                showCreateSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("Add medication")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(AppTheme.surface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
        }
        .appCardStyle()
    }

    var medicineInventoryStatus: (title: String, subtitle: String, icon: String, color: Color) {
        let expired = state.medicineInventory.filter { $0.expiryState() == .expired }.count
        let expiring = state.medicineInventory.filter { $0.expiryState() == .expiringSoon }.count
        let lowStock = state.medicineInventory.filter(\.isLowStock).count

        if state.medicineInventory.isEmpty {
            return ("Medicine cabinet", "Add what you have at home", "cross.case.fill", AppTheme.primary)
        }
        if expired > 0 {
            return ("Check your cabinet", "\(expired) expired · \(lowStock) low stock", "exclamationmark.triangle.fill", AppTheme.danger)
        }
        if expiring > 0 || lowStock > 0 {
            return ("Cabinet needs attention", "\(expiring) expiring · \(lowStock) low stock", "exclamationmark.triangle.fill", AppTheme.warning)
        }
        return ("Cabinet is up to date", "\(state.medicineInventory.count) medicines recorded", "checkmark.circle.fill", AppTheme.success)
    }

    var calendarCard: some View {
        CardDark {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primary)
                Text("Calendar")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDate.formatted(.dateTime.weekday()))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(selectedDate.formatted(.dateTime.month()))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(selectedDate.formatted(.dateTime.day()))
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Button {
                        selectedDate = Date()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                            Text("Today")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Spacer()

                MonthMiniCalendar(selectedDate: $selectedDate)
                    .frame(width: 210)
            }
        }
        .appCardStyle()
    }

    var addNewTaskButton: some View {
        Button {
            createPrefillKind = .event
            showCreateSheet = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.primary)
                    .clipShape(Circle())

                Text("Add a new task")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppTheme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 27)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 0)
        .padding(.bottom, 8)
    }

    func playPill(isPlaying: Bool, title: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(iconColor)
                        .padding(.leading, isPlaying ? 0 : 1)
                }
                if let title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, title == nil ? 8 : 12)
            .frame(height: 34)
            .background(iconColor)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.06), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mutations
private extension TasksTabView {
    func toggleDone(_ task: TaskItem) {
        guard let idx = state.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        state.tasks[idx].isDone.toggle()
        state.tasks[idx].updatedAt = .now
        state.saveTasks()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func togglePlay(url: URL) {
        if playingTaskURL == url && taskAudioPlayer.isPlaying {
            taskAudioPlayer.stop()
            playingTaskURL = nil
        } else {
            taskAudioPlayer.stop()
            taskAudioPlayer.play(url: url)
            playingTaskURL = url
        }
    }
}

// MARK: - Create Task Sheet
private struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var state: AppState

    let selectedDate: Date
    let prefillKind: TaskKind

    @State private var kind: TaskKind
    @State private var title: String = ""
    @State private var eventDateTime: Date

    @State private var reminderEnabled: Bool = true
    @State private var reminderOffset: ReminderOffset = .five

    @Environment(\.colorScheme) private var scheme
    private var textPrimary: Color { AppTheme.textPrimary }
    private var textSecondary: Color { AppTheme.textSecondary }
    private var controlBackground: Color { AppTheme.surface2 }
    private var controlBorder: Color { AppTheme.stroke }
    private var emphasisBackground: Color { AppTheme.primary }
    private var emphasisForeground: Color { AppTheme.textOnSurfacePrimary }

    init(state: AppState, selectedDate: Date, prefillKind: TaskKind) {
        self.state = state
        self.selectedDate = selectedDate
        self.prefillKind = prefillKind

        _kind = State(initialValue: prefillKind)
        _eventDateTime = State(initialValue: selectedDate)
    }

    private var canConfirm: Bool { Validators.nonEmpty(title) }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    CardDark {
                        HStack(spacing: 10) {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(AppTheme.primary)
                            Text("Create a new task")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                        }

                        VStack(spacing: 12) {
                            label("Tipology")
                            Menu {
                                Button("Tasks") { kind = .event }
                                Button("Medication") { kind = .medication }
                            } label: {
                                HStack {
                                    Text(kind == .event ? "Tasks" : "Medication")
                                        .foregroundStyle(textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundStyle(textSecondary)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(controlBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(controlBorder, lineWidth: 1)
                                )
                            }
                            .tint(AppTheme.primary)

                            label("Title")
                            TextField("Title", text: $title)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(controlBackground)
                                .foregroundStyle(textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(controlBorder, lineWidth: 1)
                                )
                                .submitLabel(.done)

                            label("Date & time")
                            DatePicker("", selection: $eventDateTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .tint(AppTheme.primary)

                            label("Reminder")
                            VStack(spacing: 10) {
                                HStack {
                                    Toggle("", isOn: $reminderEnabled)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                    Spacer()
                                    Text(reminderEnabled ? "On" : "Off")
                                        .foregroundStyle(reminderEnabled ? textPrimary.opacity(0.85) : textSecondary)
                                }

                                if reminderEnabled {
                                    HStack {
                                        Text("Before")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(textSecondary)
                                        Spacer()
                                        Menu {
                                            ForEach(ReminderOffset.allCases) { opt in
                                                Button(opt.title) { reminderOffset = opt }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(reminderOffset.title)
                                                    .foregroundStyle(textPrimary)
                                                Image(systemName: "chevron.down")
                                                    .foregroundStyle(textSecondary)
                                            }
                                            .padding(.horizontal, 12)
                                            .frame(height: 36)
                                            .background(controlBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(controlBorder, lineWidth: 1)
                                            )
                                        }
                                        .tint(AppTheme.primary)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(controlBackground.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(controlBorder, lineWidth: 1)
                            )

                            HStack(spacing: 12) {
                                Button { dismiss() } label: {
                                    Text("Cancel")
                                        .font(.headline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(controlBackground)
                                        .foregroundStyle(textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(controlBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)

                                Button { confirm() } label: {
                                    Text("Confirm")
                                        .font(.headline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(emphasisBackground)
                                        .foregroundStyle(emphasisForeground)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .opacity(canConfirm ? 1 : 0.45)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canConfirm)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .appCardStyle()
                }
                .padding()
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .onTapGesture { dismissKeyboard() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
    }

    private func label(_ t: String) -> some View {
        HStack {
            Text(t)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textSecondary)
            Spacer()
        }
    }

    private func confirm() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let scheduled = eventDateTime
        let notifId: String? = reminderEnabled ? "task_\(UUID().uuidString)" : nil

        let newItem = TaskItem(
            title: trimmed,
            createdAt: .now,
            isDone: false,
            scheduledAt: scheduled,
            notificationId: notifId,
            kind: kind,
            notes: nil
        )

        state.tasks.insert(newItem, at: 0)
        state.saveTasks()

        if let notifId, reminderEnabled {
            NotificationManager.scheduleCallReminder(
                id: notifId,
                title: trimmed,
                phone: nil,
                date: scheduled,
                offset: reminderOffset
            )
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

// MARK: - Mini month calendar
private struct MonthMiniCalendar: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selectedDate: Date
    private var calendar: Calendar { .current }

    private var monthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: selectedDate)
        return calendar.date(from: comps) ?? selectedDate
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        let first = calendar.firstWeekday
        return (weekday - first + 7) % 7
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.black.opacity(0.75))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthStart.formatted(.dateTime.month()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black)

                Spacer()

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.black.opacity(0.75))
                }
                .buttonStyle(.plain)
            }

            let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: cols, spacing: 6) {
                let totalCells = firstWeekdayOffset + daysInMonth

                ForEach(0..<totalCells, id: \.self) { index in
                    if index < firstWeekdayOffset {
                        Color.clear.frame(height: 22)
                    } else {
                        let day = index - firstWeekdayOffset + 1
                        let date = dateForDay(day)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

                        Button {
                            selectedDate = date
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("\(day)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.black : Color.black.opacity(0.85))
                                .frame(width: 26, height: 22)
                                .background(isSelected ? Color(red: 0.953, green: 0.957, blue: 0.965) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func dateForDay(_ day: Int) -> Date {
        calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? selectedDate
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthStart) {
            let day = calendar.component(.day, from: selectedDate)
            let comps = calendar.dateComponents([.year, .month], from: d)
            let candidate = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: min(day, 28))) ?? d
            selectedDate = candidate
        }
    }
}
