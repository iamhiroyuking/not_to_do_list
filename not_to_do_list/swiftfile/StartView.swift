import SwiftUI

// アプリが今どの画面を表示すべきかを管理する列挙型
//
// 要件定義 v2 4章 層1: 起動のたびにマインドセット画面を挟むと、
// 「アプリを開く」判断そのものが記録までの摩擦になる。
// マインドセットは起動時ではなく、記録した"直後"の報酬に移した
// （NotToDoListView.presentMindsetIfNeeded を参照）。
enum AppPhase {
    case splash    // 起動時のロゴ画面
    case main      // メインのタブ画面
}

struct StartView: View {
    // 最初はスプラッシュ画面（.splash）からスタートする
    @State private var currentPhase: AppPhase = .splash

    var body: some View {
        ZStack {
            // 現在のフェーズに応じて、表示する画面を切り替える
            switch currentPhase {
            case .splash:
                splashScreen
                    .transition(.opacity) // ふわっと切り替わるアニメーション

            case .main:
                // この後作るボトムタブの親玉画面へ
                RootView()
                    .transition(.opacity)
            }
        }
    }

    // スプラッシュ画面のデザインと動き
    private var splashScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea() // ストイックな黒背景

            VStack(spacing: 20) {
                Image(systemName: "shield.slash") // 誘惑を弾くイメージのアイコン
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text("Not To Do")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(4) // 文字の間隔を少し開けてスタイリッシュに
            }
        }
        .onAppear {
            // 画面が表示されてから「0.9秒後」に自動でメイン画面へ切り替える
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentPhase = .main
                }
            }
        }
    }
}

#Preview {
    StartView()
}
