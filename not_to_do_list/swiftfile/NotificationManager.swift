import Foundation
import SwiftData
import UserNotifications

// MARK: - 通知の組み立てとスケジュール（要件定義 v2 4章 層1・層4）
//
// このアプリでの通知は2つの役割を持つ。
//   層4「未然に防ぐ」— 危険シグナルを本文に出して、記録より前に効かせる
//   層1「入力コストを下げる」— 通知を長押しすればアプリを開かずに記録できる
//
// 「アプリを開く」判断そのものが最大の関門なので、通知から直接記録できることが要点。
final class NotificationManager {
    static let shared = NotificationManager()

    // 通知の種類と、押せるボタンの識別子
    enum Identifiers {
        static let itemCategory = "ITEM_RECORD"       // 項目に紐づく通知（KEEP/FAILが押せる）
        static let plainCategory = "PLAIN_REMINDER"   // 項目が無いときの素の通知
        static let keepAction = "ACTION_KEEP"
        static let failAction = "ACTION_FAIL"
        static let itemIDKey = "itemID"               // userInfo に入れる項目の識別子
        static let requestPrefix = "dailyNotification"
    }

    // MARK: - 許可まわり

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // 端末側の設定アプリで変更されていないか、実際の許可状態を確認する（G3）
    func refreshAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - 通知に出すボタンの登録

    // アプリ起動時に1回だけ呼ぶ。ここで登録しておかないとボタンが出ない
    func registerCategories() {
        let keep = UNNotificationAction(
            identifier: Identifiers.keepAction,
            title: "KEEP（我慢できた）",
            options: []
        )

        // FAILは理由を書けるようにする。ただし空欄のまま送っても記録は成立する
        //（要件定義 v2 8章「入力した事実を優先する」）
        let fail = UNTextInputNotificationAction(
            identifier: Identifiers.failAction,
            title: "FAIL（破ってしまった）",
            options: [],
            textInputButtonTitle: "記録する",
            textInputPlaceholder: "理由（空欄でもOK）"
        )

        let itemCategory = UNNotificationCategory(
            identifier: Identifiers.itemCategory,
            actions: [keep, fail],
            intentIdentifiers: [],
            options: []
        )

        let plainCategory = UNNotificationCategory(
            identifier: Identifiers.plainCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([itemCategory, plainCategory])
    }

    // MARK: - スケジュール

    // メイン（isFocused）に指定された項目ぶんだけ通知を出す（要件定義 v2 5.2）。
    // メインが1つも無いときは、素の通知を1本だけ出す。
    @MainActor
    func rescheduleAll(hour: Int, minute: Int, context: ModelContext) {
        cancelAll()

        let descriptor = FetchDescriptor<NotToDoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let allItems = (try? context.fetch(descriptor)) ?? []
        let focused = allItems.filter { $0.isFocused }

        guard !focused.isEmpty else {
            schedulePlainNotification(hour: hour, minute: minute)
            return
        }

        // 同じ時刻に大量に鳴らすと通知そのものが無視されるようになるので、上限を設ける
        for item in focused.prefix(3) {
            scheduleItemNotification(for: item, hour: hour, minute: minute)
        }
    }

    private func scheduleItemNotification(for item: NotToDoItem, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.categoryIdentifier = Identifiers.itemCategory
        content.sound = .default

        // 層4：危険シグナルがあれば、記録を促す文言ではなく「未然に防ぐ」問いかけを出す
        let signal = item.warningSignal.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = signal.isEmpty
            ? "今日はどうでしたか？長押しで記録できます。"
            : "「\(signal)」— 今、そうなっていませんか？"

        if let encoded = Self.encode(item.persistentModelID) {
            content.userInfo = [Identifiers.itemIDKey: encoded]
        }

        add(content: content, hour: hour, minute: minute, suffix: String(describing: item.persistentModelID.hashValue))
    }

    private func schedulePlainNotification(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Not To Do"
        content.body = "今日の「やらないこと」を振り返って記録しましょう。"
        content.categoryIdentifier = Identifiers.plainCategory
        content.sound = .default

        add(content: content, hour: hour, minute: minute, suffix: "plain")
    }

    private func add(content: UNMutableNotificationContent, hour: Int, minute: Int, suffix: String) {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(Identifiers.requestPrefix)-\(suffix)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ 通知の追加エラー: \(error.localizedDescription)")
            }
        }
    }

    // このアプリが出した通知だけを取り消す
    func cancelAll() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Identifiers.requestPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - 項目の識別子を userInfo に載せるための変換

    static func encode(_ id: PersistentIdentifier) -> String? {
        guard let data = try? JSONEncoder().encode(id) else { return nil }
        return data.base64EncodedString()
    }

    static func decode(_ string: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}
