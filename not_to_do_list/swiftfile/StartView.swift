import SwiftUI

// アプリが今どの画面を表示すべきかを管理する列挙型
enum AppPhase {
    case splash    // 起動時のロゴ画面
    case column    // コラム画面
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
                
            case .column:
                DailyColumnView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentPhase = .main //ボタンが押されたらメイン画面へ
                    }
                })
                .transition(.opacity)
                
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
            // 画面が表示されてから「1.5秒後」に自動でコラム画面へ切り替える
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentPhase = .column
                }
            }
        }
    }
}

#Preview {
    StartView()
}
