import SwiftUI
import AegisShared

public struct LiveLogView: View {
    public let logStore: LogStore

    public init(logStore: LogStore) {
        self.logStore = logStore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Logs")
                    .font(.headline)

                Spacer()

                Button("Clear") {
                    logStore.clear()
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(logStore.entries.suffix(200).reversed())) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("[\(entry.level.rawValue.uppercased())] \(entry.category)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(entry.message)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
