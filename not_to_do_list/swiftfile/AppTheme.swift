import SwiftUI

// 画面の見た目の設定（要件定義 v2 9章）
//
// かつては Bool 1つ（isDarkMode）で持っていたため、端末側をダークにしていても
// アプリ内トグルがオフなら必ずライトになり、「システムに従う」を選べなかった。
// 3値にして、既定を .system にしている。
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    // nil を返すと端末の設定に従う
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
