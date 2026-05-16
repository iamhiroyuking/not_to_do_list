import SwiftUI

// アプリの根幹となるタブナビゲーションのビュー
struct RootView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false // 🌟 追加
    
    var body: some View {
        TabView {
            // 1タブ目：メインのリスト画面
            NotToDoListView()
                .tabItem {
                    Label("リスト", systemImage: "checklist")
                }
            
            // 2タブ目：カレンダー画面
            CalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
            
            // 3タブ目：コラム画面
            ColumnView()
                .tabItem {
                    Label("コラム", systemImage: "book.fill")
                }
            
            // 4タブ目：設定画面
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
        .preferredColorScheme(isDarkMode ? .dark : .light) // 🌟 画面全体にテーマを適用
    }
}

#Preview {
    RootView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}
