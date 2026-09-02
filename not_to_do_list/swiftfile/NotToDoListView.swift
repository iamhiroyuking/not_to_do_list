import SwiftUI
import SwiftData

struct NotToDoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotToDoItem.createdAt, order: .forward) private var items: [NotToDoItem]
    @State private var showingAddItemSheet = false

    // お祝いポップアップを出すかどうかのフラグ
    @State private var showRecordCelebration = false
    // お祝いカードに出す観測日数（記録した瞬間の値をそのまま使う）
    @State private var celebrationStreak = 0
    // その日のお祝いを出したかどうか。
    // 記録のたびに出すと、項目の数だけモーダルを閉じさせることになり、
    // 層1（入力コストを下げる）と層2（報酬を返す）が喧嘩する。1日1回に絞る。
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: Double = 0

    // 記録直後のマインドセット画面（要件定義 v2 4章 層2）。1日1回だけ出す
    @AppStorage("lastMindsetShownDate") private var lastMindsetShownDate: Double = 0
    @State private var showingMindset = false

    // メインに指定された項目（上に固定して表示する）
    private var focusedItems: [NotToDoItem] { items.filter { $0.isFocused } }
    // それ以外の項目
    private var otherItems: [NotToDoItem] { items.filter { !$0.isFocused } }

    // 今日すでに記録した項目の数
    private var recordedTodayCount: Int {
        items.filter { $0.recordForToday() != nil }.count
    }
    private var isTodayComplete: Bool {
        !items.isEmpty && recordedTodayCount == items.count
    }

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
                        // 主役の数字（観測日数）と今日の進み具合を、いちばん上に置く。
                        // 要件定義 3.2① で観測日数を「主役」と決めたのに、
                        // 画面では 🔥連続KEEP しか出ておらず主役が主役になっていなかった。
                        todaySummary
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 14, trailing: 16))

                        // メイン（要件定義 v2 5.2）を上に固定する。
                        // SwiftDataの @Query は Bool で並べ替えられない（Bool は Comparable でない）ため、
                        // 取得後にここで2つに振り分けている。
                        if !focusedItems.isEmpty {
                            Section {
                                ForEach(focusedItems) { item in
                                    itemRow(for: item)
                                }
                            } header: {
                                sectionHeader("メイン", systemImage: "star.fill", color: .orange)
                            }
                        }

                        if !otherItems.isEmpty {
                            Section {
                                ForEach(otherItems) { item in
                                    itemRow(for: item)
                                }
                            } header: {
                                // メインが1つも無いときは、ただのリストとして見せる
                                if focusedItems.isEmpty {
                                    EmptyView()
                                } else {
                                    sectionHeader("そのほか", systemImage: "list.bullet", color: .secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                if showRecordCelebration {
                    // 1. 後ろを少し暗くする（タップで閉じる機能付き）
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeCelebration()
                        }

                    // 2. お祝いのカード本体
                    recordCelebrationCard
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .navigationTitle("しないことリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItemSheet = true }) {
                        Image(systemName: "plus").fontWeight(.bold)
                    }
                    .accessibilityLabel("新しい「しないこと」を追加")
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddNotToDoView()
            }
            .fullScreenCover(isPresented: $showingMindset) {
                DailyColumnView(onDismiss: {
                    showingMindset = false
                })
            }
        }
    }

    // MARK: - 今日の要約（主役の数字と進み具合）

    private var todaySummary: some View {
        let stats = ObservationStats.compute(items: items)

        return HStack(spacing: 14) {
            // 主役の数字（観測日数）。炎ではなく「積み上がる」記号を割り当てている
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(stats.streak)日")
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("連続で記録中")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider().frame(height: 30)

            // 今日の進み具合。「あと何を記録すればいいか」が一目で分かるようにする
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("今日の記録")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recordedTodayCount)/\(items.count)")
                        .font(.caption.bold())
                        .monospacedDigit()
                        .foregroundColor(isTodayComplete ? .blue : .primary)
                    if isTodayComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                ProgressView(
                    value: Double(recordedTodayCount),
                    total: Double(max(items.count, 1))
                )
                .tint(isTodayComplete ? .blue : .orange)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // リストの1行。メイン／そのほかの両セクションで同じものを使う
    @ViewBuilder
    private func itemRow(for item: NotToDoItem) -> some View {
        ZStack {
            // 画面遷移のリンク（矢印アイコンが邪魔にならないように透明にする裏技です）
            NavigationLink(destination: NotToDoDetailView(item: item)) {
                EmptyView()
            }
            .opacity(0)

            NotToDoRowView(item: item, onRecord: {
                handleRecordAction()
            })
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("削除", systemImage: "trash")
            }
            .tint(.red)
        }
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

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundColor(color)
            Text(title)
        }
        .font(.caption.bold())
        .textCase(nil)
    }

    private func deleteItem(_ item: NotToDoItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }

    // リセットメソッド
    private func resetTodayRecord(for item: NotToDoItem) {
        if let todayRecord = item.recordForToday() {
            withAnimation {
                if let index = item.records.firstIndex(of: todayRecord) {
                    item.records.remove(at: index)
                }
                modelContext.delete(todayRecord)
            }
        }
    }

    // MARK: - 記録された時の処理
    //
    // 要件定義 v2 1.1: 主役は「記録できたこと」。KEEP/FAILを問わず、
    // 記録が入力された時点でお祝いを出す（何を祝ったのかは3.2①の観測日数）。
    private func handleRecordAction() {
        let stats = ObservationStats.compute(items: items)
        celebrationStreak = stats.streak

        // 記録のたびにモーダルを出すと、項目が4つあれば4回閉じさせることになる。
        // 報酬が入力の邪魔をしていたので、1日1回だけに絞った。
        // 数字そのものは todaySummary に常に出ているので、報酬は消えていない。
        let calendar = Calendar.current
        let shownDate = Date(timeIntervalSince1970: lastCelebrationDate)
        guard !calendar.isDateInToday(shownDate) else { return }

        lastCelebrationDate = Date().timeIntervalSince1970
        withAnimation { showRecordCelebration = true }
    }

    private func closeCelebration() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showRecordCelebration = false
        }
        presentMindsetIfNeeded()
    }

    // 層2：報酬（マインドセット）は記録の"後"に置く。1日1回だけ
    private func presentMindsetIfNeeded() {
        let calendar = Calendar.current
        let lastDate = Date(timeIntervalSince1970: lastMindsetShownDate)
        guard !calendar.isDateInToday(lastDate) else { return }

        lastMindsetShownDate = Date().timeIntervalSince1970
        showingMindset = true
    }

    private var recordCelebrationCard: some View {
        VStack(spacing: 20) {
            Text("記録した。それがいちばん難しい。")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, value: showRecordCelebration)

            Text("\(celebrationStreak)日連続で記録中")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(.primary)

            Button(action: closeCelebration) {
                Text("閉じる")
                    .font(.headline).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.top, 10)
        }
        .padding(32)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(40)
    }
}

// 1行分のデザイン（本物のデータを受け取る）
struct NotToDoRowView: View {
    // データベース保存用
    @Environment(\.modelContext) private var modelContext

    // SwiftDataのモデルをそのまま監視する
    @Bindable var item: NotToDoItem
    var onRecord: () -> Void
    // 失敗の記録はアラートではなく画面で行う（RecordFailView）。
    // 危険シグナルをその場で見せたいので、1行のテキスト欄では足りなかった。
    @State private var showingFailSheet = false

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

                    // 🔥 連続KEEP と ⚠️ 危険シグナルを横に並べる
                    HStack(spacing: 12) {

                        // 🔥 左側：連続KEEP（項目ごとの成績。要件定義 v2 3.2②）
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(item.currentStreak > 0 ? .orange : .gray)
                            Text("\(item.currentStreak)日連続KEEP")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        .layoutPriority(1)

                        // ⚠️ 右側：危険シグナル（入力されている時だけ表示）
                        if !item.warningSignal.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text(item.warningSignal)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
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
                        showingFailSheet = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("FAIL。今日は破ってしまった")

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
                    .accessibilityLabel("KEEP。今日は我慢できた")
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingFailSheet) {
            RecordFailView(item: item) { reason, matched in
                // 理由は空欄でもよい（要件定義 v2 8章）。入力した事実そのものに価値がある
                let newRecord = DailyRecord(
                    date: Date(),
                    isSuccess: false,
                    note: reason,
                    matchedPrediction: matched
                )
                item.records.append(newRecord)
                onRecord()
            }
        }
    }
}

#Preview {
    NotToDoListView()
        .modelContainer(for: NotToDoItem.self, inMemory: true) // プレビュー用の仮データベース
}
