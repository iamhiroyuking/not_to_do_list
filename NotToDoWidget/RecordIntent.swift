import AppIntents
import SwiftData
import WidgetKit

// MARK: - ウィジェットから直接記録する（要件定義 v2 4章 層1）
//
// 「アプリを開く」判断そのものが最大の関門なので、ホーム画面から
// タップ1回で記録できるようにする。アプリは起動しない。
//
// 理由の入力はここではできない。**書けない代わりに、記録は残る。**
// 要件定義 8章で「理由が空欄でも記録は成立する」と決めたのが、ここで効いている。
struct RecordIntent: AppIntent {
    static var title: LocalizedStringResource = "今日の記録をつける"
    // アプリを前面に出さずに実行する
    static var openAppWhenRun: Bool = false

    @Parameter(title: "項目")
    var itemID: String

    @Parameter(title: "我慢できたか")
    var isSuccess: Bool

    init() {}

    init(itemID: String, isSuccess: Bool) {
        self.itemID = itemID
        self.isSuccess = isSuccess
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.container.mainContext

        let descriptor = FetchDescriptor<NotToDoItem>()
        let all = (try? context.fetch(descriptor)) ?? []
        guard let item = all.first(where: { WidgetItemID.encode($0) == itemID }) else {
            return .result()
        }

        // 今日すでに記録があるなら上書きしない。
        // アプリで書いた理由つきの記録を、ウィジェットを押しただけで消してしまわないため。
        if item.recordForToday() == nil {
            item.records.append(DailyRecord(date: Date(), isSuccess: isSuccess))
            try? context.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// ウィジェットの中で項目を指す文字列。
// PersistentIdentifier をそのまま持ち回すとプロセスをまたいだ時に噛み合わないので、
// 表示名と作成日から安定した鍵を作っている。
enum WidgetItemID {
    static func encode(_ item: NotToDoItem) -> String {
        "\(item.createdAt.timeIntervalSince1970)|\(item.title)"
    }
}
