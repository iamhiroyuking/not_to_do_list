import Foundation
import SwiftData
import UserNotifications

// MARK: - 通知のボタンが押された時に記録を書き込む（要件定義 v2 4章 層1）
//
// 「アプリを開く」判断を挟まずに記録できるようにするための受け口。
// ここで書いた記録も、画面から入力したものとまったく同じ DailyRecord になる。
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    // アプリを開いている最中でも通知を出す（記録し忘れを拾うため）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        // KEEP / FAIL 以外（通知本体のタップなど）は、アプリを開くだけでよい
        guard actionID == NotificationManager.Identifiers.keepAction
                || actionID == NotificationManager.Identifiers.failAction else {
            completionHandler()
            return
        }

        let isSuccess = (actionID == NotificationManager.Identifiers.keepAction)
        // FAILのときだけ、入力された理由を受け取る（空欄でも記録は成立する）
        let note = (response as? UNTextInputNotificationResponse)?.userText ?? ""

        guard let encodedID = userInfo[NotificationManager.Identifiers.itemIDKey] as? String,
              let persistentID = NotificationManager.decode(encodedID) else {
            completionHandler()
            return
        }

        Task { @MainActor in
            Self.record(persistentID: persistentID, isSuccess: isSuccess, note: note)
            completionHandler()
        }
    }

    // MARK: - 書き込み

    @MainActor
    private static func record(persistentID: PersistentIdentifier, isSuccess: Bool, note: String) {
        let context = not_to_do_listApp.sharedModelContainer.mainContext

        guard let item = context.model(for: persistentID) as? NotToDoItem else { return }

        // 今日すでに記録があるなら上書きしない。
        // 画面から入力した内容を、通知を押しただけで消してしまわないため。
        guard item.recordForToday() == nil else { return }

        let record = DailyRecord(date: Date(), isSuccess: isSuccess, note: note)
        item.records.append(record)

        do {
            try context.save()
        } catch {
            print("⚠️ 通知からの記録に失敗: \(error.localizedDescription)")
        }
    }
}
