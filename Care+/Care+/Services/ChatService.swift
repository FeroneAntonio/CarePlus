import Foundation
import Supabase

struct ChatContext: Sendable {
    let careLinkId: String
    let partnerId: String
    let partnerName: String
}

private struct ChatMessageRow: Decodable, Sendable {
    let id: String
    let care_link_id: String
    let sender_id: String
    let body: String
    let created_at: String
}

private struct ChatMessageInsert: Encodable, Sendable {
    let care_link_id: String
    let sender_id: String
    let body: String
}

enum ChatServiceError: LocalizedError {
    case unauthenticated
    case roleMissing
    case carePartnerMissing

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Sign in to chat with your care partner."
        case .roleMissing:
            return "Complete your account setup before opening chat."
        case .carePartnerMissing:
            return "No active patient-caregiver connection was found."
        }
    }
}

@MainActor
final class ChatService {
    static let shared = ChatService()

    private let client = SupabaseClientProvider.shared.client
    private init() {}

    func resolveContext(role: String?) async throws -> ChatContext {
        guard let session = await AuthService.shared.currentSession() else {
            throw ChatServiceError.unauthenticated
        }

        let userId = session.user.id.uuidString
        let normalizedRole = role?.lowercased()
        let links: [CareLinkDTO]
        let partnerId: (CareLinkDTO) -> String

        switch normalizedRole {
        case "patient":
            links = try await CareLinksService.shared.fetchCaregivers(forPatientId: userId)
            partnerId = { $0.caregiver_id }
        case "caregiver":
            links = try await CareLinksService.shared.fetchPatients(forCaregiverId: userId)
            partnerId = { $0.patient_id }
        default:
            throw ChatServiceError.roleMissing
        }

        guard let link = links.first(where: { $0.status.lowercased() == "active" }) else {
            throw ChatServiceError.carePartnerMissing
        }

        let linkedUserId = partnerId(link)
        let profile = try? await ProfilesService.shared.fetchProfile(id: linkedUserId)
        let fallback = normalizedRole == "patient" ? "Caregiver" : "Patient"

        return ChatContext(
            careLinkId: link.id,
            partnerId: linkedUserId,
            partnerName: profile?.display_name?.nilIfBlank ?? fallback
        )
    }

    func fetchMessages(context: ChatContext, currentUserId: String) async throws -> [ChatMessage] {
        let rows: [ChatMessageRow] = try await client.database
            .from("messages")
            .select()
            .eq("care_link_id", value: context.careLinkId)
            .order("created_at", ascending: true)
            .limit(250)
            .execute()
            .value

        return rows.compactMap { row in
            guard let id = UUID(uuidString: row.id) else { return nil }
            return ChatMessage(
                id: id,
                senderId: row.sender_id,
                text: row.body,
                date: Self.parseDate(row.created_at),
                isFromCurrentUser: row.sender_id == currentUserId
            )
        }
    }

    func send(text: String, context: ChatContext, currentUserId: String) async throws {
        let payload = ChatMessageInsert(
            care_link_id: context.careLinkId,
            sender_id: currentUserId,
            body: text
        )

        _ = try await client.database
            .from("messages")
            .insert(payload)
            .execute()
    }

    private static func parseDate(_ value: String) -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        return ISO8601DateFormatter().date(from: value) ?? .now
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
