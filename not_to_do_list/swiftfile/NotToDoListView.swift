import SwiftUI
import SwiftData

// UI確認用のダミーデータ構造体
struct DummyItem: Identifiable {
    let id = UUID()
    let title: String
    let streak: Int // 連続達成日数
    var status: TodayStatus
}

// 今日の記録ステータス
enum TodayStatus {
    case unrecorded // まだ記録していない
    case success    // 我慢できた！
    case failure    // やってしまった…
}

struct NotToDoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotToDoItem.createdAt, order: .forward) private var items: [NotToDoItem]
    @State private var showingAddItemSheet = false
    
    // ストリーク（連続日数）と最後に記録した日を保存する変数
    @AppStorage("currentLoginStreak") private var currentLoginStreak: Int = 0
    @AppStorage("lastRecordDate") private var lastRecordDate: Double = 0
    // お祝いポップアップを出すかどうかのフラグ
    @State private var showStreakCelebration = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("右上の「＋」から\nやめたい習慣を追加しましょう")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            ZStack {
                                // 画面遷移のリンク（矢印アイコンが邪魔にならないように透明にする裏技です）
                                NavigationLink(destination: NotToDoDetailView(item: item)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                // 今までの行のデザイン
                                NotToDoRowView(item: item, onRecord: {
                                    handleRecordAction()
                                })
                            }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            // 👇 ここを .onDelete から .swipeActions に変更！
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        // ゴミ箱アイコンを指定
                                        Label("削除", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            // リセットする
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    // もし今日の記録がすでに存在している場合のみ、リセットボタンを表示する
                                    if item.recordForToday() != nil {
                                        Button {
                                            resetTodayRecord(for: item)
                                        } label: {
                                            Label("リセット", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
                if showStreakCelebration {
                    // 1. 後ろを少し暗くする（タップで閉じる機能付き）
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showStreakCelebration = false
                            }
                        }
                    
                    // 2. お祝いのカード本体（このあと下で作ります）
                    streakCelebrationCard
                    // ポップアップが出る時のフワッとしたアニメーション
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .navigationTitle("しないことリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItemSheet = true }) {
                        Image(systemName: "plus").fontWeight(.bold)
                    }
                }
            }
            /*.toolbar {
                // 👇 追加：テスト用のリセットボタン（左上）
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("リセット(テスト)") {
                        // ストリークと日付のデータを強制的に空っぽにする
                        currentLoginStreak = 0
                        lastRecordDate = 0
                        showStreakCelebration = false
                    }
                    .foregroundColor(.red)
                }
            }*/
            .sheet(isPresented: $showingAddItemSheet) {
                AddNotToDoView()
            }
        }
    }
    
    // 👇 削除メソッドも少しだけ書き換え（IndexSetではなく、Itemを直接受け取る）
    private func deleteItem(_ item: NotToDoItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }
    // リセットメソッド
    private func resetTodayRecord(for item: NotToDoItem) {
        // 今日の記録が存在するかチェック
        if let todayRecord = item.recordForToday() {
            withAnimation {
                // 1. 親（item）の配列から直接削除して、UIを即座に更新させる（追加）
                if let index = item.records.firstIndex(of: todayRecord) {
                    item.records.remove(at: index)
                }
                
                // 2. データベースからも完全に削除する
                modelContext.delete(todayRecord)
            }
        }
    }
    // MARK: - 記録時のストリーク判定ロジック
    private func handleRecordAction() {
        let calendar = Calendar.current
        let today = Date()
        let lastDate = Date(timeIntervalSince1970: lastRecordDate)
        
        // ① まだ一度も記録したことがない場合（初回）
        if lastRecordDate == 0 {
            currentLoginStreak = 1
            lastRecordDate = today.timeIntervalSince1970
            withAnimation { showStreakCelebration = true }
            return
        }
        
        // ② 今日すでに別の習慣で記録をつけている場合（何もしない）
        if calendar.isDateInToday(lastDate) {
            return
        }
        
        // ③ 昨日の記録がある場合（連続達成！）
        if calendar.isDateInYesterday(lastDate) {
            currentLoginStreak += 1
            lastRecordDate = today.timeIntervalSince1970
            withAnimation { showStreakCelebration = true }
            return
        }
        
        // ④ 記録が途切れてしまった場合（1日からリセットして再スタート！）
        currentLoginStreak = 1
        lastRecordDate = today.timeIntervalSince1970
        withAnimation { showStreakCelebration = true }
    }
    
    private var streakCelebrationCard: some View {
        VStack(spacing: 20) {
            // 1日目か、2日目以降かでメッセージを変える
            Text(currentLoginStreak == 1 ? "今日からスタート！" : "連続記録更新！")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("🔥")
                .font(.system(size: 70))
            // 少し揺れるようなエフェクトを入れるとリッチになります
                .symbolEffect(.bounce, value: showStreakCelebration)
            
            Text("\(currentLoginStreak)日目")
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(.primary)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showStreakCelebration = false
                }
            }) {
                Text("閉じる")
                    .font(.headline).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(16)
            }
            .padding(.top, 10)
        }
        .padding(32)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(40) // 画面端からの余白
    }
}

// 1行分のデザイン（本物のデータを受け取る）
struct NotToDoRowView: View {
    // データベース保存用
    @Environment(\.modelContext) private var modelContext
    
    // SwiftDataのモデルをそのまま監視する
    @Bindable var item: NotToDoItem
    var onRecord: () -> Void
    // 👇 🌟 追加：アラートを出すためのスイッチと、入力された理由を入れる箱
    @State private var showingFailAlert = false
    @State private var failReason = ""
    
    var body: some View {
        // 今日の記録がすでにあるかチェックする
        let todayRecord = item.recordForToday()
        
        HStack {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // ① 習慣の名前
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // 👇 🌟 変更：ストリークと危険シグナルを「横（HStack）」に並べる！
                    HStack(spacing: 12) { // 12はストリークとシグナルの間の余白です
                        
                        // 🔥 左側：ストリーク（連続記録）
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(item.currentStreak > 0 ? .orange : .gray)
                            Text("\(item.currentStreak)日連続")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        .layoutPriority(1) // 👈 これをつけると、文字が「...」で潰れなくなります！
                        
                        // ⚠️ 右側：危険シグナル（入力されている時だけ表示）
                        if !item.warningSignal.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text(item.warningSignal)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1) // 長い時は「...」で省略
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 右側のボタン表示切り替え
            if let record = todayRecord {
                // すでに今日の記録がある場合
                if record.isSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("KEEP").font(.subheadline.bold())
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("FAIL").font(.subheadline.bold())
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
                }
            } else {
                // 今日の記録がまだない場合
                HStack(spacing: 12) {
                    // 失敗ボタン
                    Button(action: {
                        showingFailAlert = true //　アラートを出す
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain) // 当たり判定を丸の中に限定
                    
                    // 成功ボタン
                    Button(action: {
                        let newRecord = DailyRecord(date: Date(), isSuccess: true)
                        item.records.append(newRecord)
                        onRecord()
                    }) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        // 👇 🌟 追加：ここから下がアラート（ポップアップ）の画面！
        .alert("失敗の記録", isPresented: $showingFailAlert) {
            // テキスト入力欄
            TextField("理由（例: スマホを寝室に持ち込んだ等）", text: $failReason)
            
            // キャンセルボタン
            Button("キャンセル", role: .cancel) {
                failReason = "" // 入力をクリア
            }
            
            // 記録するボタン
            Button("記録する", role: .destructive) {
                // ここで初めて、理由（note）と一緒に失敗記録を保存する！
                let newRecord = DailyRecord(date: Date(), isSuccess: false, note: failReason)
                item.records.append(newRecord)
                
                onRecord()      // ストリーク更新などの処理を呼ぶ
                failReason = "" // 次のために空っぽに戻しておく
            }
        } message: {
            Text("何が原因で破ってしまいましたか？次に活かすためにメモしておきましょう。（空欄でもOK）")
        }
    }
}

#Preview {
    NotToDoListView()
        .modelContainer(for: NotToDoItem.self, inMemory: true) // プレビュー用の仮データベース
}
