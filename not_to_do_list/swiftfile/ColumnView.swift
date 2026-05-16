import SwiftUI
import WebKit

// MARK: - Data Model
struct ColumnItem: Codable, Identifiable {
    var id = UUID()
    let title: String
    let subtitle: String
    let htmlFile: String
    let iconName: String   // 🌟 SF Symbolsの名前
    let themeColor: String // 🌟 色の名前
    
    enum CodingKeys: String, CodingKey {
        case title, subtitle, htmlFile, iconName, themeColor
    }
}

// MARK: - HTML Viewer
struct HTMLView: UIViewRepresentable {
    let fileName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let htmlURL = Bundle.main.url(forResource: fileName, withExtension: "html") {
            let directoryURL = htmlURL.deletingLastPathComponent()
            uiView.loadFileURL(htmlURL, allowingReadAccessTo: directoryURL)
        } else {
            let errorHtml = "<html><body><h2 style='color:red;'>🚨 \(fileName).html Not Found</h2></body></html>"
            uiView.loadHTMLString(errorHtml, baseURL: nil)
        }
    }
}

// MARK: - Main View
struct ColumnView: View {
    @State private var problemData: [ColumnItem] = []
    @State private var actionData: [ColumnItem] = []
    @State private var otherData: [ColumnItem] = []
    
    @Namespace private var animationNamespace
    @State private var selectedItem: ColumnItem? = nil
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 35) {
                        ColumnSection(title: "問題を知ろう", items: problemData, namespace: animationNamespace) { select($0) }
                        ColumnSection(title: "行動を知ろう", items: actionData, namespace: animationNamespace) { select($0) }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("コラム")
            }
            .scaleEffect(selectedItem != nil ? 0.92 : 1.0)
            .blur(radius: selectedItem != nil ? 5 : 0)
            .disabled(selectedItem != nil)
            
            if let item = selectedItem {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { deselect() }
                
                DetailView(item: item, namespace: animationNamespace, dragOffset: $dragOffset) {
                    deselect()
                }
            }
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .onAppear { loadAllData() }
    }
    
    private func select(_ item: ColumnItem) {
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            selectedItem = item
        }
    }
    
    private func deselect() {
        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.9, blendDuration: 0)) {
            selectedItem = nil
            dragOffset = .zero
        }
    }
    
    private func loadAllData() {
        problemData = loadData(filename: "problemColumn")
        actionData = loadData(filename: "actionColumn")
    }
    
    private func loadData(filename: String) -> [ColumnItem] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ColumnItem].self, from: data)
        } catch {
            print("🚨 JSON Error (\(filename)): \(error)")
            return []
        }
    }
}

// MARK: - Section View
struct ColumnSection: View {
    let title: String
    let items: [ColumnItem]
    var namespace: Namespace.ID
    let onTap: (ColumnItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .padding(.horizontal, 22)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 0) {
                            
                            // 🌟 差し替えた上半分：ビジュアルエリア 🌟
                            ZStack {
                                let baseColor = getColor(from: item.themeColor)
                                
                                LinearGradient(
                                    colors: [baseColor.opacity(0.6), baseColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: item.iconName)
                                            .font(.system(size: 30, weight: .semibold))
                                            .foregroundColor(baseColor)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            }
                            .frame(height: 140)
                            .clipped()
                            
                            // --- 下半分：テキストエリア ---
                            VStack(alignment: .leading, spacing: 10) {
                                Text(title.replacingOccurrences(of: "を知ろう", with: ""))
                                    .font(.caption2.bold())
                                    .foregroundColor(getColor(from: item.themeColor))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(getColor(from: item.themeColor).opacity(0.1))
                                    .cornerRadius(8)
                                
                                Text(item.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .lineLimit(1)
                                
                                Text(item.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.all, 18)
                        }
                        .frame(width: 280, height: 320, alignment: .topLeading)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
                        .matchedGeometryEffect(id: "bg-\(item.id)", in: namespace)
                        .onTapGesture { onTap(item) }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
    }
    
    // 🌟 ヘルパー関数を構造体内に配置 🌟
    func getColor(from string: String) -> Color {
        switch string {
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        case "pink": return .pink
        case "blue": return .blue
        case "green": return .green
        case "teal": return .teal
        case "mint": return .mint   // 追加
        case "cyan": return .cyan   // 追加
        default: return .gray
        }
    }
}

// MARK: - Detail View
struct DetailView: View {
    let item: ColumnItem
    var namespace: Namespace.ID
    @Binding var dragOffset: CGSize
    var onClose: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(UIColor.systemBackground))
                .matchedGeometryEffect(id: "bg-\(item.id)", in: namespace)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 15)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.title).font(.title2).bold()
                        Text(item.subtitle).font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
                .padding(25)
                
                HTMLView(fileName: item.htmlFile)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
        .scaleEffect(dragOffset.height > 0 ? 1 - (dragOffset.height / 1200) : 1)
        .gesture(
            DragGesture().onChanged { value in
                if value.translation.height > 0 { dragOffset = value.translation }
            }
                .onEnded { value in
                    if value.translation.height > 100 { onClose() }
                    else { withAnimation(.spring()) { dragOffset = .zero } }
                }
        )
    }
}

#Preview {
    ColumnView()
}
