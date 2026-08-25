// 連続KEEPと観測日数の判定を検証する。
//
// このプロジェクトにはXCTestのターゲットが無いため、依存なしで走る単体スクリプトにしてある。
//
//     swift Tests/StreakLogicTests.swift
//
// Models.swift の currentStreak / ObservationStats.compute と同じアルゴリズムを
// SwiftData抜きで移植したもの。ロジックを変えたら両方を直すこと。

import Foundation

// MARK: - 検証対象のアルゴリズム（Models.swift と同じ）

func currentStreak(keepDays: Set<Date>, recordedDays: Set<Date>, creation: Date, today: Date) -> Int {
    let calendar = Calendar.current

    // 今日はまだ「日が終わっていない」ので、未記録なら判定に含めず前日までで見る
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
            // KEEP以外（FAIL・理由なしFAIL・未記録）。2日連続でここに来た時だけリセット
            if previousWasOff { streak = 0 }
            previousWasOff = true
        }
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
    }
    return streak
}

func observationStreak(recordedDays: Set<Date>, today: Date) -> Int {
    let calendar = Calendar.current
    let targetDay: Date
    if recordedDays.contains(today) {
        targetDay = today
    } else if let y = calendar.date(byAdding: .day, value: -1, to: today) {
        targetDay = y
    } else { return 0 }

    guard recordedDays.contains(targetDay) else { return 0 }

    var streak = 0
    var day = targetDay
    while recordedDays.contains(day) {
        streak += 1
        guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
        day = prev
    }
    return streak
}

// MARK: - テストの土台

let cal = Calendar.current
let today = cal.startOfDay(for: Date())
func d(_ ago: Int) -> Date { cal.date(byAdding: .day, value: -ago, to: today)! }

var passed = 0, failed = 0
func check(_ name: String, _ actual: Int, _ expected: Int) {
    if actual == expected {
        passed += 1
        print("  ✅ \(name) = \(actual)")
    } else {
        failed += 1
        print("  ❌ \(name): 期待 \(expected) / 実際 \(actual)")
    }
}

// MARK: - 連続KEEP（要件定義 v2 3.2②）
//
// ルール: KEEPは+1。KEEP以外は「据え置き」（増えないが折れない）。
//        KEEP以外が2日続いた時点で0にリセット。
// 「据え置き」は増えないので、KEEP,FAIL,KEEP は 3 ではなく 2 になる。

print("=== 連続KEEP（要件定義 v2 3.2②）===")

check("KEEP×3日連続",
      currentStreak(keepDays: [d(2), d(1), d(0)], recordedDays: [d(2), d(1), d(0)],
                    creation: d(2), today: today), 3)

check("KEEP,KEEP,FAIL → 据え置き",
      currentStreak(keepDays: [d(2), d(1)], recordedDays: [d(2), d(1), d(0)],
                    creation: d(2), today: today), 2)

check("KEEP,FAIL,FAIL → 2日連続で0",
      currentStreak(keepDays: [d(2)], recordedDays: [d(2), d(1), d(0)],
                    creation: d(2), today: today), 0)

check("KEEP,未記録,KEEP → 据え置きは加算しないので2",
      currentStreak(keepDays: [d(2), d(0)], recordedDays: [d(2), d(0)],
                    creation: d(2), today: today), 2)

check("KEEP,未記録,未記録,FAIL → 未記録2日で0",
      currentStreak(keepDays: [d(3)], recordedDays: [d(3), d(0)],
                    creation: d(3), today: today), 0)

check("KEEP,FAIL,未記録,FAIL → FAILと未記録が続いても0",
      currentStreak(keepDays: [d(3)], recordedDays: [d(3), d(2), d(0)],
                    creation: d(3), today: today), 0)

check("KEEP,FAIL,KEEP,KEEP → 1日転んでも立て直せる",
      currentStreak(keepDays: [d(3), d(1), d(0)], recordedDays: [d(3), d(2), d(1), d(0)],
                    creation: d(3), today: today), 3)

check("KEEP,FAIL,FAIL,KEEP → 折れたあと再スタート",
      currentStreak(keepDays: [d(3), d(0)], recordedDays: [d(3), d(2), d(1), d(0)],
                    creation: d(3), today: today), 1)

check("昨日KEEP・今日はまだ未記録 → 今日を罰しない",
      currentStreak(keepDays: [d(1)], recordedDays: [d(1)],
                    creation: d(1), today: today), 1)

check("記録なし",
      currentStreak(keepDays: [], recordedDays: [], creation: today, today: today), 0)

// MARK: - 観測日数（要件定義 v2 3.2①）
//
// 連続KEEPと違って猶予は無く、未記録の日でそのまま連続が切れる。
// 「連続KEEPは寛容に、観測日数は正直に」という役割分担。

print("\n=== 観測日数（要件定義 v2 3.2①）===")

check("3日連続で記録",
      observationStreak(recordedDays: [d(2), d(1), d(0)], today: today), 3)

check("1日抜けたら切れる（猶予なし）",
      observationStreak(recordedDays: [d(2), d(0)], today: today), 1)

check("今日はまだ未記録・昨日まで2日",
      observationStreak(recordedDays: [d(2), d(1)], today: today), 2)

check("記録なし",
      observationStreak(recordedDays: [], today: today), 0)

print("\n合計: \(passed) 件成功 / \(failed) 件失敗")
if failed > 0 { exit(1) }
