import Foundation
import Supabase

struct ProfileRowDTO: Codable, Sendable {
    let id: String
    let status: String
    let role: String?
    let display_name: String?
    let email: String?
}

struct ProfileUpsertDTO: Encodable, Sendable {
    let id: String
    let status: String?
    let role: String?
    let display_name: String?
    let email: String?
}

struct ProfileLookupDTO: Decodable, Sendable {
    let id: String
    let role: String?
    let status: String
    let display_name: String?
    let email: String?
}

@MainActor
final class ProfilesService {
    static let shared = ProfilesService()
    private init() {}

    private var client: SupabaseClient { SupabaseClientProvider.shared.client }

    func fetchProfile() async throws -> ProfileRowDTO? {
        guard let session = await AuthService.shared.currentSession() else { return nil }
        let userId = session.user.id.uuidString

        let rows: [ProfileRowDTO] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchProfile(id: String) async throws -> ProfileRowDTO? {
        let rows: [ProfileRowDTO] = try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func upsertProfile(_ dto: ProfileUpsertDTO) async throws {
        _ = try await client
            .from("profiles")
            .upsert(dto, onConflict: "id")
            .execute()
    }

    func ensureProfile(displayName: String, email: String) async throws {
        guard let session = await AuthService.shared.currentSession() else { return }
        let existing = try await fetchProfile()

        try await upsertProfile(ProfileUpsertDTO(
            id: session.user.id.uuidString,
            status: existing?.status ?? "pending",
            role: existing?.role,
            display_name: existing?.display_name?.isEmpty == false
                ? existing?.display_name
                : displayName,
            email: existing?.email?.isEmpty == false
                ? existing?.email
                : email.lowercased()
        ))
    }

    /// Set role only once (RoleChoiceView).
    /// IMPORTANT: role must be "patient" or "caregiver" (DB enum).
    func setRoleOnce(_ role: String) async throws {
        guard let session = await AuthService.shared.currentSession() else { return }
        let userId = session.user.id.uuidString

        let normalized = role.lowercased()
        guard normalized == "patient" || normalized == "caregiver" else {
            throw NSError(domain: "ProfilesService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid role: \(role)"])
        }

        let existing = try? await fetchProfile()
        if let existingRole = existing?.role, !existingRole.isEmpty {
            guard existingRole == normalized else {
                throw NSError(
                    domain: "ProfilesService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "This account is already registered as \(existingRole)."]
                )
            }
            return
        }

        struct Upsert: Encodable {
            let id: String
            let role: String
            let status: String
        }

        // Keep pending so SetupWizard can run.
        let payload = Upsert(id: userId, role: normalized, status: "pending")

        _ = try await client
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    // MARK: - RPC: look up a care partner without exposing the profiles table.

    func findProfile(byEmail email: String) async throws -> ProfileLookupDTO? {
        let res: [ProfileLookupDTO] = try await client
            .rpc("find_care_profile_by_email", params: ["p_email": email.lowercased()])
            .execute()
            .value
        return res.first
    }
}
