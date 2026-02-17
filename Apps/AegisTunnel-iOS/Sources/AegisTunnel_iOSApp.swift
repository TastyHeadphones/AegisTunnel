import SwiftUI
import AegisShared
import SharedUI

@main
struct AegisTunnel_iOSApp: App {
    @State private var viewModel = AppBootstrap.makeViewModel(appIdentifier: "com.aegis.tunnel.ios")

    var body: some Scene {
        WindowGroup {
            AegisRootView(viewModel: viewModel)
        }
    }
}
