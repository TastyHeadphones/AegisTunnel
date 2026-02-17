import SwiftUI
import AegisShared

public struct AegisRootView: View {
    public let viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationSplitView {
            ProfileListView(viewModel: viewModel)
        } detail: {
            VStack(spacing: 16) {
                ConnectionDashboardView(viewModel: viewModel)
                LiveLogView(logStore: viewModel.logStore)
            }
            .padding()
            .navigationTitle("Connection")
        }
        .task {
            viewModel.start()
        }
        .sheet(isPresented: $bindableViewModel.isPresentingProfileEditor) {
            ProfileEditorView(
                draft: $bindableViewModel.profileDraft,
                onSave: {
                    Task {
                        await viewModel.saveProfileDraft()
                    }
                },
                onCancel: {
                    viewModel.isPresentingProfileEditor = false
                }
            )
            .frame(minWidth: 420, minHeight: 420)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { bindableViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        bindableViewModel.errorMessage = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    bindableViewModel.errorMessage = nil
                }
            },
            message: {
                Text(bindableViewModel.errorMessage ?? "")
            }
        )
    }
}
