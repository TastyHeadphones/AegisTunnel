import SwiftUI
import AegisCore
import AegisShared

public struct ProfileEditorView: View {
    @Binding private var draft: ProfileDraft
    private let onSave: () -> Void
    private let onCancel: () -> Void

    public init(
        draft: Binding<ProfileDraft>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $draft.name)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Transport") {
                    Picker("Type", selection: $draft.transportType) {
                        ForEach(TransportType.allCases, id: \.self) { transportType in
                            Text(transportType.displayName).tag(transportType)
                        }
                    }

                    Toggle("Use CONNECT-IP", isOn: $draft.useConnectIP)
                        .disabled(draft.transportType != .masqueHTTP3)

                    Toggle("Enable UDP ASSOCIATE capability", isOn: $draft.enableUDPAssociate)
                        .disabled(draft.transportType != .socks5TLS)

                    Toggle("Enable QUIC datagrams", isOn: $draft.enableDatagrams)
                        .disabled(draft.transportType != .quic)
                }

                Section("Upstream Endpoint") {
                    TextField("Host", text: $draft.serverHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", value: $draft.serverPort, format: .number)
                        .keyboardType(.numberPad)

                    Picker("TLS Mode", selection: $draft.tlsMode) {
                        ForEach(TLSMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue.uppercased()).tag(mode)
                        }
                    }

                    TextField("SNI / Server Name", text: $draft.serverName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("ALPN (comma separated)", text: $draft.alpnCSV)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if draft.transportRequiresTarget {
                    Section("Target") {
                        TextField("Target Host", text: $draft.targetHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Target Port", value: $draft.targetPort, format: .number)
                            .keyboardType(.numberPad)
                    }
                }

                Section("TLS Pinning") {
                    TextField("Cert SHA-256 pins (comma separated)", text: $draft.pinnedCertificateHashesCSV)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Public Key SHA-256 pins (comma separated)", text: $draft.pinnedPublicKeyHashesCSV)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Pinning Credential ID (optional UUID)", text: $draft.pinningCredentialIDText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Credentials") {
                    TextField("Proxy Username", text: $draft.proxyUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Proxy Password", text: $draft.proxyPassword)
                    TextField("Client Identity Credential ID (UUID)", text: $draft.clientIdentityCredentialIDText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(draft.id == nil ? "New Profile" : "Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}
