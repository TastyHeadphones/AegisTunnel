import Foundation
import AegisCore

public enum AppBootstrap {
    @MainActor
    public static func makeViewModel(appIdentifier: String) -> AppViewModel {
        let logStore = LogStore(maxEntries: 1_000)
        let logger = OSLogLogger(subsystem: appIdentifier, logStore: logStore)
        let repository = JSONProfileRepository(fileURL: profilesFileURL())
        let secretStore = KeychainSecretStore(service: "\(appIdentifier).secrets")

        let transportController = TransportController(
            transportFactory: DefaultTransportFactory(),
            secretStore: secretStore,
            logger: logger
        )

        return AppViewModel(
            profileRepository: repository,
            secretStore: secretStore,
            transportController: transportController,
            logStore: logStore
        )
    }

    private static func profilesFileURL() -> URL {
        let appSupportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return appSupportDirectory
            .appendingPathComponent("AegisTunnel", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }
}
