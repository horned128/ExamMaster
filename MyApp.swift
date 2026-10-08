import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-TankeiGallery") {
                TankeiGallery()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
