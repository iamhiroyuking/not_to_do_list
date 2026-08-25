import SwiftUI

// アプリの根幹となるタブナビゲーションのビュー
struct RootView: View {
    // 見た目の設定。既定は「システムに従う」（AppTheme を参照）
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .system }

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
            
            // 3タブ目：分析画面（要件定義 v2 5.1。集めた記録を見せる、v2の主役）
            AnalysisView()
                .tabItem {
                    Label("分析", systemImage: "chart.bar.doc.horizontal")
                }

            // 4タブ目：コラム画面
            ColumnView()
                .tabItem {
                    Label("コラム", systemImage: "book.fill")
                }

            // 5タブ目：設定画面
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
        .preferredColorScheme(appTheme.colorScheme) // nil なら端末の設定に従う
    }
}

#Preview {
    RootView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}
