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
    
    // 連続記録のリセット用
    @AppStorage("lastRecordDate") private var lastRecordDate: Double = 0
    @AppStorage("currentLoginStreak") private var currentLoginStreak: Int = 0
    
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
                                        minute: notificationMinute
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
                                        minute: notificationMinute
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
    
    // MARK: - データの全消去処理
    private func deleteAllData() {
        // ① 目標と記録をすべて削除
        for item in allItems {
            modelContext.delete(item)
        }
        
        // ② 保存している連続ログイン日数などをゼロに戻す
        currentLoginStreak = 0
        lastRecordDate = 0
        
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
    
    // 指定した時間（時・分）で通知をスケジュール
    func scheduleNotification(hour: Int, minute: Int) {
        // 既存の通知をクリア
        cancelNotification()
        
        let content = UNMutableNotificationContent()
        content.title = "Not To Do List"
        content.body = "今日の「やらないこと」を振り返って記録しましょう！"
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

#Preview {
    SettingsView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}

