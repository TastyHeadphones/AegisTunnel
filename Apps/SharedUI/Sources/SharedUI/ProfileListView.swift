import SwiftUI
import AegisCore
import AegisShared

public struct ProfileListView: View {
    public let viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List(
            selection: Binding(
                get: { viewModel.selectedProfileID },
                set: { newValue in
                    Task {
                        await viewModel.selectProfileByID(newValue)
                    }
                }
            )
        ) {
            ForEach(viewModel.profiles) { profile in
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                    Text("\(profile.serverHost):\(profile.serverPort) • \(profile.transportType.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(profile.id)
                .contextMenu {
                    Button("Edit") {
                        Task {
                            await viewModel.beginEditProfile(profile)
                        }
                    }
                    Button("Delete", role: .destructive) {
                        if let index = viewModel.profiles.firstIndex(where: { $0.id == profile.id }) {
                            Task {
                                await viewModel.deleteProfiles(at: IndexSet(integer: index))
                            }
                        }
                    }
                }
            }
            .onDelete { offsets in
                Task {
                    await viewModel.deleteProfiles(at: offsets)
                }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.beginCreateProfile()
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    if let selectedProfile = viewModel.selectedProfile {
                        Task {
                            await viewModel.beginEditProfile(selectedProfile)
                        }
                    }
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                }
                .disabled(viewModel.selectedProfile == nil)
            }
        }
    }
}
