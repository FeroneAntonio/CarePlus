import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText = ""
    @Published private(set) var partnerName = "Care partner"
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private var context: ChatContext?
    private var currentUserId: String?
    private var pollingTask: Task<Void, Never>?

    var canSend: Bool {
        context != nil && !isSending && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func start(state: AppState) async {
        stop()
        isLoading = true
        errorMessage = nil
        messages = []

        guard let userId = state.sessionUserId else {
            isLoading = false
            errorMessage = ChatServiceError.unauthenticated.localizedDescription
            return
        }

        do {
            let resolved = try await ChatService.shared.resolveContext(role: state.userRole)
            context = resolved
            currentUserId = userId
            partnerName = resolved.partnerName
            try await refreshMessages()
            beginPolling()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func retry(state: AppState) async {
        await start(state: state)
    }

    func send() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let context, let currentUserId else { return }

        isSending = true
        errorMessage = nil
        draftText = ""

        do {
            try await ChatService.shared.send(
                text: trimmed,
                context: context,
                currentUserId: currentUserId
            )
            try await refreshMessages()
        } catch {
            draftText = trimmed
            errorMessage = "Message not sent. \(error.localizedDescription)"
        }

        isSending = false
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func refreshMessages() async throws {
        guard let context, let currentUserId else { return }
        messages = try await ChatService.shared.fetchMessages(
            context: context,
            currentUserId: currentUserId
        )
    }

    private func beginPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, let self else { return }
                try? await self.refreshMessages()
            }
        }
    }
}
