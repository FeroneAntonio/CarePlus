import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let senderId: String
    let text: String
    let date: Date
    let isFromCurrentUser: Bool

    init(
        id: UUID = UUID(),
        senderId: String,
        text: String,
        date: Date = .now,
        isFromCurrentUser: Bool
    ) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.date = date
        self.isFromCurrentUser = isFromCurrentUser
    }
}
