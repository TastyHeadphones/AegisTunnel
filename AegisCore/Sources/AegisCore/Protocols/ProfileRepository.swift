import Foundation

public protocol ProfileRepository: Sendable {
    func loadProfiles() async throws -> [Profile]
    func saveProfile(_ profile: Profile) async throws
    func deleteProfile(id: UUID) async throws
}
