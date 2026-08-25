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
    // 事前に書いた危険シグナルのとおりだったか（要件定義 v2 5.1）。
    // 記録する画面で「予測どおり」を押した時だけ true になる。
    // 予測を「当たったか」で答え合わせできるようにするための、このアプリの中核データ。
    var matchedPrediction: Bool = false

    // どの目標に対する記録か
    var item: NotToDoItem?

    init(date: Date, isSuccess: Bool, note: String = "", isBackfilled: Bool = false, matchedPrediction: Bool = false) {
        self.date = date
        self.isSuccess = isSuccess
        self.note = note
        self.isBackfilled = isBackfilled
        self.matchedPrediction = matchedPrediction
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

// MARK: - 失敗パターンの集計（要件定義 v2 5.1「分析画面 — v2の主役」）
//
// 重心（1.1）が「自分の失敗パターンを記録すること」である以上、
// 集めた記録を見せるここがアプリの核心になる。
// 新しいテーブルは要らず、すべて既存の records から計算できる。
enum FailureAnalysis {

    // 項目ごとの「予測（危険シグナル）」と「実際（FAIL理由）」の突き合わせ
    struct Comparison: Identifiable {
        let id: PersistentIdentifier
        let title: String
        let prediction: String          // 事前に書いた危険シグナル
        let actualReasons: [Reason]     // 事後に書かれた失敗理由
        let failCount: Int
        let keepCount: Int

        // 記録が1件でもある項目か（分析に出す価値があるか）
        var hasRecords: Bool { failCount + keepCount > 0 }

        // 「予測どおり」を押して記録された失敗の数（要件定義 v2 5.1）
        var matchedCount: Int { actualReasons.filter(\.matchedPrediction).count }

        // 予測の的中率。失敗が1件も無ければ nil（率として意味を持たない）
        var predictionHitRate: Double? {
            guard failCount > 0, !prediction.isEmpty else { return nil }
            return Double(matchedCount) / Double(failCount)
        }

        var keepRate: Double {
            let total = failCount + keepCount
            guard total > 0 else { return 0 }
            return Double(keepCount) / Double(total)
        }
    }

    struct Reason: Identifiable {
        let id: PersistentIdentifier
        let date: Date
        let text: String
        let isBackfilled: Bool
        let matchedPrediction: Bool

        // 理由が空欄のFAIL。空欄でも記録は成立する（要件定義 v2 8章）が、
        // 分析の材料としては薄いので区別できるようにしておく
        var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // 曜日ごとのKEEP / FAIL件数。index 0 = 日曜（Calendar の weekday は 1=日曜）
    struct WeekdayTally: Identifiable {
        let id: Int          // 0...6
        let label: String
        let keepCount: Int
        let failCount: Int

        var total: Int { keepCount + failCount }
    }

    // MARK: 1. 予測 vs 実際

    static func comparisons(items: [NotToDoItem]) -> [Comparison] {
        items.map { item in
            let fails = item.records
                .filter { !$0.isSuccess }
                .sorted { $0.date > $1.date }

            return Comparison(
                id: item.persistentModelID,
                title: item.title,
                prediction: item.warningSignal.trimmingCharacters(in: .whitespacesAndNewlines),
                actualReasons: fails.map {
                    Reason(
                        id: $0.persistentModelID,
                        date: $0.date,
                        text: $0.note,
                        isBackfilled: $0.isBackfilled,
                        matchedPrediction: $0.matchedPrediction
                    )
                },
                failCount: fails.count,
                keepCount: item.records.filter { $0.isSuccess }.count
            )
        }
    }

    // MARK: 2. 失敗の分布（曜日別）

    static func weekdayTallies(items: [NotToDoItem]) -> [WeekdayTally] {
        let calendar = Calendar.current
        let labels = ["日", "月", "火", "水", "木", "金", "土"]

        var keeps = Array(repeating: 0, count: 7)
        var fails = Array(repeating: 0, count: 7)

        for item in items {
            for record in item.records {
                // Calendar の weekday は 1=日曜 なので 0 始まりに直す
                let index = calendar.component(.weekday, from: record.date) - 1
                guard index >= 0, index < 7 else { continue }
                if record.isSuccess {
                    keeps[index] += 1
                } else {
                    fails[index] += 1
                }
            }
        }

        return (0..<7).map { i in
            WeekdayTally(id: i, label: labels[i], keepCount: keeps[i], failCount: fails[i])
        }
    }

    // 最もFAILが多かった曜日。同数や記録ゼロなら nil（断定できないため出さない）
    static func worstWeekday(from tallies: [WeekdayTally]) -> WeekdayTally? {
        let maxFail = tallies.map(\.failCount).max() ?? 0
        guard maxFail > 0 else { return nil }
        let top = tallies.filter { $0.failCount == maxFail }
        // 1位が複数ある間は「傾向」と言えないので出さない
        guard top.count == 1 else { return nil }
        return top.first
    }

    // MARK: 3. 理由の一覧（全項目を時系列で読み返す）

    struct ReasonEntry: Identifiable {
        let id: PersistentIdentifier
        let itemTitle: String
        let date: Date
        let text: String
        let isBackfilled: Bool
    }

    static func allReasons(items: [NotToDoItem]) -> [ReasonEntry] {
        var entries: [ReasonEntry] = []
        for item in items {
            for record in item.records where !record.isSuccess {
                entries.append(
                    ReasonEntry(
                        id: record.persistentModelID,
                        itemTitle: item.title,
                        date: record.date,
                        text: record.note,
                        isBackfilled: record.isBackfilled
                    )
                )
            }
        }
        return entries.sorted { $0.date > $1.date }
    }
}
