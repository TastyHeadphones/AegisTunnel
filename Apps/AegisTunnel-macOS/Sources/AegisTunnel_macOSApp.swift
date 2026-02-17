import SwiftUI
import AegisShared
import SharedUI

@main
struct AegisTunnel_macOSApp: App {
    @State private var viewModel = AppBootstrap.makeViewModel(appIdentifier: "com.aegis.tunnel.macos")

    var body: some Scene {
        WindowGroup {
            AegisRootView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 620)
        }
    }
}
