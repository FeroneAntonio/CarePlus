import Foundation

public enum TaskKind: String, Codable, CaseIterable, Sendable {
    case event
    case medication
}

public struct TaskItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String?

    // Media/metadata used by UI
    public var imageData: Data?
    public var audioURL: URL?
    public var phone: String?
    public var notificationId: String?
    public var kind: TaskKind

    // Core fields
    public var isCompleted: Bool
    public var dueDate: Date?
    public var createdAt: Date
    public var updatedAt: Date

    // Aliases used across UI
    public var isDone: Bool {
        get { isCompleted }
        set { isCompleted = newValue }
    }

    public var scheduledAt: Date? {
        get { dueDate }
        set { dueDate = newValue }
    }

    public var uniqueKey: String { id.uuidString }

    // MARK: - Main initializer (most explicit)
    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        kind: TaskKind = .event,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        imageData: Data? = nil,
        audioURL: URL? = nil,
        phone: String? = nil,
        notificationId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.kind = kind

        self.isCompleted = isCompleted
        self.dueDate = dueDate

        self.imageData = imageData
        self.audioURL = audioURL
        self.phone = phone
        self.notificationId = notificationId

        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Convenience initializer (matches your current UI usage)
    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        isDone: Bool = false,
        audioURL: URL? = nil,
        imageData: Data? = nil,
        phone: String? = nil,
        scheduledAt: Date? = nil,
        notificationId: String? = nil,
        kind: TaskKind = .event,
        notes: String? = nil
    ) {
        let now = Date()
        self.init(
            id: id,
            title: title,
            notes: notes,
            kind: kind,
            isCompleted: isDone,
            dueDate: scheduledAt,
            imageData: imageData,
            audioURL: audioURL,
            phone: phone,
            notificationId: notificationId,
            createdAt: createdAt,
            // important: updatedAt should reflect "creation moment" too
            updatedAt: max(createdAt, now)
        )
    }

    // MARK: - Mutations
    public mutating func markCompleted(_ completed: Bool = true) {
        isCompleted = completed
        updatedAt = Date()
    }

    public mutating func touch() {
        updatedAt = Date()
    }
}
