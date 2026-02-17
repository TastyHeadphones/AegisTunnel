import Foundation
import Observation
import AegisCore

@MainActor
@Observable
public final class AppViewModel {
    public private(set) var profiles: [Profile] = []
    public var selectedProfileID: UUID?

    public private(set) var snapshot: TransportSnapshot = .idle()
    public private(set) var isBusy = false
    public var isPresentingProfileEditor = false
    public var profileDraft = ProfileDraft()
    public var errorMessage: String?

    public let logStore: LogStore

    private let profileRepository: any ProfileRepository
    private let secretStore: any SecretStore
    private let transportController: TransportController
    private var snapshotTask: Task<Void, Never>?

    public init(
        profileRepository: any ProfileRepository,
        secretStore: any SecretStore,
        transportController: TransportController,
        logStore: LogStore
    ) {
        self.profileRepository = profileRepository
        self.secretStore = secretStore
        self.transportController = transportController
        self.logStore = logStore
    }

    deinit {
        snapshotTask?.cancel()
    }

    public var selectedProfile: Profile? {
        guard let selectedProfileID else {
            return nil
        }

        return profiles.first(where: { $0.id == selectedProfileID })
    }

    public func start() {
        snapshotTask?.cancel()

        snapshotTask = Task { [weak self] in
            guard let self else {
                return
            }

            let stream = await self.transportController.snapshots()
            for await snapshot in stream {
                self.snapshot = snapshot
            }
        }

        Task { [weak self] in
            await self?.refreshProfiles()
        }
    }

    public func refreshProfiles() async {
        isBusy = true
        defer { isBusy = false }

        do {
            profiles = try await profileRepository.loadProfiles()

            if let selectedProfileID,
               let selected = profiles.first(where: { $0.id == selectedProfileID }) {
                await transportController.setActiveProfile(selected)
            } else if let first = profiles.first {
                selectedProfileID = first.id
                await transportController.setActiveProfile(first)
            } else {
                selectedProfileID = nil
                await transportController.setActiveProfile(nil)
            }
        } catch {
            errorMessage = "Failed to load profiles: \(error.localizedDescription)"
        }
    }

    public func selectProfileByID(_ id: UUID?) async {
        selectedProfileID = id
        let selected = profiles.first(where: { $0.id == id })
        await transportController.setActiveProfile(selected)
    }

    public func beginCreateProfile() {
        profileDraft = ProfileDraft()
        isPresentingProfileEditor = true
    }

    public func beginEditProfile(_ profile: Profile) async {
        var draft = ProfileDraft(profile: profile)

        switch profile.transportOptions {
        case let .masque(options):
            if
                let credentialID = options.proxyAuthorizationCredentialID,
                let value = try? await secretStore.loadString(id: credentialID)
            {
                applyCredentialString(value, to: &draft)
            }

            if
                let pinningCredentialID = options.pinningCredentialID,
                let payload = try? await secretStore.load(id: pinningCredentialID),
                let pinning = try? JSONDecoder().decode(TLSPinningPolicy.self, from: payload)
            {
                draft.pinnedCertificateHashesCSV = pinning.certificateSHA256Base64.joined(separator: ",")
                draft.pinnedPublicKeyHashesCSV = pinning.publicKeySHA256Base64.joined(separator: ",")
            }
        case let .httpConnectTLS(options):
            if
                let credentialID = options.proxyAuthorizationCredentialID,
                let value = try? await secretStore.loadString(id: credentialID)
            {
                applyCredentialString(value, to: &draft)
            }

            if
                let pinningCredentialID = options.pinningCredentialID,
                let payload = try? await secretStore.load(id: pinningCredentialID),
                let pinning = try? JSONDecoder().decode(TLSPinningPolicy.self, from: payload)
            {
                draft.pinnedCertificateHashesCSV = pinning.certificateSHA256Base64.joined(separator: ",")
                draft.pinnedPublicKeyHashesCSV = pinning.publicKeySHA256Base64.joined(separator: ",")
            }
        case let .socks5TLS(options):
            if
                let credentialID = options.usernamePasswordCredentialID,
                let payload = try? await secretStore.load(id: credentialID),
                let credential = try? JSONDecoder().decode(UsernamePasswordCredential.self, from: payload)
            {
                draft.proxyUsername = credential.username
                draft.proxyPassword = credential.password
            }

            if
                let pinningCredentialID = options.pinningCredentialID,
                let payload = try? await secretStore.load(id: pinningCredentialID),
                let pinning = try? JSONDecoder().decode(TLSPinningPolicy.self, from: payload)
            {
                draft.pinnedCertificateHashesCSV = pinning.certificateSHA256Base64.joined(separator: ",")
                draft.pinnedPublicKeyHashesCSV = pinning.publicKeySHA256Base64.joined(separator: ",")
            }
        case let .mtlsTCP(options):
            if
                let pinningCredentialID = options.pinningCredentialID,
                let payload = try? await secretStore.load(id: pinningCredentialID),
                let pinning = try? JSONDecoder().decode(TLSPinningPolicy.self, from: payload)
            {
                draft.pinnedCertificateHashesCSV = pinning.certificateSHA256Base64.joined(separator: ",")
                draft.pinnedPublicKeyHashesCSV = pinning.publicKeySHA256Base64.joined(separator: ",")
            }
        case let .quic(options):
            if
                let pinningCredentialID = options.pinningCredentialID,
                let payload = try? await secretStore.load(id: pinningCredentialID),
                let pinning = try? JSONDecoder().decode(TLSPinningPolicy.self, from: payload)
            {
                draft.pinnedCertificateHashesCSV = pinning.certificateSHA256Base64.joined(separator: ",")
                draft.pinnedPublicKeyHashesCSV = pinning.publicKeySHA256Base64.joined(separator: ",")
            }
        }

        profileDraft = draft
        isPresentingProfileEditor = true
    }

    public func saveProfileDraft() async {
        guard profileDraft.isValid else {
            errorMessage = "Name, endpoint, and required transport fields are needed."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let proxyAuthorizationCredentialID = try await storeProxyAuthorizationIfNeeded()
            let socksCredentialID = try await storeSocksCredentialIfNeeded()
            let pinningCredentialID = try await storePinningPolicyIfNeeded()

            let profile = try profileDraft.makeProfile(
                proxyAuthorizationCredentialID: proxyAuthorizationCredentialID,
                socksUsernamePasswordCredentialID: socksCredentialID,
                pinningCredentialIDOverride: pinningCredentialID
            )

            try await profileRepository.saveProfile(profile)

            isPresentingProfileEditor = false
            profileDraft = ProfileDraft()

            await refreshProfiles()
            await selectProfileByID(profile.id)
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
    }

    public func deleteProfiles(at offsets: IndexSet) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let toDelete = offsets.compactMap { index -> Profile? in
                guard profiles.indices.contains(index) else {
                    return nil
                }
                return profiles[index]
            }

            for profile in toDelete {
                try await profileRepository.deleteProfile(id: profile.id)

                switch profile.transportOptions {
                case let .masque(options):
                    try await deleteIfPresent(options.proxyAuthorizationCredentialID)
                    try await deleteIfPresent(options.clientIdentityCredentialID)
                    try await deleteIfPresent(options.pinningCredentialID)
                case let .httpConnectTLS(options):
                    try await deleteIfPresent(options.proxyAuthorizationCredentialID)
                    try await deleteIfPresent(options.clientIdentityCredentialID)
                    try await deleteIfPresent(options.pinningCredentialID)
                case let .socks5TLS(options):
                    try await deleteIfPresent(options.usernamePasswordCredentialID)
                    try await deleteIfPresent(options.clientIdentityCredentialID)
                    try await deleteIfPresent(options.pinningCredentialID)
                case let .mtlsTCP(options):
                    try await deleteIfPresent(options.clientIdentityCredentialID)
                    try await deleteIfPresent(options.pinningCredentialID)
                case let .quic(options):
                    try await deleteIfPresent(options.clientIdentityCredentialID)
                    try await deleteIfPresent(options.pinningCredentialID)
                }

                if selectedProfileID == profile.id {
                    selectedProfileID = nil
                }
            }

            await refreshProfiles()
        } catch {
            errorMessage = "Failed to delete profile: \(error.localizedDescription)"
        }
    }

    public func connect() async {
        do {
            try await transportController.connect()
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }
    }

    public func disconnect() async {
        await transportController.disconnect()
    }

    public func toggleConnection() async {
        switch snapshot.status {
        case .connected, .connecting:
            await disconnect()
        case .disconnected, .disconnecting, .failed:
            await connect()
        }
    }

    private func storeProxyAuthorizationIfNeeded() async throws -> UUID? {
        guard profileDraft.transportType == .httpConnectTLS || profileDraft.transportType == .masqueHTTP3 else {
            return nil
        }

        let username = profileDraft.proxyUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = profileDraft.proxyPassword

        guard !username.isEmpty else {
            return nil
        }

        let id = UUID()
        try await secretStore.store(secret: "\(username):\(password)", for: id)
        return id
    }

    private func storeSocksCredentialIfNeeded() async throws -> UUID? {
        guard profileDraft.transportType == .socks5TLS else {
            return nil
        }

        let username = profileDraft.proxyUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = profileDraft.proxyPassword

        guard !username.isEmpty else {
            return nil
        }

        let payload = try JSONEncoder().encode(
            UsernamePasswordCredential(username: username, password: password)
        )

        let id = UUID()
        try await secretStore.store(secret: payload, for: id)
        return id
    }

    private func storePinningPolicyIfNeeded() async throws -> UUID? {
        guard let pinning = profileDraft.inlinePinningPolicy else {
            return profileDraft.parsedPinningCredentialID
        }

        let payload = try JSONEncoder().encode(pinning)
        let id = profileDraft.parsedPinningCredentialID ?? UUID()
        try await secretStore.store(secret: payload, for: id)
        return id
    }

    private func deleteIfPresent(_ id: UUID?) async throws {
        guard let id else {
            return
        }

        try await secretStore.delete(id: id)
    }

    private func applyCredentialString(_ value: String, to draft: inout ProfileDraft) {
        if let separator = value.firstIndex(of: ":") {
            draft.proxyUsername = String(value[..<separator])
            draft.proxyPassword = String(value[value.index(after: separator)...])
        } else {
            draft.proxyUsername = value
            draft.proxyPassword = ""
        }
    }
}
