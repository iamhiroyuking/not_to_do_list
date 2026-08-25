import SwiftUI
import SwiftData

// MARK: - 失敗を記録する画面（要件定義 v2 4章 層4 ＋ 5.1）
//
// もとはアラート＋1行のテキスト欄だったが、2つの理由で画面に作り替えた。
//
// 1. **予測をここで見せる。** 危険シグナルはリストの小さなグレー文字に
//    埋もれていて、いちばん効くはずの瞬間＝破ってしまった直後に出てこなかった。
//    「あなたはこう予測していた」をこの場で見せることで、
//    分析画面を開かなくても 予測→観測 のループが閉じる。
//
// 2. **予測どおりなら、書かずに済ませる。** 予測の文言をそのまま理由に使えるので、
//    タップ1回で記録が終わる。入力を増やすのではなく、減らしながら
//    「予測は当たっていたか」というデータ（matchedPrediction）を取れる。
struct RecordFailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: NotToDoItem
    /// (理由, 予測どおりだったか) を返す
    let onRecord: (String, Bool) -> Void

    @State private var reason: String = ""
    @State private var matchedPrediction = false
    @FocusState private var isReasonFocused: Bool

    private var prediction: String {
        item.warningSignal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ① 予測していたこと（書いてある時だけ）
                if !prediction.isEmpty {
                    Section {
                        // Form の Section の中では Button + .buttonStyle(.plain) が
                        // 反応しないことがあるので、行に onTapGesture を付けている
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: matchedPrediction
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundColor(matchedPrediction ? .orange : .secondary)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(prediction)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("今回もこれでしたか？")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { selectPrediction() }
                    } header: {
                        Label("あなたが予測していた危険シグナル", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } footer: {
                        Text("当てはまるなら押すだけで記録できます。予測が当たったかどうかは、分析画面で振り返れます。")
                    }
                }

                // ② 自由に書く理由
                Section {
                    TextField("例：スマホを寝室に持ち込んだ", text: $reason, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($isReasonFocused)
                        .onChange(of: reason) { _, newValue in
                            // 手で書き換えたら「予測どおり」の印は外す
                            if matchedPrediction && newValue != prediction {
                                matchedPrediction = false
                            }
                        }
                } header: {
                    Text(prediction.isEmpty ? "何が原因でしたか？" : "別の理由なら、ここに書く")
                } footer: {
                    Text("空欄でも記録できます。書けなかった日も、記録したこと自体に意味があります。")
                }
            }
            .navigationTitle("失敗を記録する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("記録する") {
                        onRecord(
                            reason.trimmingCharacters(in: .whitespacesAndNewlines),
                            matchedPrediction
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func selectPrediction() {
        withAnimation(.easeInOut(duration: 0.15)) {
            if matchedPrediction {
                matchedPrediction = false
                if reason == prediction { reason = "" }
            } else {
                matchedPrediction = true
                reason = prediction
            }
        }
        isReasonFocused = false
    }
}

#Preview {
    RecordFailView(
        item: NotToDoItem(title: "SNSを寝る前に見ない", warningSignal: "スマホを寝室に持ち込んだ時"),
        onRecord: { _, _ in }
    )
}
