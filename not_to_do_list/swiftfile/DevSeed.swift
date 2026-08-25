#if DEBUG
import Foundation
import SwiftData

// MARK: - 検証用のデータを仕込む（開発ビルドだけ）
//
// 画面を手で操作して記録を積むのは手間がかかるうえ、
// 「2日連続でFAIL」のような過去にまたがる状態は作りようがない。
// 起動引数で呼べるようにして、判定ルール（3.2）を目で確かめられるようにする。
//
//     xcrun simctl launch <device> com.Hiroyuki.not-to-do-list -seed
//     xcrun simctl launch <device> com.Hiroyuki.not-to-do-list -wipe
//
// `#if DEBUG` で囲ってあるので、Releaseビルドには一切入らない。
enum DevSeed {

    static func runIfRequested(container: ModelContainer) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-seed") || args.contains("-wipe") else { return }

        let context = ModelContext(container)
        wipe(context: context)

        if args.contains("-seed") {
            seed(context: context)
        }

        try? context.save()
    }

    private static func wipe(context: ModelContext) {
        let descriptor = FetchDescriptor<NotToDoItem>()
        for item in (try? context.fetch(descriptor)) ?? [] {
            context.delete(item)
        }
    }

    private static func seed(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func day(_ ago: Int) -> Date {
            // 正午にしておく。0時ちょうどだと日付の境目でぶれることがある
            calendar.date(byAdding: .hour, value: 12, to: calendar.date(byAdding: .day, value: -ago, to: today)!)!
        }

        // ① 順調に続いている項目（KEEPが5日連続）
        let steady = NotToDoItem(
            title: "SNSを寝る前に見ない",
            warningSignal: "スマホを寝室に持ち込んだ時",
            createdAt: day(6),
            isFocused: true
        )
        for ago in [5, 4, 3, 2, 1] {
            steady.records.append(DailyRecord(date: day(ago), isSuccess: true))
        }

        // ② 1日転んだが立て直した項目（据え置きを目で確かめる用）
        //    KEEP, FAIL, KEEP, KEEP → 連続KEEPは 3（据え置きは加算しない）
        let recovered = NotToDoItem(
            title: "夜food deliveryを頼まない",
            warningSignal: "残業で帰りが遅くなった日",
            createdAt: day(4),
            isFocused: true
        )
        recovered.records.append(DailyRecord(date: day(4), isSuccess: true))
        recovered.records.append(DailyRecord(
            date: day(3),
            isSuccess: false,
            note: "残業で帰りが遅くなった日",
            matchedPrediction: true
        ))
        recovered.records.append(DailyRecord(date: day(2), isSuccess: true))
        recovered.records.append(DailyRecord(date: day(1), isSuccess: true))

        // ③ 2日続けて折れた項目（リセットを目で確かめる用）
        let broken = NotToDoItem(
            title: "感情的なトレードをしない",
            warningSignal: "負けを取り返そうと焦っている時",
            createdAt: day(5),
            isFocused: false
        )
        broken.records.append(DailyRecord(date: day(5), isSuccess: true))
        broken.records.append(DailyRecord(date: day(4), isSuccess: true))
        // 「予測どおり」を押した記録（matchedPrediction）を混ぜて、的中率の表示を確かめられるようにする
        broken.records.append(DailyRecord(date: day(3), isSuccess: false, note: "朝の下げで焦って損切りできなかった"))
        broken.records.append(DailyRecord(
            date: day(2),
            isSuccess: false,
            note: "負けを取り返そうと焦っている時",
            matchedPrediction: true
        ))
        broken.records.append(DailyRecord(date: day(1), isSuccess: false, note: ""))  // 理由なしFAIL

        // ④ 危険シグナルが未入力の項目（分析画面の「まだ書かれていません」を出す用）
        let noSignal = NotToDoItem(
            title: "会議中にメールを開かない",
            warningSignal: "",
            createdAt: day(3),
            isFocused: false
        )
        noSignal.records.append(DailyRecord(date: day(2), isSuccess: false, note: "話が長引いて手が空いた"))
        // 後から埋めた記録（カレンダーと分析の「後から記録」バッジを出す用）
        noSignal.records.append(DailyRecord(date: day(1), isSuccess: true, isBackfilled: true))

        for item in [steady, recovered, broken, noSignal] {
            context.insert(item)
        }
    }
}
#endif
