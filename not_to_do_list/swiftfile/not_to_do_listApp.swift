import SwiftUI
import SwiftData

@main
struct not_to_do_listApp: App {
    // 通知とウィジェットから記録を書き込むために、コンテナを明示的に持つ
    //（要件定義 v2 4章 層1）。置き場は App Group（SharedStore）。
    static var sharedModelContainer: ModelContainer { SharedStore.container }

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            StartView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
}

// 通知の受け取り役を、アプリの起動時に登録するためだけのもの
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        NotificationManager.shared.registerCategories()
        #if DEBUG
        DevSeed.runIfRequested(container: not_to_do_listApp.sharedModelContainer)
        #endif
        return true
    }
}
