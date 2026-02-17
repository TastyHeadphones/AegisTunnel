import Foundation
import NetworkExtension
import Darwin
import AegisCore
import AegisShared

private final class PacketFlowAdapter: TunnelPacketFlow, @unchecked Sendable {
    private let packetFlow: NEPacketTunnelFlow

    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    func readPackets() async throws -> [Data] {
        await withCheckedContinuation { continuation in
            packetFlow.readPackets { packets, _ in
                continuation.resume(returning: packets)
            }
        }
    }

    func writePackets(_ packets: [Data]) async throws {
        let protocols = Array(repeating: NSNumber(value: AF_INET), count: packets.count)
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
}

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var transportController: TransportController?
    private var tunnelPipe: TunnelPipe?
    private var loggerAdapter: OSLogLogger?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let logger = LogStore(maxEntries: 500)
                let adapter = OSLogLogger(subsystem: "com.aegis.tunnel.ios.packet-tunnel", logStore: logger)
                self.loggerAdapter = adapter

                let repository = JSONProfileRepository(fileURL: profilesFileURL())
                let secretStore = KeychainSecretStore(service: "com.aegis.tunnel.ios.secrets")

                let controller = TransportController(
                    transportFactory: DefaultTransportFactory(),
                    secretStore: secretStore,
                    logger: adapter
                )

                self.transportController = controller

                let profiles = try await repository.loadProfiles()
                guard let selected = selectProfile(from: profiles, options: options) else {
                    throw TransportError(code: .invalidConfiguration, message: "No profile available for packet tunnel")
                }

                await controller.setActiveProfile(selected)
                try await controller.connect()

                let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: selected.serverHost)
                settings.mtu = 1_500 as NSNumber
                settings.ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
                settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
                settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

                try await apply(settings)

                guard let activeTransport = await controller.activeTransportInstance() else {
                    throw TransportError(code: .connectionFailed, message: "No active transport after connect")
                }

                let flowAdapter = PacketFlowAdapter(packetFlow: packetFlow)
                let pipe = TunnelPipe(flow: flowAdapter, transport: activeTransport, logger: adapter)
                try await pipe.start()
                self.tunnelPipe = pipe

                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        Task {
            if let tunnelPipe {
                await tunnelPipe.stop()
                self.tunnelPipe = nil
            }

            if let transportController {
                await transportController.shutdown()
                self.transportController = nil
            }

            completionHandler()
        }
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        Task {
            guard
                let payload = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                let action = payload["action"] as? String
            else {
                completionHandler?(nil)
                return
            }

            guard let transportController else {
                completionHandler?(nil)
                return
            }

            switch action {
            case "snapshot":
                let snapshot = await transportController.currentSnapshot()
                let data = try? JSONEncoder().encode(snapshot)
                completionHandler?(data)
            case "disconnect":
                await transportController.disconnect()
                completionHandler?(Data("ok".utf8))
            case "connect":
                do {
                    try await transportController.connect()
                    completionHandler?(Data("ok".utf8))
                } catch {
                    completionHandler?(Data(error.localizedDescription.utf8))
                }
            default:
                completionHandler?(nil)
            }
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        Task {
            if let tunnelPipe {
                await tunnelPipe.stop()
            }
            completionHandler()
        }
    }

    override func wake() {
        Task {
            guard let tunnelPipe else {
                return
            }

            try? await tunnelPipe.start()
        }
    }

    private func apply(_ settings: NEPacketTunnelNetworkSettings) async throws {
        try await withCheckedThrowingContinuation { continuation in
            setTunnelNetworkSettings(settings) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func selectProfile(from profiles: [Profile], options: [String: NSObject]?) -> Profile? {
        if
            let profileID = options?["profileID"] as? NSString,
            let uuid = UUID(uuidString: profileID as String),
            let match = profiles.first(where: { $0.id == uuid })
        {
            return match
        }

        return profiles.first
    }

    private func profilesFileURL() -> URL {
        if let appGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.aegistunnel") {
            return appGroup.appendingPathComponent("profiles.json")
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return appSupport.appendingPathComponent("AegisTunnel/profiles.json")
    }
}
