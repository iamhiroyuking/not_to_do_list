import SwiftUI
import SwiftData
import NotificationCenter 

struct SettingsView: View {
    // 画面の見た目設定。既定は「システムに従う」（AppTheme を参照）
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    // 通知設定
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 20
    @AppStorage("notificationMinute") private var notificationMinute = 0
    
    // データ管理用
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [NotToDoItem]
    @State private var showingDeleteAlert = false

    // 記録直後のマインドセット表示日（データ全消去では一緒にリセットする）
    @AppStorage("lastMindsetShownDate") private var lastMindsetShownDate: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 一般設定
                Section {
                    Picker(selection: $appThemeRaw) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    } label: {
                        Label("外観", systemImage: "moon.fill")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("一般")
                } footer: {
                    Text("「システム」を選ぶと、端末の設定に合わせて自動で切り替わります。")
                }
                
                // MARK: - 通知設定
                Section {
                    Toggle(isOn: $isNotificationEnabled) {
                        Label("通知をオンにする", systemImage: "bell.fill")
                    }
                    .onChange(of: isNotificationEnabled) { _, newValue in
                        if newValue {
                            NotificationManager.shared.requestPermission { granted in
                                if granted {
                                    reschedule()
                                } else {
                                    isNotificationEnabled = false // 許可がない場合はオフに戻す
                                }
                            }
                        } else {
                            NotificationManager.shared.cancelAll()
                        }
                    }
                    
                    // 通知がオンの時だけピッカーを表示
                    if isNotificationEnabled {
                        DatePicker(
                            "通知時間",
                            selection: Binding(
                                get: {
                                    // 保存されている時・分からDate型を作成
                                    Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? Date()
                                },
                                set: { newDate in
                                    // 選択されたDateから時・分を抽出して保存＆再スケジュール
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                    notificationHour = components.hour ?? 20
                                    notificationMinute = components.minute ?? 0
                                    
                                    reschedule()
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("通知設定")
                } footer: {
                    Text("メインに指定した項目ごとに通知が届きます。通知を長押しすると、アプリを開かずにKEEP/FAILを記録できます。")
                }
                .onAppear {
                    // 端末側の設定アプリでオフにされていた場合、表示をずれさせない（G3）
                    NotificationManager.shared.refreshAuthorizationStatus { isAuthorized in
                        if !isAuthorized {
                            isNotificationEnabled = false
                        } else if isNotificationEnabled {
                            // メインの指定や危険シグナルが変わっている可能性があるので組み直す
                            reschedule()
                        }
                    }
                }
                
                // MARK: - アプリ情報
                Section(header: Text("このアプリについて")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        // アプリのバージョンを自動取得
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - データ管理
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("すべての記録をリセット", systemImage: "trash.fill")
                    }
                } header: {
                    Text("データ管理")
                } footer: {
                    Text("⚠️ この操作は取り消せません。アプリ内の全データが消去されます。")
                }
            }
            .navigationTitle("設定")
            
            // 🗑️ データ消去の最終確認アラート
            .alert("本当にリセットしますか？", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("リセットする", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("これまでの「やらないこと」と記録がすべて完全に消去されます。")
            }
        }
    }
    
    // 通知を今の状態で組み直す。
    // 本文（危険シグナル）や対象（メインの指定）は NotificationManager 側で決める。
    private func reschedule() {
        NotificationManager.shared.rescheduleAll(
            hour: notificationHour,
            minute: notificationMinute,
            context: modelContext
        )
    }

    // MARK: - データの全消去処理
    private func deleteAllData() {
        // ① 目標と記録をすべて削除
        for item in allItems {
            modelContext.delete(item)
        }

        // ② マインドセット表示日もゼロに戻す
        lastMindsetShownDate = 0

        print("🚨 データをすべて完全に削除しました！")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}
