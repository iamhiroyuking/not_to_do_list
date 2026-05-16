import Foundation
import SwiftData

// 「しないこと」の目標データ
@Model
final class NotToDoItem {
    var title: String
    var createdAt: Date
    var isActive: Bool
    
    @Relationship(deleteRule: .cascade)
    var records: [DailyRecord]
    // 危険シグナル
    var warningSignal: String = ""
    
    // initを書き換え（warningSignalを追加）
    init(title: String, warningSignal: String = "", createdAt: Date = Date(), isActive: Bool = true) {
        self.title = title
        self.warningSignal = warningSignal
        self.createdAt = createdAt
        self.isActive = isActive
        self.records = []
    }
    
    // 【便利機能】今日の記録がすでにあるかを探して返すメソッド
    func recordForToday() -> DailyRecord? {
        let calendar = Calendar.current
        return records.first { calendar.isDateInToday($0.date) }
    }
    
    // 連続記録（ストリーク）の計算用
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // ① 全ての記録を「日付（0時0分） : 成功か失敗か」の辞書（リスト）にまとめる
        var recordDict: [Date: Bool] = [:]
        for record in records {
            let startOfDay = calendar.startOfDay(for: record.date)
            recordDict[startOfDay] = record.isSuccess
        }
        
        var streak = 0
        
        // ② まず「今日」の記録をチェックする
        if let isTodaySuccess = recordDict[today] {
            if isTodaySuccess {
                streak += 1 // 今日KEEPできていたら +1
            } else {
                return 0    // 今日FAILしていたら、問答無用で 0日
            }
        }
        
        // ③ 「昨日」から過去に向かって、1日ずつ遡ってKEEPの日を探す
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // checkDate（チェックしている日）に記録があり、かつ isSuccess == true である限りループする
        while let isSuccess = recordDict[checkDate], isSuccess == true {
            streak += 1
            // さらに1日過去に戻る
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
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
    
    // どの目標に対する記録か
    var item: NotToDoItem?
    
    init(date: Date, isSuccess: Bool, note: String = "") {
        self.date = date
        self.isSuccess = isSuccess
        self.note = note
    }
}
