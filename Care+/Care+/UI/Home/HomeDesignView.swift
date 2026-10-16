import SwiftUI
import UIKit

struct HomeDesignView: View {

    @Bindable var state: AppState
    @Binding var selectedTab: AppTab

    // Listen voice
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var playingURL: URL?

    // Sheets / Menu
    @State private var showMedicalReport = false

    #if DEBUG
    @State private var showAddCall = false
    #endif

    // Insights UI
    @State private var insightsPeriod: InsightsPeriod = .today
    @State private var showAllRoutine = false

    // MARK: - Data helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let name = (state.careDataOwnerName ?? state.currentUser?.name)?
            .split(separator: " ").first.map(String.init)
        return name.map { "\(part), \($0)" } ?? part
    }

    private var daySummary: String {
        let left = todayTimelineItems.filter { !$0.isDone }.count
        switch left {
        case 0: return todayTimelineItems.isEmpty ? "Nothing planned for today." : "All done for today. Well done!"
        case 1: return "1 activity left today."
        default: return "\(left) activities left today."
        }
    }

    private var dayBounds: (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? .now
        return (start, end)
    }

    private var todayScheduledTasks: [TaskItem] {
        let (start, end) = dayBounds
        return state.tasks
            .filter {
                guard let d = $0.scheduledAt else { return false }
                return d >= start && d < end
            }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    private var todayMedications: [TaskItem] {
        todayScheduledTasks.filter { $0.kind == .medication }
    }

    private var todayTimelineItems: [TaskItem] {
        todayScheduledTasks
            .filter { $0.kind == .event || $0.kind == .medication }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    private var medicationTask: TaskItem? {
        todayMedications.first(where: { !$0.isDone })
    }

    private var voiceContacts: [ContactItem] {
        state.contacts
            .filter { $0.audioNoteURL != nil }
            .prefix(2)
            .map { $0 }
    }

    private var gamesDoneToday: Int {
        min(3, state.gameSessions(on: .now).count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        TabHeader(state: state, title: "Hub", onChat: { selectedTab = .chat }) {
                            Button("Medical report") { showMedicalReport = true }
                            #if DEBUG
                            Button("Log a Call") { showAddCall = true }
                            #endif
                        }

                        calendarCard

                        HStack(spacing: 14) {
                            medicationCard
                            listenVoiceCard
                        }

                        eventsCard

                        // Calls statistics preview card (same style as Routine)
                        callsStatsCard

                        // NEW: Insights (Routine + Medication + Voice)
                        insightsCard

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                audioPlayer.onFinish = { playingURL = nil }
            }
        }
        .sheet(isPresented: $showMedicalReport) {
            MedicalReportView(state: state)
        }

        #if DEBUG
        .sheet(isPresented: $showAddCall) {
            AddCallView(state: state)
        }
        #endif
    }
}

// MARK: - Calendar card
private extension HomeDesignView {
    var calendarCard: some View {
        Group {
            CardDark {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)

                            Text("Calendar")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Spacer()
                        }

                        Text(Date.now.formatted(.dateTime.weekday().month().day()))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(daySummary)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()
                }
            }
            .appCardStyle()
        }
        .background(AppTheme.background)
    }
}

// MARK: - Medication card
private extension HomeDesignView {
    var medicationCard: some View {
        Group {
            CardDark {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "pill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(AppTheme.primary)
                        Text("Medication")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }

                    if let med = medicationTask {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text((med.scheduledAt?.formatted(.dateTime.hour().minute())) ?? "Anytime")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .opacity(med.isDone ? 0.6 : 1.0)

                        Spacer(minLength: 0)

                        Button {
                            if let idx = state.tasks.firstIndex(where: { $0.id == med.id }) {
                                state.tasks[idx].isDone.toggle()
                                state.tasks[idx].updatedAt = .now

                                // Track completion timestamp (used for On time / Delayed)
                                if state.tasks[idx].isDone {
                                    setTaskCompletionDate(taskID: med.id, date: .now)
                                } else {
                                    setTaskCompletionDate(taskID: med.id, date: nil)
                                }

                                state.saveTasks()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Text(med.isDone ? "Taken" : "Not taken")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(AppPillButtonStyle(role: med.isDone ? .primary : .warning))

                    } else {
                        Text("No medication for today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 150)
            }
            .appCardStyle()
        }
    }
}

// MARK: - Listen voice card
private extension HomeDesignView {
    var listenVoiceCard: some View {
        Group {
            CardDark {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primary)
                        Text("Voices")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }

                    if voiceContacts.isEmpty {
                        Text("Record a loved one's voice from Contacts.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(voiceContacts) { c in
                                voicePill(contact: c)
                            }
                        }
                        .padding(.top, 2)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 150)
            }
            .appCardStyle()
        }
    }

    func voicePill(contact: ContactItem) -> some View {
        Button {
            guard let url = contact.audioNoteURL else { return }

            if playingURL == url {
                audioPlayer.stop()
                playingURL = nil
            } else {
                audioPlayer.stop()
                audioPlayer.play(url: url)
                playingURL = url

                // Track Voice Interaction event (user-initiated, observational)
                logVoicePlay(contactKey: contact.uniqueKey, date: .now)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: (playingURL == contact.audioNoteURL) ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.primary)
                    .clipShape(Circle())

                Text(contact.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if playingURL == contact.audioNoteURL {
                    Button {
                        audioPlayer.stop()
                        playingURL = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
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

// MARK: - Events card (Routine)
private extension HomeDesignView {
    var eventsCard: some View {
        Group {
            CardDark {
                VStack(spacing: 10) {
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "list.bullet")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                            Text("Today")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Spacer()
                    }

                    if todayTimelineItems.isEmpty {
                        Text("No activities for today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(showAllRoutine ? todayTimelineItems : Array(todayTimelineItems.prefix(3))) { e in
                                timelineRow(task: e)
                            }
                        }
                        .padding(.top, 10)

                        if todayTimelineItems.count > 3 {
                        Button {
                            withAnimation(.snappy) { showAllRoutine.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showAllRoutine ? "Show less" : "Show all \(todayTimelineItems.count)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)
                                Image(systemName: showAllRoutine ? "chevron.up" : "chevron.down")
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
                    }
                }
            }
            .appCardStyle()
        }
    }

    func timelineRow(task: TaskItem) -> some View {
        let time = task.scheduledAt?.formatted(.dateTime.hour().minute()) ?? ""
        let isDone = task.isDone
        let kindIcon = task.kind == .medication ? "pill" : "calendar"

        return HStack(spacing: 10) {
            Button {
                if let idx = state.tasks.firstIndex(where: { $0.id == task.id }) {
                    state.tasks[idx].isDone.toggle()
                    state.tasks[idx].updatedAt = .now

                    // Track completion timestamp (used for On time / Delayed)
                    if state.tasks[idx].isDone {
                        setTaskCompletionDate(taskID: task.id, date: .now)
                    } else {
                        setTaskCompletionDate(taskID: task.id, date: nil)
                    }

                    state.saveTasks()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? AppTheme.primary : AppTheme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: kindIcon)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(time)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .opacity(isDone ? 0.55 : 1.0)
        .padding(.vertical, 8)
        .background(
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(AppTheme.stroke)
                    .frame(height: 1)
            }
        )
    }
}

// MARK: - Calls stats card (preview like Routine)
private extension HomeDesignView {
    var callsStatsCard: some View {
        Group {
            CardDark {
                VStack(spacing: 10) {
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)

                            Text("Calls")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedTab = .contacts
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(AppTheme.surface2)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(AppTheme.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                    }

                    let todayTotal = state.callsPerDayLastNDays(days: 1, now: .now).first?.count ?? 0
                    let daily = state.dailyCallsBreakdown(on: .now)

                    if todayTotal == 0 || daily.isEmpty {
                        Text("No calls tracked today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    } else {
                        HStack(spacing: 8) {
                            Text("Today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(todayTotal == 1 ? "1 call" : "\(todayTotal) calls")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Spacer()

                            let lastAny = daily.compactMap { $0.last }.max()
                            Text("Last \(lastAny?.formatted(.dateTime.hour().minute()) ?? "—")")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 6)

                        VStack(spacing: 10) {
                            ForEach(Array(daily.sorted { $0.count > $1.count }.prefix(2)), id: \.contactKey) { row in
                                callStatRow(row: row)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .appCardStyle()
        }
    }

    @ViewBuilder
    func callStatRow(row: (contactKey: String, count: Int, last: Date?)) -> some View {
        let contact = state.contacts.first(where: { $0.uniqueKey == row.contactKey })
        let name = contact?.name ?? row.contactKey
        let role = (contact?.relation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lastText = row.last?.formatted(.dateTime.hour().minute()) ?? "—"

        HStack(spacing: 10) {
            Image(systemName: "phone.circle.fill")
                .foregroundStyle(AppTheme.primary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                if !role.isEmpty {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Last: \(lastText)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(row.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("today")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .background(
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(AppTheme.stroke)
                    .frame(height: 1)
            }
        )
    }
}

// MARK: - Insights (NEW)
private extension HomeDesignView {

    enum InsightsPeriod: String, CaseIterable, Identifiable {
        case today = "Today"
        case last7 = "7d"
        case last30 = "30d"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .today: return 1
            case .last7: return 7
            case .last30: return 30
            }
        }
    }

    // --- Models (simple, Apple-safe, observational)

    struct PercentageMetric {
        let value: Int
        let avg: Int?
        let trendDelta: Int?
    }

    struct MedicationMetric {
        let adherence: Int
        let onTime: Int
        let delayed: Int
        let missed: Int
    }

    struct VoiceMetric {
        let plays: Int
        let uniqueVoices: Int
        let repeatedSameVoice: Int
        let peakTimeRange: String
    }

    var insightsCard: some View {
        Group {
            CardDark {
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)

                            Text("Insights")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Spacer()

                        Picker("", selection: $insightsPeriod) {
                            ForEach(InsightsPeriod.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 240)
                    }

                    let routine = computeRoutineCompletion(period: insightsPeriod)
                    let meds = computeMedicationAdherence(period: insightsPeriod)
                    let voice = computeVoiceInteractions(period: insightsPeriod)

                    insightRowRoutine(metric: routine)
                    DividerLine()
                    insightRowMedication(metric: meds)
                    DividerLine()
                    insightRowVoice(metric: voice)
                }
            }
            .appCardStyle()
        }
    }

    // MARK: UI rows

    @ViewBuilder
    func insightRowRoutine(metric: PercentageMetric) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Routine Completion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 10) {
                    if let avg = metric.avg {
                        Text("Avg \(avg)%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if let d = metric.trendDelta {
                        Text(trendText(delta: d))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(d < 0 ? AppTheme.warning : AppTheme.textSecondary)
                    }
                }
            }

            Spacer()

            Text("\(metric.value)%")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func insightRowMedication(metric: MedicationMetric) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "pill.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Medication Adherence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("On time \(metric.onTime)% · Delayed \(metric.delayed)% · Missed \(metric.missed)%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text("\(metric.adherence)%")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func insightRowVoice(metric: VoiceMetric) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Voice Interactions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(metric.plays) plays · \(metric.uniqueVoices) voices · Peak \(metric.peakTimeRange)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text("\(metric.repeatedSameVoice)")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("repeat")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    struct DividerLine: View {
        var body: some View {
            Rectangle()
                .fill(AppTheme.stroke)
                .frame(height: 1)
                .opacity(0.85)
        }
    }

    // MARK: Computations

    /// Share (0–100) of tasks scheduled in [from, to) that are completed.
    func completionRate(from: Date, to: Date) -> Int {
        let items = state.tasks.filter { $0.scheduledAt.map { $0 >= from && $0 < to } ?? false }
        guard !items.isEmpty else { return 0 }
        return items.filter(\.isDone).count * 100 / items.count
    }

    func dayStart(_ offset: Int) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now)) ?? .now
    }

    func computeRoutineCompletion(period: InsightsPeriod) -> PercentageMetric {
        let tomorrow = dayStart(1)
        let value = completionRate(from: dayStart(-(period.days - 1)), to: tomorrow)
        let last7 = completionRate(from: dayStart(-6), to: tomorrow)
        let previous7 = completionRate(from: dayStart(-13), to: dayStart(-6))

        return .init(
            value: value,
            avg: period == .today ? last7 : nil,
            trendDelta: period.days <= 7 ? last7 - previous7 : nil
        )
    }

    func computeMedicationAdherence(period: InsightsPeriod) -> MedicationMetric {
        let days = period.days
        let cal = Calendar.current
        let now = Date.now
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: now)) ?? now

        // Doses that are due by now, plus any taken early.
        let meds = state.tasks.filter { t in
            guard let d = t.scheduledAt, t.kind == .medication, d >= start else { return false }
            return d <= now || t.isDone
        }

        let scheduled = meds.count
        let taken = meds.filter(\.isDone).count
        let adherence = Int((Double(taken) / Double(max(scheduled, 1))) * 100.0)

        // Breakdown (observational):
        // - On time: completed within tolerance of scheduled time
        // - Delayed: completed after tolerance
        // - Missed: not done and scheduled time passed
        let toleranceMinutes = 30

        var onTimeCount = 0
        var delayedCount = 0
        var missedCount = 0

        for m in meds {
            guard let scheduledAt = m.scheduledAt else { continue }
            if m.isDone {
                let completedAt = getTaskCompletionDate(taskID: m.id) ?? now
                let tolerance = Calendar.current.date(byAdding: .minute, value: toleranceMinutes, to: scheduledAt) ?? scheduledAt
                if completedAt <= tolerance { onTimeCount += 1 } else { delayedCount += 1 }
            } else {
                if scheduledAt <= now { missedCount += 1 }
            }
        }

        // Convert to % over scheduled doses
        func pct(_ x: Int) -> Int {
            Int((Double(x) / Double(max(scheduled, 1))) * 100.0)
        }

        return .init(
            adherence: adherence,
            onTime: pct(onTimeCount),
            delayed: pct(delayedCount),
            missed: pct(missedCount)
        )
    }

    func computeVoiceInteractions(period: InsightsPeriod) -> VoiceMetric {
        let days = period.days
        let cal = Calendar.current
        let now = Date.now
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: now)) ?? now

        let events = loadVoiceEvents()
            .filter { $0.date >= start && $0.date <= now }

        let plays = events.count
        let unique = Set(events.map(\.contactKey)).count

        // repeatedSameVoice: max plays for a single voice (matches your example)
        let grouped = Dictionary(grouping: events, by: \.contactKey)
        let maxForOne = grouped.values.map { $0.count }.max() ?? 0

        // Peak time: 3-hour bucket like "18:00–21:00"
        let peak = peakTimeRange3h(events: events)

        return .init(
            plays: plays,
            uniqueVoices: unique,
            repeatedSameVoice: maxForOne,
            peakTimeRange: peak
        )
    }

    func peakTimeRange3h(events: [VoicePlayEvent]) -> String {
        guard !events.isEmpty else { return "—" }
        let cal = Calendar.current
        let buckets = events.reduce(into: [Int: Int]()) { acc, e in
            let hour = cal.component(.hour, from: e.date)
            let bucket = (hour / 3) * 3
            acc[bucket, default: 0] += 1
        }
        let best = buckets.max { $0.value < $1.value }?.key ?? 0
        let start = best
        let end = min(best + 3, 24)
        return String(format: "%02d:00–%02d:00", start, end)
    }

    func trendText(delta: Int) -> String {
        if delta == 0 { return "→ 0%" }
        if delta > 0 { return "↑ \(delta)%" }
        return "↓ \(abs(delta))%"
    }
}

// MARK: - Persistence helpers (Voice + Task completion timestamps)
private extension HomeDesignView {

    // --- Task completion timestamps (for medication On time / Delayed)
    func completionKey(taskID: UUID) -> String { "task_completion_\(taskID.uuidString)" }

    func setTaskCompletionDate(taskID: UUID, date: Date?) {
        let key = completionKey(taskID: taskID)
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func getTaskCompletionDate(taskID: UUID) -> Date? {
        let key = completionKey(taskID: taskID)
        let ts = UserDefaults.standard.double(forKey: key)
        if ts == 0 { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // --- Voice events (observational, user-initiated)
    struct VoicePlayEvent: Codable, Hashable {
        let contactKey: String
        let date: Date
    }

    var voiceEventsKey: String {
        // If you have a user id in state, use it. Otherwise keep single bucket.
        // You can swap this to state.currentUser?.id later.
        "voice_play_events_v1"
    }

    func logVoicePlay(contactKey: String, date: Date) {
        var events = loadVoiceEvents()
        events.append(.init(contactKey: contactKey, date: date))

        // Keep it light: keep last 2000 events
        if events.count > 2000 { events = Array(events.suffix(2000)) }

        saveVoiceEvents(events)
    }

    func loadVoiceEvents() -> [VoicePlayEvent] {
        guard let data = UserDefaults.standard.data(forKey: voiceEventsKey) else { return [] }
        do {
            return try JSONDecoder().decode([VoicePlayEvent].self, from: data)
        } catch {
            return []
        }
    }

    func saveVoiceEvents(_ events: [VoicePlayEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: voiceEventsKey)
        } catch {
            // no-op (keep it safe)
        }
    }
}

// MARK: - Small helpers
private extension HomeDesignView {
}
