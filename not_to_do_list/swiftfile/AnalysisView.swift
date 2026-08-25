import SwiftUI
import SwiftData

// MARK: - 分析画面（要件定義 v2 5.1）
//
// 重心（1.1）は「自分の失敗パターンを記録すること」。
// その集めた記録を見せるのがこの画面で、v2ではここがアプリの主役になる。
//
// 出すものは3つ:
//   1. 予測 vs 実際 — 危険シグナル（事前）と失敗理由（事後）の突き合わせ
//   2. 失敗の分布 — 曜日別・項目別
//   3. 理由の一覧 — 時系列で読み返す
struct AnalysisView: View {
    @Query(sort: \NotToDoItem.createdAt, order: .forward) private var items: [NotToDoItem]

    private var comparisons: [FailureAnalysis.Comparison] {
        FailureAnalysis.comparisons(items: items).filter { $0.hasRecords }
    }
    private var weekdayTallies: [FailureAnalysis.WeekdayTally] {
        FailureAnalysis.weekdayTallies(items: items)
    }
    private var reasons: [FailureAnalysis.ReasonEntry] {
        FailureAnalysis.allReasons(items: items)
    }
    private var totalFails: Int {
        comparisons.reduce(0) { $0 + $1.failCount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if comparisons.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            predictionSection
                            weekdaySection
                            reasonListSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("分析")
        }
    }

    // MARK: - 記録がまだ無いとき

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("記録がたまると、\nここに失敗のパターンが出ます")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
    }

    // MARK: - 1. 予測 vs 実際

    private var predictionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("予測と実際", subtitle: "先に書いた危険シグナルは、当たっていましたか？")

            ForEach(comparisons) { comparison in
                VStack(alignment: .leading, spacing: 12) {
                    // 項目名と成績
                    HStack(alignment: .firstTextBaseline) {
                        Text(comparison.title)
                            .font(.headline)
                        Spacer()
                        Text("KEEP \(comparison.keepCount) / FAIL \(comparison.failCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 予測（事前に書いた危険シグナル）
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("予測していた危険シグナル", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                            Spacer()
                            // 答え合わせ。「予測どおり」を押した回数から出している
                            if let rate = comparison.predictionHitRate {
                                Text("的中 \(comparison.matchedCount)/\(comparison.failCount)")
                                    .font(.caption2.bold())
                                    .foregroundColor(rate >= 0.5 ? .orange : .secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background((rate >= 0.5 ? Color.orange : Color.gray).opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                        if comparison.prediction.isEmpty {
                            Text("まだ書かれていません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(comparison.prediction)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    // 実際（事後に書かれた失敗理由）
                    VStack(alignment: .leading, spacing: 6) {
                        Label("実際に書いた失敗の理由", systemImage: "xmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.red)

                        if comparison.actualReasons.isEmpty {
                            Text("まだ失敗の記録はありません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(comparison.actualReasons.prefix(5)) { reason in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(reason.date, format: .dateTime.month().day())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 48, alignment: .leading)
                                    if reason.matchedPrediction {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .help("予測どおり")
                                    }
                                    Text(reason.isEmpty ? "理由なし" : reason.text)
                                        .font(.subheadline)
                                        .foregroundColor(reason.isEmpty ? .secondary : .primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if comparison.actualReasons.count > 5 {
                                Text("ほか\(comparison.actualReasons.count - 5)件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - 2. 失敗の分布（曜日別）

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("いつ崩れるか", subtitle: "曜日ごとのKEEPとFAILの数")

            VStack(alignment: .leading, spacing: 16) {
                // 曜日ごとの棒グラフ
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weekdayTallies) { tally in
                        VStack(spacing: 6) {
                            weekdayBar(for: tally)
                            Text(tally.label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 130)

                // 断定できるときだけ、傾向を一文で出す
                if let worst = FailureAnalysis.worstWeekday(from: weekdayTallies) {
                    Label(
                        "いまのところ、崩れやすいのは\(worst.label)曜日です（FAIL \(worst.failCount)件）",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    legendItem(color: .blue, label: "KEEP")
                    legendItem(color: .red, label: "FAIL")
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }

    // 1曜日ぶんの積み上げ棒。全曜日で最大の合計に合わせて高さを決める
    private func weekdayBar(for tally: FailureAnalysis.WeekdayTally) -> some View {
        let maxTotal = max(weekdayTallies.map(\.total).max() ?? 1, 1)
        let unitHeight = 90.0 / Double(maxTotal)

        return VStack(spacing: 2) {
            Spacer(minLength: 0)
            if tally.failCount > 0 {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.red)
                    .frame(height: max(Double(tally.failCount) * unitHeight, 4))
            }
            if tally.keepCount > 0 {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue)
                    .frame(height: max(Double(tally.keepCount) * unitHeight, 4))
            }
            if tally.total == 0 {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - 3. 理由の一覧

    private var reasonListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("失敗の記録", subtitle: "全部で\(totalFails)件。新しい順に読み返せます")

            VStack(spacing: 0) {
                ForEach(Array(reasons.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.itemTitle)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(entry.date, format: .dateTime.year().month().day())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 6) {
                            Text(entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? "理由なし"
                                 : entry.text)
                                .font(.subheadline)
                                .foregroundColor(
                                    entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .secondary : .primary
                                )
                                .fixedSize(horizontal: false, vertical: true)
                            if entry.isBackfilled {
                                Text("後から記録")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                    if index < reasons.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - 共通部品

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}
