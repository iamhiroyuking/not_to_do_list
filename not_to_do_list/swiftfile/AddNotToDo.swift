import SwiftUI
import SwiftData

struct AddNotToDoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    // 👇 🌟 追加：危険シグナル用の変数
    @State private var warningSignal: String = ""
    
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
            }
            .navigationTitle("リストに追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        let newItem = NotToDoItem(title: title, warningSignal: warningSignal)
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
