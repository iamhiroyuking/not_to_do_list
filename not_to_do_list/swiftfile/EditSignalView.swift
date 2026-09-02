import SwiftUI
import SwiftData

// MARK: - 危険シグナルを書き直す（要件定義 v2 5.1）
//
// 危険シグナルは「いつ失敗しそうか」の**仮説**であり、記録が貯まれば答え合わせができる。
// 外れ続けているなら、仮説の方を直すのが筋。
//
// ここで大事なのは、**実際に書いた理由を材料として並べること**。
// ゼロから考え直させるのではなく、自分が過去に書いた言葉を選ぶだけで
// 新しい予測ができる。記録が予測を育てる、という循環がここで閉じる。
struct EditSignalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var item: NotToDoItem

    @State private var draft: String = ""

    /// 過去のFAIL理由（空欄は材料にならないので除く）。同じ文言は1つにまとめる
    private var pastReasons: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for record in item.records.filter({ !$0.isSuccess }).sorted(by: { $0.date > $1.date }) {
            let text = record.note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !seen.contains(text) else { continue }
            seen.insert(text)
            result.append(text)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：スマホを寝室に持ち込んだ時", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text("次に警戒すること")
                } footer: {
                    Text("「どんな時に失敗しそうか」を短く書きます。次に破ってしまった時、これが当たっていたかを記録できます。")
                }

                if !pastReasons.isEmpty {
                    Section {
                        // Form の Section の中では Button + .buttonStyle(.plain) が
                        // 反応しないことがある（.contentShape を足しても直らなかった）。
                        // 行そのものに onTapGesture を付ける形が確実。
                        ForEach(pastReasons, id: \.self) { reason in
                            HStack(spacing: 10) {
                                Image(systemName: draft == reason
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundColor(draft == reason ? .orange : .secondary)
                                Text(reason)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    draft = reason
                                }
                            }
                            // onTapGesture だけでは VoiceOver がボタンとして認識しないため明示する
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(reason)
                            .accessibilityAddTraits(draft == reason ? [.isButton, .isSelected] : .isButton)
                        }
                    } header: {
                        Text("実際に書いた理由から選ぶ")
                    } footer: {
                        Text("過去に自分が書いた言葉です。当てはまるものを押すと、そのまま次の予測になります。")
                    }
                }
            }
            .navigationTitle("危険シグナル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        item.warningSignal = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        // 自動保存に任せず明示的に書き出す（閉じた直後に別画面で読むため）
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear { draft = item.warningSignal }
        }
    }
}
