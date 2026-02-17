import SwiftUI
import AegisShared

public struct DiagnosticsView: View {
    public let viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Handshake Error")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.diagnostics.lastHandshakeError ?? "-")
                }
                GridRow {
                    Text("Certificate Eval")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.diagnostics.certificateEvaluationSummary ?? "-")
                }
                GridRow {
                    Text("Negotiated ALPN")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.diagnostics.negotiatedALPN ?? "-")
                }
                GridRow {
                    Text("QUIC Version")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.diagnostics.quicVersion ?? "-")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
