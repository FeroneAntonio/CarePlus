//
//  AppState.swift
//  Care+
//
//  App global state + persistence
//

import Foundation
import Observation
import UIKit
import Supabase

@MainActor
@Observable
final class AppState {

    // MARK: - Stored state
    var tasks: [TaskItem] = []
    var diary: [DiaryEntry] = []
    var contacts: [ContactItem] = []
    var callEvents: [CallEvent] = []              // outgoing call log (from app)
    var gameResults: [GameSessionResult] = []     // all game sessions

    var currentUser: UserProfile?
    var isGuest: Bool = false

    var sessionUserId: String?
    /// Patient whose care data is currently displayed. For a patient this is their own id;
    /// for a caregiver it is the id from the active care link.
    var careDataOwnerId: String?
    var careDataOwnerName: String?
    var careLinkStatus: String?

    var userRole: String?
    var profileStatus: String? = nil
    var needsSetupWizard: Bool {
        (userRole != nil) && ((profileStatus ?? "pending").lowercased() != "active")
    }

    var isProfileReady: Bool = false
    var selectedLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool = false
    private let onboardingKey = "onboarding_done_v1"

    var hasSeenEducation: Bool = false
    private let educationKey = "education_seen_v1"

    var calmingRemindersEnabled: Bool = false
    var calmingIntervalMinutes: Int = 20
    var hasImportedDeviceContacts: Bool = false

    // MARK: - SOS State
    var sosContactID: UUID?
    private let sosKey = "sos_contact_id_v1"

    // MARK: - Keys
    private let userKey = "user_profile_v5"
    private let userRoleKey = "user_role_v1"
    private let profileReadyKey = "profile_ready_v1"
    private let contactsKey = "contacts_v1"
    private let callsKey = "call_events_v1"
    private let gamesKey = "game_results_v1"
    private let tasksKey = "tasks_v1"
    private let diaryKey = "diary_v1"
    private let calmingEnabledKey = "calming_enabled_v1"
    private let calmingIntervalKey = "calming_interval_v1"
    private let contactsImportedKey = "contacts_imported_v1"
    private let languageKey = "app_language_code_v1"
    private let profileStatusKey = "profile_status_v1"
    private let guestKey = "guest_mode_v1"

    // MARK: - Lifecycle
    func load() {
        // User
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            currentUser = user
        }
        if let role = UserDefaults.standard.string(forKey: userRoleKey) {
            userRole = role
        }
        if let status = UserDefaults.standard.string(forKey: profileStatusKey) {
            profileStatus = status
        }
        isProfileReady = UserDefaults.standard.bool(forKey: profileReadyKey)
        isGuest = UserDefaults.standard.bool(forKey: guestKey)

        // Feature data
        contacts = Persistence.load([ContactItem].self, key: contactsKey, defaultValue: [])
        callEvents = Persistence.load([CallEvent].self, key: callsKey, defaultValue: [])
        gameResults = Persistence.load([GameSessionResult].self, key: gamesKey, defaultValue: [])

        // tasks/diary: non carico global qui, verranno caricati per-user o lasciati vuoti
        tasks = []
        diary = []

        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        hasSeenEducation = UserDefaults.standard.bool(forKey: educationKey)
        calmingRemindersEnabled = UserDefaults.standard.bool(forKey: calmingEnabledKey)

        let savedInterval = UserDefaults.standard.integer(forKey: calmingIntervalKey)
        if savedInterval > 0 { calmingIntervalMinutes = savedInterval }

        // SOS
        if let idString = UserDefaults.standard.string(forKey: sosKey) {
            sosContactID = UUID(uuidString: idString)
        }

        hasImportedDeviceContacts = UserDefaults.standard.bool(forKey: contactsImportedKey)
        if let code = UserDefaults.standard.string(forKey: languageKey) {
            selectedLanguageCode = code
        }
    }

    // MARK: - Load user-scoped data
    func loadUserData(_ userId: String) {
        migrateLegacyDataIfNeeded(to: userId)

        let c: [ContactItem] = Persistence.load([ContactItem].self, key: contactsKey, userId: userId, defaultValue: [])
        let calls: [CallEvent] = Persistence.load([CallEvent].self, key: callsKey, userId: userId, defaultValue: [])
        let games: [GameSessionResult] = Persistence.load([GameSessionResult].self, key: gamesKey, userId: userId, defaultValue: [])
        self.contacts = c
        self.callEvents = calls
        self.gameResults = games
        let scopedSOSKey = Persistence.scopedKey(key: sosKey, userId: userId)
        sosContactID = UserDefaults.standard.string(forKey: scopedSOSKey).flatMap(UUID.init(uuidString:))
        let scopedImportKey = Persistence.scopedKey(key: contactsImportedKey, userId: userId)
        hasImportedDeviceContacts = UserDefaults.standard.bool(forKey: scopedImportKey)
        loadCareData(userId)
    }

    private func loadCareData(_ ownerId: String) {
        careDataOwnerId = ownerId
        tasks = Persistence.load([TaskItem].self, key: tasksKey, userId: ownerId, defaultValue: [])
        diary = Persistence.load([DiaryEntry].self, key: diaryKey, userId: ownerId, defaultValue: [])
    }

    private func configureCareDataOwner() async {
        guard let sessionUserId else { return }
        guard userRole?.lowercased() == "caregiver" else {
            if userRole?.lowercased() == "patient" {
                let links = try? await CareLinksService.shared.fetchCaregivers(forPatientId: sessionUserId)
                careLinkStatus = links?.first?.status
            } else {
                careLinkStatus = nil
            }
            careDataOwnerName = currentUser?.name
            loadCareData(sessionUserId)
            return
        }

        let links = try? await CareLinksService.shared.fetchPatients(forCaregiverId: sessionUserId)
        let activeLink = links?.first(where: { $0.status.lowercased() == "active" })
        careLinkStatus = activeLink?.status ?? links?.first?.status
        let patientId = activeLink?.patient_id
        if let patientId = patientId {
            let profile = try? await ProfilesService.shared.fetchProfile(id: patientId)
            careDataOwnerName = profile?.display_name
        } else {
            careDataOwnerName = nil
        }
        loadCareData(patientId ?? sessionUserId)
    }

    private func migrateLegacyDataIfNeeded(to userId: String) {
        let migrationKey = "legacy_data_migrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let legacyTasks: [TaskItem] = Persistence.load([TaskItem].self, key: tasksKey, defaultValue: [])
        let legacyDiary: [DiaryEntry] = Persistence.load([DiaryEntry].self, key: diaryKey, defaultValue: [])
        let legacyContacts: [ContactItem] = Persistence.load([ContactItem].self, key: contactsKey, defaultValue: [])
        let legacyCalls: [CallEvent] = Persistence.load([CallEvent].self, key: callsKey, defaultValue: [])
        let legacyGames: [GameSessionResult] = Persistence.load([GameSessionResult].self, key: gamesKey, defaultValue: [])

        if !legacyTasks.isEmpty { Persistence.save(legacyTasks, key: tasksKey, userId: userId) }
        if !legacyDiary.isEmpty { Persistence.save(legacyDiary, key: diaryKey, userId: userId) }
        if !legacyContacts.isEmpty { Persistence.save(legacyContacts, key: contactsKey, userId: userId) }
        if !legacyCalls.isEmpty { Persistence.save(legacyCalls, key: callsKey, userId: userId) }
        if !legacyGames.isEmpty { Persistence.save(legacyGames, key: gamesKey, userId: userId) }
        if let legacySOS = UserDefaults.standard.string(forKey: sosKey) {
            UserDefaults.standard.set(
                legacySOS,
                forKey: Persistence.scopedKey(key: sosKey, userId: userId)
            )
        }
        if UserDefaults.standard.bool(forKey: contactsImportedKey) {
            UserDefaults.standard.set(
                true,
                forKey: Persistence.scopedKey(key: contactsImportedKey, userId: userId)
            )
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - SOS Management
    var sosContact: ContactItem? {
        contacts.first { $0.id == sosContactID } ?? contacts.first
    }

    func setSOSContact(_ contact: ContactItem) {
        sosContactID = contact.id
        let scope = sessionUserId ?? (isGuest ? "guest" : nil)
        let key = scope.map { Persistence.scopedKey(key: sosKey, userId: $0) } ?? sosKey
        UserDefaults.standard.set(contact.id.uuidString, forKey: key)
    }

    // MARK: - Save helpers
    func saveUser() {
        guard let user = currentUser,
              let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userKey)
    }

    func saveUserRole(_ role: String?) {
        userRole = role
        if let role {
            UserDefaults.standard.set(role, forKey: userRoleKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userRoleKey)
        }
    }

    func saveProfileStatus(_ status: String?) {
        profileStatus = status
        if let status {
            UserDefaults.standard.set(status, forKey: profileStatusKey)
        } else {
            UserDefaults.standard.removeObject(forKey: profileStatusKey)
        }
    }

    func saveProfileReady(_ ready: Bool) {
        isProfileReady = ready
        UserDefaults.standard.set(ready, forKey: profileReadyKey)
    }

    func saveContacts() { saveScoped(contacts, key: contactsKey) }
    func saveCalls() { saveScoped(callEvents, key: callsKey) }
    func saveGames() { saveScoped(gameResults, key: gamesKey) }

    private func saveScoped<T: Encodable>(_ value: T, key: String) {
        if let uid = sessionUserId {
            Persistence.save(value, key: key, userId: uid)
        } else if isGuest {
            Persistence.save(value, key: key, userId: "guest")
        } else {
            Persistence.save(value, key: key)
        }
    }

    func saveTasks() {
        if let ownerId = careDataOwnerId ?? sessionUserId {
            Persistence.save(tasks, key: tasksKey, userId: ownerId)
            SyncEngine.schedulePush(state: self)
        } else {
            Persistence.save(tasks, key: tasksKey)
        }
    }

    func saveDiary() {
        if let ownerId = careDataOwnerId ?? sessionUserId {
            Persistence.save(diary, key: diaryKey, userId: ownerId)
            SyncEngine.schedulePush(state: self)
        } else {
            Persistence.save(diary, key: diaryKey)
        }
    }

    func setOnboardingCompleted() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    func setEducationSeen() {
        hasSeenEducation = true
        UserDefaults.standard.set(true, forKey: educationKey)
    }

    func setContactsImported() {
        hasImportedDeviceContacts = true
        let scope = sessionUserId ?? (isGuest ? "guest" : nil)
        let key = scope.map { Persistence.scopedKey(key: contactsImportedKey, userId: $0) } ?? contactsImportedKey
        UserDefaults.standard.set(true, forKey: key)
    }

    func setCalmingReminders(enabled: Bool) {
        calmingRemindersEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: calmingEnabledKey)
    }

    func setCalmingInterval(minutes: Int) {
        calmingIntervalMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: calmingIntervalKey)
    }

    func setLanguage(code: String) {
        selectedLanguageCode = code
        UserDefaults.standard.set(code, forKey: languageKey)
    }

    func setGuest(_ enabled: Bool) {
        isGuest = enabled
        UserDefaults.standard.set(enabled, forKey: guestKey)
        if enabled {
            loadUserData("guest")
        }
    }

    // MARK: - Auth (server gating)
    func refreshProfileFromSupabase() async {
        do {
            guard let _ = await AuthService.shared.currentSession() else {
                self.currentUser = nil
                self.saveProfileReady(false)
                self.saveUserRole(nil)
                self.saveProfileStatus(nil)
                return
            }

            let fetchedProfile = try await ProfilesService.shared.fetchProfile()
            if let profile = fetchedProfile {
                self.saveProfileStatus(profile.status)

                self.saveUserRole(profile.role)
                self.saveProfileReady(profile.status.lowercased() == "active")

                if let displayName = profile.display_name, !displayName.isEmpty {
                    let existing = self.currentUser
                    self.currentUser = UserProfile(
                        id: existing?.id ?? UUID(),
                        name: displayName,
                        phone: existing?.phone ?? "",
                        email: profile.email ?? existing?.email ?? "",
                        provider: existing?.provider ?? "email"
                    )
                    self.saveUser()
                }
                await self.configureCareDataOwner()
            } else {
                self.saveProfileReady(false)
                self.saveUserRole(nil)
                self.saveProfileStatus(nil)
            }
        } catch {
            print("refreshProfileFromSupabase error: \(error)")
            self.saveProfileReady(false)
            self.saveProfileStatus(nil)
        }
    }

    func logout() async {
        try? await AuthService.shared.signOut()
        setGuest(false)

        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        sessionUserId = nil
        careDataOwnerId = nil
        careDataOwnerName = nil
        careLinkStatus = nil

        tasks = []
        diary = []
        contacts = []
        callEvents = []
        gameResults = []

        saveUserRole(nil)
        saveProfileReady(false)
        saveProfileStatus(nil)
        // non cancelliamo dati locali
    }

    // MARK: - Contacts helpers
    func canAddContact(name: String, relation: String?) -> Bool {
        let temp = ContactItem(name: name, relation: relation)
        return !contacts.contains(where: { $0.uniqueKey == temp.uniqueKey })
    }

    func upsertContact(_ contact: ContactItem) {
        if let idx = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[idx] = contact
        } else {
            contacts.append(contact)
        }
        saveContacts()
    }

    // MARK: - Calls (log + stats)
    func logAndCall(_ contact: ContactItem) {
        guard let phone = contact.phone else { return }

        callEvents.insert(CallEvent(contactKey: contact.uniqueKey, timestamp: .now), at: 0)
        saveCalls()

        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }

        #if targetEnvironment(simulator)
        print("⚠️ tel:// does not work on Simulator. Test on a real iPhone.")
        #endif

        UIApplication.shared.open(url)
    }

    func callSummary(for contact: ContactItem, on day: Date = .now) -> (count: Int, last: Date?) {
        let (start, end) = romeDayRange(for: day)

        let events = callEvents.filter {
            $0.contactKey == contact.uniqueKey &&
            $0.timestamp >= start &&
            $0.timestamp < end
        }

        let last = events.map(\.timestamp).max()
        return (events.count, last)
    }

    func dailyCallsBreakdown(on day: Date = .now) -> [(contactKey: String, count: Int, last: Date?)] {
        let (start, end) = romeDayRange(for: day)
        let filtered = callEvents.filter { $0.timestamp >= start && $0.timestamp < end }

        var counts: [String: [Date]] = [:]
        for e in filtered {
            counts[e.contactKey, default: []].append(e.timestamp)
        }

        return counts.map { key, dates in
            (contactKey: key, count: dates.count, last: dates.max())
        }
        .sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return (a.last ?? .distantPast) > (b.last ?? .distantPast)
        }
    }

    func lastNDaysCallRanking(days: Int = 30, now: Date = .now) -> [(contactKey: String, total: Int)] {
        let range = romeLastNDaysRangeEndingToday(days: days, now: now)
        let filtered = callEvents.filter { $0.timestamp >= range.from && $0.timestamp < range.to }

        var dict: [String: Int] = [:]
        for e in filtered { dict[e.contactKey, default: 0] += 1 }

        return dict.map { ($0.key, $0.value) }
            .sorted { $0.total > $1.total }
    }

    func callsPerDayLastNDays(days: Int = 14, now: Date = .now) -> [(dayStart: Date, count: Int)] {
        guard days > 0 else { return [] }
        let cal = romeCalendar()
        let startToday = cal.startOfDay(for: now)

        var buckets: [Date: Int] = [:]
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: -offset, to: startToday) {
                buckets[d] = 0
            }
        }

        let earliest = cal.date(byAdding: .day, value: -(days - 1), to: startToday) ?? startToday
        let end = cal.date(byAdding: .day, value: 1, to: startToday) ?? now

        for e in callEvents {
            guard e.timestamp >= earliest && e.timestamp < end else { continue }
            let day = cal.startOfDay(for: e.timestamp)
            if buckets[day] != nil {
                buckets[day, default: 0] += 1
            }
        }

        return buckets
            .map { ($0.key, $0.value) }
            .sorted { $0.dayStart < $1.dayStart }
    }

    // MARK: - Games (save + stats)
    func addGameResult(_ result: GameSessionResult) {
        gameResults.insert(result, at: 0)
        saveGames()
    }

    func gameSessions(on day: Date = .now, type: GameType? = nil) -> [GameSessionResult] {
        let (start, end) = romeDayRange(for: day)
        return gameResults
            .filter { $0.finishedAt >= start && $0.finishedAt < end }
            .filter { type == nil ? true : $0.type == type }
            .sorted { $0.finishedAt > $1.finishedAt }
    }

    func gameMonthlyAggregateLastNDays(days: Int = 30, now: Date = .now, type: GameType? = nil)
    -> (sessions: Int, totalAttempts: Int, avgTimeSec: Double, avgScore: Double) {

        let range = romeLastNDaysRangeEndingToday(days: days, now: now)
        let filtered = gameResults
            .filter { $0.finishedAt >= range.from && $0.finishedAt < range.to }
            .filter { type == nil ? true : $0.type == type }

        guard !filtered.isEmpty else { return (0, 0, 0, 0) }

        let sessions = filtered.count
        let totalAttempts = filtered.reduce(0) { $0 + $1.totalAttempts }
        let totalRounds = filtered.reduce(0) { $0 + $1.totalRounds }
        guard totalRounds > 0 else { return (sessions, totalAttempts, 0, 0) }
        let avgTime = Double(filtered.reduce(0) { $0 + $1.durationSeconds }) / Double(sessions)
        let avgScore = Double(filtered.reduce(0) { $0 + $1.correctCount }) / Double(totalRounds)

        return (sessions, totalAttempts, avgTime, avgScore)
    }

    func guessWhoAvgScorePerDayLastNDays(days: Int = 14, now: Date = .now)
    -> [(dayStart: Date, avgScore: Double, sessions: Int)] {
        guard days > 0 else { return [] }
        let cal = romeCalendar()
        let startToday = cal.startOfDay(for: now)
        let earliest = cal.date(byAdding: .day, value: -(days - 1), to: startToday) ?? startToday
        let end = cal.date(byAdding: .day, value: 1, to: startToday) ?? now

        var buckets: [Date: [GameSessionResult]] = [:]
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: -offset, to: startToday) {
                buckets[d] = []
            }
        }

        for s in gameResults where s.type == .guessWho {
            guard s.finishedAt >= earliest && s.finishedAt < end else { continue }
            let day = cal.startOfDay(for: s.finishedAt)
            if buckets[day] != nil {
                buckets[day, default: []].append(s)
            }
        }

        return buckets.map { day, sessions in
            if sessions.isEmpty { return (dayStart: day, avgScore: 0, sessions: 0) }
            let rounds = sessions.reduce(0) { $0 + $1.totalRounds }
            guard rounds > 0 else { return (dayStart: day, avgScore: 0, sessions: sessions.count) }
            let avg = Double(sessions.reduce(0) { $0 + $1.correctCount }) / Double(rounds)
            return (dayStart: day, avgScore: avg, sessions: sessions.count)
        }
        .sorted { $0.dayStart < $1.dayStart }
    }

    func guessWhoAttemptsPerDayLastNDays(days: Int = 14, now: Date = .now) -> [(dayStart: Date, attempts: Int)] {
        guard days > 0 else { return [] }
        let cal = romeCalendar()
        let startToday = cal.startOfDay(for: now)
        let earliest = cal.date(byAdding: .day, value: -(days - 1), to: startToday) ?? startToday
        let end = cal.date(byAdding: .day, value: 1, to: startToday) ?? now

        var buckets: [Date: Int] = [:]
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: -offset, to: startToday) {
                buckets[d] = 0
            }
        }

        for s in gameResults where s.type == .guessWho {
            guard s.finishedAt >= earliest && s.finishedAt < end else { continue }
            let day = cal.startOfDay(for: s.finishedAt)
            if buckets[day] != nil {
                buckets[day, default: 0] += s.totalAttempts
            }
        }

        return buckets.map { ($0.key, $0.value) }
            .sorted { $0.dayStart < $1.dayStart }
    }

    // MARK: - Rome calendar helpers
    private func romeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Rome") ?? .current
        return cal
    }

    private func romeDayRange(for day: Date) -> (start: Date, end: Date) {
        let cal = romeCalendar()
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? day
        return (start, end)
    }

    private func romeLastNDaysRangeEndingToday(days: Int, now: Date) -> (from: Date, to: Date) {
        let cal = romeCalendar()
        let startToday = cal.startOfDay(for: now)
        let from = cal.date(byAdding: .day, value: -(max(1, days) - 1), to: startToday) ?? startToday
        let to = cal.date(byAdding: .day, value: 1, to: startToday) ?? now
        return (from, to)
    }
}

// MARK: - Supabase bootstrap
extension AppState {

    @MainActor
    func loadSupabaseSession() async {
        let session = await AuthService.shared.currentSession()

        guard let session else {
            self.currentUser = nil
            self.sessionUserId = nil
            self.careDataOwnerId = nil
            self.careDataOwnerName = nil
            self.careLinkStatus = nil
            if self.isGuest {
                self.loadUserData("guest")
            } else {
                self.tasks = []
                self.diary = []
                self.contacts = []
                self.callEvents = []
                self.gameResults = []
            }
            UserDefaults.standard.removeObject(forKey: self.userKey)
            self.saveUserRole(nil)
            self.saveProfileStatus(nil)
            self.saveProfileReady(false)
            return
        }

        let email = session.user.email ?? ""
        let nameFromEmail = email.split(separator: "@").first.map(String.init) ?? "User"
        setGuest(false)

        self.currentUser = UserProfile(
            name: nameFromEmail,
            phone: "",
            email: email,
            provider: "email"
        )
        self.saveUser()

        let userId = session.user.id.uuidString
        self.sessionUserId = userId

        self.loadUserData(userId)

        try? await ProfilesService.shared.ensureProfile(
            displayName: nameFromEmail,
            email: email
        )
        await self.refreshProfileFromSupabase()
        await SyncEngine.fullSync(state: self)
    }
}
