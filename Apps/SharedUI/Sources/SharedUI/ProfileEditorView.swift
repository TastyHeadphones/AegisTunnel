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

                Section("Server") {
                    TextField("Server Host", text: $draft.serverHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Server Port", value: $draft.serverPort, format: .number)
                        .keyboardType(.numberPad)
                }

                Section("Transport") {
                    Picker("Transport", selection: $draft.transportType) {
                        ForEach(TransportType.allCases, id: \.self) { transportType in
                            Text(transportType.displayName)
                                .tag(transportType)
                        }
                    }
                }

                Section("Secret") {
                    SecureField("Secret", text: $draft.secret)
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
