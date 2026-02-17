import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // Placeholder only: initialize Core dependencies and transport selection here.
        // Intentionally no real packet processing, proxying, or bypass logic.

        completionHandler(nil)
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        // Placeholder only: tear down lifecycle-managed resources.
        completionHandler()
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        // Placeholder only: decode app-extension messages if needed.
        completionHandler?(nil)
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Placeholder only: pause timers or refresh loops.
        completionHandler()
    }

    override func wake() {
        // Placeholder only: resume paused resources.
    }
}
