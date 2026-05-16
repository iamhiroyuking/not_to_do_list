import SwiftUI
import SwiftData

// MARK: - 詳細・自己分析画面 (ステップ1)
struct NotToDoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // @Bindable にすることで、TextFieldで書き換えた名前が自動でデータベースに保存されます！
    @Bindable var item: NotToDoItem
    
    // 誤操作防止用のアラート表示フラグ
    @State private var showingResetAlert = false
    @State private var showingDeleteAlert = false
    // 👇 🌟 追加：失敗記録の編集・削除用
    @State private var showingDeleteRecordAlert = false
    @State private var recordToDelete: DailyRecord? = nil
    
    @State private var showingEditRecordAlert = false
    @State private var recordToEdit: DailyRecord? = nil
    @State private var editReasonText = ""
    
    // 👇 🌟 追加：いま「編集モード」かどうかを判定するスイッチ
    @State private var isEditingRecords = false
    
    
    var body: some View {
        Form {
            // ① 基本情報と編集セクション
            Section {
                TextField("習慣の名前", text: $item.title)
                    .font(.headline)
                
                HStack {
                    Text("開始日")
                    Spacer()
                    // 日付を綺麗にフォーマットして表示
                    Text(item.createdAt, style: .date)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("基本情報 (タップで名前を編集)")
            }
            
            // ⚠️ 危険シグナルセクション
            Section {
                // TextFieldなので、タップしていつでも書き換え可能です！
                // axis: .vertical をつけると、長文になった時に自動で改行してくれます
                TextField("未設定（タップして追加）", text: $item.warningSignal, axis: .vertical)
                    .foregroundColor(.primary)
            } header: {
                Text("⚠️ 危険シグナル（失敗しやすいパターン）")
                    .foregroundColor(.red) // 目立たせるために赤色に！
            } footer: {
                Text("この状態に陥った時は要注意。深呼吸して誘惑をやり過ごしましょう！")
            }
            
            
            // ② ステータス確認セクション
            Section {
                HStack {
                    Text("🔥 現在の連続記録")
                    Spacer()
                    Text("\(item.currentStreak)日")
                        .font(.headline)
                        .foregroundColor(item.currentStreak > 0 ? .orange : .primary)
                }
            } header: {
                Text("ステータス")
            }
            
            // ③ 失敗の記録セクション（純正アプリ風の編集モード対応）
            Section {
                let failRecords = item.records.filter { !$0.isSuccess }.sorted { $0.date > $1.date }
                
                if failRecords.isEmpty {
                    Text("失敗記録はありません。素晴らしい！")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(failRecords, id: \.self) { record in
                        HStack(spacing: 12) {
                            // ⛔️ 左側：マイナス（削除）ボタン（編集モード時のみ表示）
                            if isEditingRecords {
                                Button(action: {
                                    recordToDelete = record
                                    showingDeleteRecordAlert = true
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)
                                // ヌルッと現れるアニメーション
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                            
                            // 📝 中央〜右側：内容と矢印
                            Button(action: {
                                // 👇 🌟 変更：編集モードの時"だけ"、アラートを出す処理を実行する
                                if isEditingRecords {
                                    recordToEdit = record
                                    editReasonText = record.note
                                    showingEditRecordAlert = true
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.date, style: .date)
                                            .foregroundColor(.primary)
                                        Text(record.note.isEmpty ? "理由なし" : record.note)
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    // ▶︎ 右側：矢印（編集モード時のみ表示）
                                    if isEditingRecords {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                            .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                // 👇 ヘッダー部分に「編集/完了」ボタンを追加！
                HStack {
                    Text("過去の失敗記録と理由")
                    Spacer()
                    // 記録が1件以上ある時だけボタンを出す
                    if !item.records.filter({ !$0.isSuccess }).isEmpty {
                        Button(action: {
                            // アニメーション付きでスイッチを切り替える
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditingRecords.toggle()
                            }
                        }) {
                            Text(isEditingRecords ? "完了" : "編集")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .textCase(.none) // 勝手に大文字になるのを防ぐ
                        }
                    }
                }
            } footer: {
                Text("「編集」を押すと、記録の削除や理由の修正ができます。")
            }
            
            // ④ 危険な操作セクション
            Section {
                // 今日の記録がある場合のみ「リセット」を表示
                if item.recordForToday() != nil {
                    Button(action: { showingResetAlert = true }) {
                        Label("今日の記録をリセット", systemImage: "arrow.uturn.backward")
                            .foregroundColor(.orange)
                    }
                }
                
                // 削除ボタン
                Button(action: { showingDeleteAlert = true }) {
                    Label("この習慣を削除", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } header: {
                Text("操作")
            }
        }
        .navigationTitle("詳細と分析")
        .navigationBarTitleDisplayMode(.inline)
        
        // 🔄 リセット用のアラート
        .alert("今日の記録をリセット", isPresented: $showingResetAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("リセットする", role: .destructive) {
                resetTodayRecord()
            }
        } message: {
            Text("今日の記録（KEEP/FAIL）を取り消して、未入力状態に戻しますか？")
        }
        
        // 🗑️ 削除用のアラート
        .alert("習慣の削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("この習慣と、これまでの記録がすべて完全に削除されます。本当によろしいですか？")
        }
        // 📝 理由の「編集」アラート
        .alert("理由の編集", isPresented: $showingEditRecordAlert, presenting: recordToEdit) { record in
            TextField("失敗した理由", text: $editReasonText)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                // 入力された文字で上書き保存する（自動でデータベースに反映されます）
                record.note = editReasonText
            }
        } message: { _ in
            Text("失敗した理由を修正します。")
        }
        
        // 🗑️ 記録の「削除」アラート
        .alert("記録の削除", isPresented: $showingDeleteRecordAlert, presenting: recordToDelete) { record in
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                deleteSingleRecord(record)
            }
        } message: { _ in
            Text("この日の失敗記録を削除しますか？\n（連続記録の日数などは自動で再計算されます）")
        }
    }
    // 1件の失敗記録だけを削除する処理
    private func deleteSingleRecord(_ record: DailyRecord) {
        if let index = item.records.firstIndex(of: record) {
            item.records.remove(at: index)
        }
        modelContext.delete(record)
    }
    
    // 詳細画面内でのリセット処理
    private func resetTodayRecord() {
        if let todayRecord = item.recordForToday() {
            if let index = item.records.firstIndex(of: todayRecord) {
                item.records.remove(at: index)
            }
            modelContext.delete(todayRecord)
        }
        dismiss()
    }
    
    // 詳細画面内での削除処理
    private func deleteItem() {
        modelContext.delete(item)
        dismiss() // 削除したら自動でリスト画面に戻る
    }
}

#Preview {
    // プレビュー用に仮のデータを作って渡してあげる
    let dummyItem = NotToDoItem(title: "テスト用の習慣")
    
    return NavigationStack {
        NotToDoDetailView(item: dummyItem)
    }
    .modelContainer(for: NotToDoItem.self, inMemory: true) // 仮データベース
}
