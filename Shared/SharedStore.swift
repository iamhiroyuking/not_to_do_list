import Foundation
import SwiftData

// MARK: - アプリとウィジェットで同じデータを見るための置き場
//
// ウィジェットは別プロセスなので、アプリの標準の保存場所には触れない。
// App Group のコンテナに store を置いて、両方から同じファイルを開く。
//
// **アプリ側の保存場所が変わる。** App Group に移す前のデータは引き継がれない。
// まだ配布していない段階なので移行処理は書いていないが、
// 一度でも配布したあとにこの識別子を変えると、利用者の記録が消える。
enum SharedStore {
    /// アプリとウィジェットの両方の entitlements に書いてある識別子と一致させること
    static let appGroupID = "group.com.Hiroyuki.not-to-do-list"

    static let container: ModelContainer = {
        let schema = Schema([NotToDoItem.self, DailyRecord.self])

        // App Group が使える時はそちらに置く。
        // 使えない場合（entitlements が無い等）でもアプリが起動しなくならないよう、
        // 既定の場所に落とす。その場合ウィジェットとは共有されない。
        let configuration: ModelConfiguration
        if FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID)
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("ModelContainerを作れませんでした: \(error)")
        }
    }()

    /// ウィジェットに出す対象（メイン指定の項目）。多すぎても置き場が無いので上限を設ける
    static func focusedItems(limit: Int = 3) -> [NotToDoItem] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<NotToDoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let focused = all.filter(\.isFocused)
        // メインが1つも無いなら、先頭から埋める（何も出ないウィジェットは役に立たない）
        return Array((focused.isEmpty ? all : focused).prefix(limit))
    }
}
