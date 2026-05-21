import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class SupabaseService {
    public let client: SupabaseClient
    
    public init(
        supabaseURL: String = "https://tsbdnndvgxlypvewsmux.supabase.co",
        supabaseKey: String = "sb_publishable_4cSeTU18hmF-eRFMBlSEkg_wCdMZzMh"
    ) {
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
    
    private struct AppUserSyncPayload: Encodable {
        let clerk_user_id: String
        let email: String?
        let full_name: String?
        let username: String?
        let image_url: String?
        let status: String
        let deleted_at: String?
    }
    
    /// Upsert app user record into Supabase `app_users` table
    /// Called after successful Clerk authentication to sync user data
    public func syncUserFromClerk(
        clerkUserId: String,
        email: String?,
        fullName: String?,
        username: String?,
        imageUrl: String?
    ) async throws {
        let payload = AppUserSyncPayload(
            clerk_user_id: clerkUserId,
            email: email,
            full_name: fullName,
            username: username,
            image_url: imageUrl,
            status: "active",
            deleted_at: nil
        )
        
        _ = try await client.database
            .from("app_users")
            .upsert(payload, onConflict: "clerk_user_id")
            .execute()
    }
    
    private struct AppUserDeletePayload: Encodable {
        let clerk_user_id: String
        let status: String
        let deleted_at: String?
    }

    /// Mark user as deleted in Supabase (soft delete)
    public func markUserDeleted(clerkUserId: String) async throws {
        let payload = AppUserDeletePayload(
            clerk_user_id: clerkUserId,
            status: "deleted",
            deleted_at: ISO8601DateFormatter().string(from: Date())
        )
        
        _ = try await client.database
            .from("app_users")
            .upsert(payload, onConflict: "clerk_user_id")
            .execute()
    }
}
