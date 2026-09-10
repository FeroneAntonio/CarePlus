import Foundation
import Supabase

enum SupabaseConfig {
    static let url: URL = {
        guard let url = URL(string: requiredValue(named: "SUPABASE_URL")) else {
            preconditionFailure("SUPABASE_URL is not a valid URL")
        }
        return url
    }()

    static let anonKey = requiredValue(named: "SUPABASE_PUBLISHABLE_KEY")

    private static func requiredValue(named key: String) -> String {
        let environmentValue = ProcessInfo.processInfo.environment[key]
        let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let value = (environmentValue ?? plistValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        precondition(!value.isEmpty, "Configure \(key) in the Xcode scheme or Info.plist")
        return value
    }
}

final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(
                    // Opt-in to emitting the locally stored session as the initial session to avoid the warning from AuthClient
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
