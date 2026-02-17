import SwiftUI
import AegisShared

public struct ConnectionDashboardView: View {
    public let viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.snapshot.activeProfileName ?? "No profile selected")
                        .font(.title3.weight(.semibold))
                    Text(statusLabel)
                        .font(.footnote)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Button(action: toggleConnection) {
                    Text(primaryButtonLabel)
                        .font(.headline)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedProfile == nil || viewModel.isBusy)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Transport")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.transportType?.displayName ?? "-")
                }
                GridRow {
                    Text("Bytes In")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.snapshot.metrics.bytesReceived)")
                }
                GridRow {
                    Text("Bytes Out")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.snapshot.metrics.bytesSent)")
                }
                GridRow {
                    Text("Packets In")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.snapshot.metrics.packetsReceived)")
                }
                GridRow {
                    Text("Packets Out")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.snapshot.metrics.packetsSent)")
                }
                GridRow {
                    Text("Latency")
                        .foregroundStyle(.secondary)
                    Text(latencyLabel)
                }
                GridRow {
                    Text("Duration")
                        .foregroundStyle(.secondary)
                    Text(durationLabel)
                }
                GridRow {
                    Text("Capabilities")
                        .foregroundStyle(.secondary)
                    Text(capabilitySummary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var statusLabel: String {
        switch viewModel.snapshot.status {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        case .failed:
            return "Failed"
        }
    }

    private var statusColor: Color {
        switch viewModel.snapshot.status {
        case .connected:
            return .green
        case .connecting, .disconnecting:
            return .orange
        case .failed:
            return .red
        case .disconnected:
            return .secondary
        }
    }

    private var primaryButtonLabel: String {
        switch viewModel.snapshot.status {
        case .connected, .connecting:
            return "Disconnect"
        case .disconnected, .disconnecting, .failed:
            return "Connect"
        }
    }

    private var latencyLabel: String {
        guard let latency = viewModel.snapshot.metrics.latencyMilliseconds else {
            return "-"
        }
        return String(format: "%.1f ms", latency)
    }

    private var durationLabel: String {
        guard let seconds = viewModel.snapshot.metrics.duration else {
            return "-"
        }

        return String(format: "%.0f s", seconds)
    }

    private var capabilitySummary: String {
        let capabilities = viewModel.snapshot.capabilities

        let values: [String] = [
            capabilities.supportsStreams ? "streams" : nil,
            capabilities.supportsDatagrams ? "datagrams" : nil,
            capabilities.supportsUDPAssociate ? "udp-associate" : nil,
            capabilities.supportsNativeQUICStreams ? "native-quic-streams" : nil
        ]
        .compactMap { $0 }

        return values.isEmpty ? "-" : values.joined(separator: ", ")
    }

    private func toggleConnection() {
        Task {
            await viewModel.toggleConnection()
        }
    }
}
