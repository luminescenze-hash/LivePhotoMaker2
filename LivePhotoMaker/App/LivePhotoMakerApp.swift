import SwiftUI

@main
@MainActor
struct LivePhotoMakerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
