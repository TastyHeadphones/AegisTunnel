import Foundation

public enum JSONProfileRepositoryError: Error, Sendable {
    case invalidProfilesDirectory(URL)
}

public actor JSONProfileRepository: ProfileRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()
    }

    public func loadProfiles() async throws -> [Profile] {
        try readProfiles()
    }

    public func saveProfile(_ profile: Profile) async throws {
        var profiles = try readProfiles()

        if let existingIndex = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[existingIndex] = profile
        } else {
            profiles.append(profile)
        }

        try writeProfiles(profiles)
    }

    public func deleteProfile(id: UUID) async throws {
        var profiles = try readProfiles()
        profiles.removeAll { $0.id == id }
        try writeProfiles(profiles)
    }

    private func readProfiles() throws -> [Profile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return []
        }

        return try decoder.decode([Profile].self, from: data)
    }

    private func writeProfiles(_ profiles: [Profile]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } else if !isDirectory.boolValue {
            throw JSONProfileRepositoryError.invalidProfilesDirectory(directoryURL)
        }

        let sortedProfiles = profiles.sorted { lhs, rhs in
            if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let data = try encoder.encode(sortedProfiles)
        try data.write(to: fileURL, options: .atomic)
    }
}
