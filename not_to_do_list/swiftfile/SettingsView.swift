import SwiftUI
import SwiftData
import NotificationCenter 

struct SettingsView: View {
    // 画面の見た目設定
    @AppStorage("isDarkMode") private var isDarkMode = false
    
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
                    Toggle(isOn: $isDarkMode) {
                        Label("ダークモード", systemImage: "moon.fill")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("一般")
                } footer: {
                    Text("ダークモードをオンにすると、目に優しい暗いテーマになります。")
                }
                
                // MARK: - 通知設定
                Section {
                    Toggle(isOn: $isNotificationEnabled) {
                        Label("通知をオンにする", systemImage: "bell.fill")
                    }
                    .onChange(of: isNotificationEnabled) { oldValue, newValue in
                        if newValue {
                            NotificationManager.shared.requestPermission { granted in
                                if granted {
                                    NotificationManager.shared.scheduleNotification(
                                        hour: notificationHour,
                                        minute: notificationMinute,
                                        body: warningSignalNotificationBody
                                    )
                                } else {
                                    isNotificationEnabled = false // 許可がない場合はオフに戻す
                                }
                            }
                        } else {
                            NotificationManager.shared.cancelNotification()
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
                                    
                                    NotificationManager.shared.scheduleNotification(
                                        hour: notificationHour,
                                        minute: notificationMinute,
                                        body: warningSignalNotificationBody
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("通知設定")
                } footer: {
                    Text("指定した時間に毎日の振り返り通知を受け取ります。")
                }
                .onAppear {
                    // 端末側の設定アプリでオフにされていた場合、表示をずれさせない（G3）
                    NotificationManager.shared.refreshAuthorizationStatus { isAuthorized in
                        if !isAuthorized {
                            isNotificationEnabled = false
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
    
    // MARK: - 通知に載せる危険シグナル（要件定義 v2 4章 層4）
    //
    // 「未然に防ぐ」を実装するため、記録させる文言ではなく、記録"より前"に効く問いかけを通知に出す。
    // メイン（isFocused）に登録された危険シグナルを優先し、無ければ最初に見つかったものを使う。
    private var warningSignalNotificationBody: String? {
        let signals = allItems
            .sorted { $0.isFocused && !$1.isFocused }
            .map { $0.warningSignal.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let signal = signals else { return nil }
        return "「\(signal)」— 今、そうなっていませんか？"
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

class NotificationManager {
    static let shared = NotificationManager()
    
    // 許可の取得
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // 端末側の設定アプリで変更されていないか、実際の許可状態を確認する（G3）
    func refreshAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // 指定した時間（時・分）で通知をスケジュール
    // body を渡すと、危険シグナルなど個別の文言を通知に載せられる（要件定義 v2 4章 層4）
    func scheduleNotification(hour: Int, minute: Int, body: String? = nil) {
        // 既存の通知をクリア
        cancelNotification()

        let content = UNMutableNotificationContent()
        content.title = "Not To Do List"
        content.body = body ?? "今日の「やらないこと」を振り返って記録しましょう！"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "dailyNotification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ 通知の追加エラー: \(error.localizedDescription)")
            } else {
                print("⏰ 通知が設定されました: \(hour)時\(minute)分")
            }
        }
    }
    
    // 通知のキャンセル
    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyNotification"])
    }
}
