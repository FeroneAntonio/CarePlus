import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var scheme

    private var isUser: Bool { message.isFromCurrentUser }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isUser ? Color.white : AppTheme.textPrimary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        isUser
                        ? AppTheme.primary.opacity(0.85)
                        : AppTheme.surface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(message.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubble(message: ChatMessage(senderId: "caregiver", text: "Messaggio di prova del caregiver", isFromCurrentUser: false))
        ChatBubble(message: ChatMessage(senderId: "patient", text: "Risposta dell'utente", isFromCurrentUser: true))
    }
    .padding()
}
