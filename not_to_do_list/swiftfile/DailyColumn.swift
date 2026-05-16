import SwiftUI

struct DailyColumnView: View {
    // StartViewから渡される「次の画面へ進む処理」
    var onDismiss: () -> Void
    
    // 🌟 追加：マインドセットのバリエーション
    let mindsets = [
        "「やらない」を決めることは、\n「本当にやりたいこと」を\n選ぶこと。",
        "意志力はバッテリー。\n無駄な決断で消費せず、\n目標のために温存せよ。",
        "完璧主義はブレーキ。\n60点の出来でもいいから、\n一歩踏み出そう。",
        "休息もトレーニングの一部。\n最高のパフォーマンスは、\n深い睡眠から始まる。",
        "失敗はデータに過ぎない。\n分析すれば、それは\n成長へのステップに変わる。",
        "100のことに取り組むより、\n1つのことに没入せよ。",
        "その誘惑は本物か？\n脳が見せている\n「偽りの報酬」ではないか？"
    ]
    
    // 🌟 追加：ランダムに選ばれたテキストを保持する変数
    @State private var selectedMindset: String = ""
    
    var body: some View {
        ZStack {
            // 背景色（少し落ち着いたグレー系）
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // コラムっぽさを演出する引用符アイコン
                Image(systemName: "quote.opening")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.3))
                
                VStack(spacing: 16) {
                    Text("今日のマインドセット")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .tracking(2) // 文字間隔を広げて洗練された印象に
                    
                    // 🌟 変更：固定テキストから変数（selectedMindset）に変更
                    Text(selectedMindset)
                        .font(.title2)
                        .fontWeight(.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(12) // 行間を広げて読みやすく
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // ホームへ進む「決意」のボタン
                Button(action: {
                    // 📱 ボタンを押した時に「ブルッ」と軽い振動をさせる（実機のみ動作）
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    
                    // StartViewから受け取った画面遷移の処理を実行
                    onDismiss()
                }) {
                    Text("今日をコントロールする")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            // 単色ではなく、少しグラデーションにして高級感を出す
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.indigo]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5) // 影をつけて立体的に
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .padding()
        }
        // 🌟 追加：画面が表示された瞬間に、配列からランダムな言葉を選ぶ
        .onAppear {
            selectedMindset = mindsets.randomElement() ?? mindsets[0]
        }
    }
}

#Preview {
    // プレビュー用に空の処理を渡す
    DailyColumnView(onDismiss: {})
}
