import Foundation
import SwiftData

// 「しないこと」の目標データ
@Model
final class NotToDoItem {
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var records: [DailyRecord]
    // 危険シグナル（失敗しやすい状況の事前予測）
    var warningSignal: String = ""
    // メイン3個かどうか（要件定義 v2 5.2）。ウィジェットと通知の対象を絞るためのフラグ
    var isFocused: Bool = false

    init(title: String, warningSignal: String = "", createdAt: Date = Date(), isFocused: Bool = false) {
        self.title = title
        self.warningSignal = warningSignal
        self.createdAt = createdAt
        self.isFocused = isFocused
        self.records = []
    }

    // 【便利機能】今日の記録がすでにあるかを探して返すメソッド
    func recordForToday() -> DailyRecord? {
        let calendar = Calendar.current
        return records.first { calendar.isDateInToday($0.date) }
    }

    // MARK: - 連続KEEP（要件定義 v2 3.2②）
    //
    // 「1日は転んでいい。2日続けて転んだら立て直す。」
    // KEEP以外（FAIL・理由なしFAIL・未記録のすべて）を区別せず「off」として扱い、
    // off が1日だけなら streak を据え置き、2日連続で off になった時だけ 0 にリセットする。
    // これは「今日off・前日off → リセット」という日々の更新ルールを、
    // 開始日から現在まで forward に積み上げ直したものと同じ値になる。
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let creation = calendar.startOfDay(for: createdAt)

        var keepDays: Set<Date> = []
        var recordedDays: Set<Date> = []
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            recordedDays.insert(day)
            if record.isSuccess {
                keepDays.insert(day)
            }
        }

        // 今日はまだ「日が終わっていない」ので、未記録なら判定に含めず前日までの値を返す
        let targetDay: Date
        if recordedDays.contains(today) {
            targetDay = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            targetDay = yesterday
        } else {
            return 0
        }

        guard targetDay >= creation else { return 0 }

        var streak = 0
        var previousWasOff = false
        var day = creation

        while day <= targetDay {
            if keepDays.contains(day) {
                streak += 1
                previousWasOff = false
            } else {
                // KEEP以外（FAILまたは未記録）。2日連続でここに来た時だけリセットする
                if previousWasOff {
                    streak = 0
                }
                previousWasOff = true
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return streak
    }
}

// 「できたか・できなかったか」の日々の記録データ
@Model
final class DailyRecord {
    var date: Date
    var isSuccess: Bool
    var note: String
    // 後からカレンダーで埋めた記録かどうか（要件定義 v2 3.3）。数字の救済とデータの正直さを両立させるための印
    var isBackfilled: Bool = false

    // どの目標に対する記録か
    var item: NotToDoItem?

    init(date: Date, isSuccess: Bool, note: String = "", isBackfilled: Bool = false) {
        self.date = date
        self.isSuccess = isSuccess
        self.note = note
        self.isBackfilled = isBackfilled
    }
}

// MARK: - 観測日数（要件定義 v2 3.2①）
//
// 「記録をつけた日数」。KEEPでもFAILでも増える、項目を横断した主役の数字。
// 連続KEEPと違って猶予は無く、未記録の日でそのまま連続が切れる（厳密に折れる）。
// 遡及入力（3.3）で前日ぶんを埋めた場合のみ、連続が復活する。
enum ObservationStats {
    // 対象のすべての項目から「記録がある日」を集め、今日までの連続日数と累計日数を返す
    static func compute(items: [NotToDoItem]) -> (streak: Int, total: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var recordedDays: Set<Date> = []
        for item in items {
            for record in item.records {
                recordedDays.insert(calendar.startOfDay(for: record.date))
            }
        }

        let total = recordedDays.count

        // 今日はまだ「日が終わっていない」ので、未記録なら前日までの連続を返す
        let targetDay: Date
        if recordedDays.contains(today) {
            targetDay = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            targetDay = yesterday
        } else {
            return (0, total)
        }

        guard recordedDays.contains(targetDay) else { return (0, total) }

        var streak = 0
        var day = targetDay
        while recordedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return (streak, total)
    }
}
