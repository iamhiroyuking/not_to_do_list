import SwiftData
import SwiftUI
import WidgetKit

// MARK: - ホーム画面ウィジェット（要件定義 v2 4章 層1）
//
// 記録に到達するまでの手数を、アプリを開かずに 1タップまで削る。
// 出すのはメイン指定の項目だけ（5.2）。

// 1項目ぶんの表示に必要なものだけを、タイムラインへ渡す形に固めたもの
struct WidgetItem: Identifiable {
    let id: String
    let title: String
    /// 今日の記録。まだ無ければ nil
    let todayIsSuccess: Bool?
}

struct NotToDoEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
    /// 観測日数（主役の数字。要件定義 3.2①）
    let observationStreak: Int
    let recordedToday: Int
    let totalItems: Int
}

struct NotToDoProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotToDoEntry {
        NotToDoEntry(
            date: Date(),
            items: [WidgetItem(id: "1", title: "SNSを寝る前に見ない", todayIsSuccess: nil)],
            observationStreak: 5,
            recordedToday: 0,
            totalItems: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NotToDoEntry) -> Void) {
        Task { @MainActor in
            completion(makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotToDoEntry>) -> Void) {
        Task { @MainActor in
            let entry = makeEntry()
            // 日付が変わったら「今日の記録」が白紙に戻るので、そこで作り直す
            let nextMidnight = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 0),
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(3600)

            completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> NotToDoEntry {
        let focused = SharedStore.focusedItems()
        let context = ModelContext(SharedStore.container)
        let allItems = (try? context.fetch(FetchDescriptor<NotToDoItem>())) ?? []
        let stats = ObservationStats.compute(items: allItems)

        return NotToDoEntry(
            date: Date(),
            items: focused.map {
                WidgetItem(
                    id: WidgetItemID.encode($0),
                    title: $0.title,
                    todayIsSuccess: $0.recordForToday()?.isSuccess
                )
            },
            observationStreak: stats.streak,
            recordedToday: allItems.filter { $0.recordForToday() != nil }.count,
            totalItems: allItems.count
        )
    }
}

// MARK: - 見た目

struct NotToDoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NotToDoEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    // 小さいサイズは押す場所が足りないので、数字だけを出してアプリへ渡す
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundColor(.blue)
            Text("\(entry.observationStreak)日")
                .font(.title.bold())
                .monospacedDigit()
            Text("連続で記録中")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            Text("今日 \(entry.recordedToday)/\(entry.totalItems)")
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundColor(entry.recordedToday == entry.totalItems && entry.totalItems > 0
                                 ? .blue : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日の記録")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.recordedToday)/\(entry.totalItems)")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            if entry.items.isEmpty {
                Text("アプリで「しないこと」を追加すると、ここから記録できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                ForEach(entry.items) { item in
                    row(for: item)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(for item: WidgetItem) -> some View {
        HStack(spacing: 8) {
            Text(item.title)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let isSuccess = item.todayIsSuccess {
                // 記録済み。押し間違いを防ぐため、ここではボタンを出さない
                Text(isSuccess ? "KEEP" : "FAIL")
                    .font(.caption2.bold())
                    .foregroundColor(isSuccess ? .blue : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isSuccess ? Color.blue : Color.red).opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Button(intent: RecordIntent(itemID: item.id, isSuccess: false)) {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .background(Color.red.opacity(0.12))
                .clipShape(Circle())
                .accessibilityLabel("\(item.title)、FAIL")

                Button(intent: RecordIntent(itemID: item.id, isSuccess: true)) {
                    Image(systemName: "shield.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
                .accessibilityLabel("\(item.title)、KEEP")
            }
        }
    }
}

// MARK: - 登録

struct NotToDoWidget: Widget {
    let kind = "NotToDoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotToDoProvider()) { entry in
            NotToDoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日の記録")
        .description("メインに指定した「しないこと」を、アプリを開かずに記録できます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NotToDoWidgetBundle: WidgetBundle {
    var body: some Widget {
        NotToDoWidget()
    }
}
