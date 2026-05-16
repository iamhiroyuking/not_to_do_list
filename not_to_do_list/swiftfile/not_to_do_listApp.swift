import SwiftUI
import SwiftData

@main
struct not_to_do_listApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
        }
        .modelContainer(for: NotToDoItem.self)
    }
}
