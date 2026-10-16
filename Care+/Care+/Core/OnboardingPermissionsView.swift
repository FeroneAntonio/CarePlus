import SwiftUI
import Contacts
import AVFoundation
import UserNotifications
import UniformTypeIdentifiers
import PDFKit

/// Paged setup shown once after the education screen: permissions, contacts and an optional medical report.
struct OnboardingPermissionsView: View {
    @Bindable var state: AppState

    private enum Step: Int, CaseIterable { case contacts, microphone, camera, notifications, report }

    @State private var step: Step = .contacts
    @State private var granted: Set<Step> = []
    @State private var importedContacts: Int?
    @State private var reportResult: String?
    @State private var isPickingReport = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Skip") { state.setOnboardingCompleted() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            TabView(selection: $step) {
                ForEach(Step.allCases, id: \.self) { step in
                    page(for: step).tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item == step ? AppTheme.primary : AppTheme.primary.opacity(0.2))
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            .accessibilityHidden(true)

            Button(action: next) {
                Text(step == .report ? "Start using Care+" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppTheme.primary, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .tint(AppTheme.primary)
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.snappy, value: step)
        .task { await refreshStatuses() }
        .fileImporter(isPresented: $isPickingReport, allowedContentTypes: [.pdf, .plainText, .rtf]) { result in
            if case .success(let url) = result { importReport(from: url) }
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func page(for step: Step) -> some View {
        switch step {
        case .contacts:
            pageLayout(icon: "person.crop.circle.badge.plus", title: "Your people",
                       text: "Import the people who matter, so they can be called in one tap and used in memory games.") {
                if let importedContacts {
                    statusLabel("\(importedContacts) contacts imported")
                } else {
                    secondaryButton("Import contacts") { importContacts() }
                }
            }
        case .microphone:
            pageLayout(icon: "mic.fill", title: "Voice notes",
                       text: "Record a loved one's voice or a diary note. Familiar voices can be calming.") {
                permissionButton(for: .microphone) { await AVAudioApplication.requestRecordPermission() }
            }
        case .camera:
            pageLayout(icon: "camera.fill", title: "Photos of moments",
                       text: "Take photos for the diary and for contacts, so faces are easy to recognise.") {
                permissionButton(for: .camera) { await AVCaptureDevice.requestAccess(for: .video) }
            }
        case .notifications:
            pageLayout(icon: "bell.badge.fill", title: "Gentle reminders",
                       text: "Get a reminder for medication and activities at the right time.") {
                permissionButton(for: .notifications) {
                    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                }
            }
        case .report:
            pageLayout(icon: "doc.text.fill", title: "Medical report",
                       text: "Optional. Import a PDF or text file: lines starting with “Medication:” or “Task:” become reminders for today.") {
                if let reportResult {
                    statusLabel(reportResult)
                } else {
                    secondaryButton("Choose a file") { isPickingReport = true }
                }
            }
        }
    }

    private func pageLayout(icon: String, title: String, text: String, @ViewBuilder action: () -> some View) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 104, height: 104)
                .background(AppTheme.primary.opacity(0.12), in: Circle())
            Text(title)
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(text)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary)
            action()
                .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func permissionButton(for step: Step, request: @escaping () async -> Bool) -> some View {
        Group {
            if granted.contains(step) {
                statusLabel("Allowed")
            } else {
                secondaryButton("Allow") {
                    Task {
                        if await request() { granted.insert(step) }
                    }
                }
            }
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline)
            .frame(minWidth: 180, minHeight: 48)
            .background(AppTheme.primary.opacity(0.12), in: Capsule())
            .foregroundStyle(AppTheme.primary)
            .buttonStyle(.plain)
    }

    private func statusLabel(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(AppTheme.success)
            .frame(minHeight: 48)
    }

    // MARK: - Actions

    private func next() {
        if let following = Step(rawValue: step.rawValue + 1) {
            step = following
        } else {
            state.setOnboardingCompleted()
        }
    }

    private func refreshStatuses() async {
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized { granted.insert(.contacts) }
        if AVAudioApplication.shared.recordPermission == .granted { granted.insert(.microphone) }
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { granted.insert(.camera) }
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized {
            granted.insert(.notifications)
        }
    }

    private func importContacts() {
        ContactsImportService.importFromDevice(existing: state.contacts) { imported in
            state.contacts.append(contentsOf: imported)
            state.saveContacts()
            state.setContactsImported()
            importedContacts = imported.count
        }
    }

    private func importReport(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let text: String? = url.pathExtension.lowercased() == "pdf"
            ? PDFDocument(url: url)?.string
            : try? String(contentsOf: url, encoding: .utf8)

        guard let text else {
            reportResult = "Could not read this file"
            return
        }
        let items = MedicalReportParser.tasks(from: text)
        state.tasks.insert(contentsOf: items, at: 0)
        state.saveTasks()
        reportResult = items.isEmpty ? "No reminders found in the report" : "\(items.count) reminders added"
    }
}

/// Turns "Medication: …" / "Task: …" lines (English or Italian keywords) into tasks scheduled for today.
enum MedicalReportParser {
    private static let medicationKeys = ["medication", "farmaco"]
    private static let taskKeys = ["task", "attività", "attivita", "azione"]

    static func tasks(from text: String, on day: Date = .now) -> [TaskItem] {
        let cal = Calendar.current
        let medicationTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        let taskTime = cal.date(bySettingHour: 10, minute: 0, second: 0, of: day)

        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return nil }

            if medicationKeys.contains(key) {
                return TaskItem(title: value, notes: "From medical report", kind: .medication, dueDate: medicationTime)
            }
            if taskKeys.contains(key) {
                return TaskItem(title: value, notes: "From medical report", kind: .event, dueDate: taskTime)
            }
            return nil
        }
    }
}
