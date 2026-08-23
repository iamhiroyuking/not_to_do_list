import SwiftUI
import SwiftData

struct AddNotToDoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    // 👇 🌟 追加：危険シグナル用の変数
    @State private var warningSignal: String = ""
    // メインに指定するかどうか（要件定義 v2 5.2）。メインだけが通知に出る
    @State private var isFocused: Bool = false

    // すでにメイン指定されている項目の数。3個を上限の目安として案内する
    @Query private var allItems: [NotToDoItem]
    private var focusedCount: Int { allItems.filter { $0.isFocused }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：感情的なトレードをしない", text: $title)
                        .submitLabel(.done)
                } header: {
                    Text("新しくやめること")
                } footer: {
                    Text("シンプルで具体的な目標を設定しましょう。")
                }

                // 👇 🌟 追加：危険シグナルの入力欄
                Section {
                    TextField("例：負けを取り返そうと焦っている時", text: $warningSignal)
                        .submitLabel(.done)
                } header: {
                    Text("⚠️ 危険シグナル（どんな時に失敗しそう？）")
                } footer: {
                    Text("失敗しやすいパターンを事前に予測しておくことで、実際の誘惑にグッと強くなります。（空欄でもOK）")
                }

                Section {
                    Toggle("メインに設定する", isOn: $isFocused)
                } header: {
                    Text("メイン項目")
                } footer: {
                    Text("メインは通知で優先して扱われます。3個くらいまでがおすすめです（現在\(focusedCount)個）。")
                }
            }
            .navigationTitle("リストに追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        let newItem = NotToDoItem(title: title, warningSignal: warningSignal, isFocused: isFocused)
                        modelContext.insert(newItem)

                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
