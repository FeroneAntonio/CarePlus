import Foundation
import Supabase

struct CareLinkDTO: Codable, Sendable {
    let id: String
    let caregiver_id: String
    let patient_id: String
    let status: String
    let created_at: String?
}

@MainActor
final class CareLinksService {
    static let shared = CareLinksService()
    private init() {}

    private var client: SupabaseClient { SupabaseClientProvider.shared.client }

    /// The first account requests a link; the counterpart confirms it by requesting
    /// the same pair from their own authenticated account.
    func requestLink(patientId: String, caregiverId: String) async throws {
        _ = try await client.database
            .rpc(
                "request_care_link",
                params: [
                    "p_patient_id": patientId,
                    "p_caregiver_id": caregiverId
                ]
            )
            .execute()
    }

    // Lista caregivers del patient
    func fetchCaregivers(forPatientId patientId: String) async throws -> [CareLinkDTO] {
        let rows: [CareLinkDTO] = try await client.database
            .from("care_links")
            .select()
            .eq("patient_id", value: patientId)
            .execute()
            .value
        return rows
    }

    // Lista patients del caregiver
    func fetchPatients(forCaregiverId caregiverId: String) async throws -> [CareLinkDTO] {
        let rows: [CareLinkDTO] = try await client.database
            .from("care_links")
            .select()
            .eq("caregiver_id", value: caregiverId)
            .execute()
            .value
        return rows
    }

    // Prendi un link specifico (se esiste)
    func fetchLink(patientId: String, caregiverId: String) async throws -> CareLinkDTO? {
        let rows: [CareLinkDTO] = try await client.database
            .from("care_links")
            .select()
            .eq("patient_id", value: patientId)
            .eq("caregiver_id", value: caregiverId)
            .execute()
            .value
        return rows.first
    }
}
