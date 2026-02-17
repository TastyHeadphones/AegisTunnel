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
        let secret = (try? await secretStore.load(id: profile.secretID)) ?? ""
        profileDraft = ProfileDraft(profile: profile, secret: secret)
        isPresentingProfileEditor = true
    }

    public func saveProfileDraft() async {
        guard profileDraft.isValid else {
            errorMessage = "Name and host are required."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let resolvedSecretID = profileDraft.secretID ?? UUID()
            let profile = profileDraft.makeProfile(secretID: resolvedSecretID)

            try await profileRepository.saveProfile(profile)

            if profileDraft.secret.isEmpty {
                try await secretStore.delete(id: resolvedSecretID)
            } else {
                try await secretStore.store(secret: profileDraft.secret, for: resolvedSecretID)
            }

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
                try await secretStore.delete(id: profile.secretID)

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
        await transportController.connect()
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
}
