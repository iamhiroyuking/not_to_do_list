import SwiftUI
import SwiftData

// その日1日がどう終わったか。要件定義 v2 3.1「1日の状態は4つ」のうち、
// カレンダーの点で区別すべき3種類（未記録／KEEP／FAILの2状態）
private enum DayOutcome {
    case none    // 未記録
    case keep    // KEEP
    case fail    // FAIL（理由の有無は問わない）

    var color: Color {
        switch self {
        case .none: return .clear
        case .keep: return .blue
        case .fail: return .red
        }
    }
}

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [NotToDoItem]

    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    @State private var slideDirection: Edge = .trailing

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        calendarCard

                        if let selected = selectedDate {
                            // 日付が選択されている時は詳細リストを表示
                            detailList(for: selected)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            // 選択されていない時はサマリーを表示
                            summaryDashboard
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.3), value: selectedDate)
                    .animation(.easeInOut(duration: 0.3), value: currentMonth)
                }
            }
            .navigationTitle("カレンダー")
        }
        .onAppear {
            currentMonth = Date()
            selectedDate = nil
        }
    }

    // MARK: - 1. カレンダーカード
    private var calendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(monthYearString(for: currentMonth))
                    .font(.title2.bold())
                Spacer()
                HStack(spacing: 24) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.title3).foregroundColor(.blue)
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.title3).foregroundColor(.blue)
                    }
                }
            }
            .padding(.bottom, 8)

            let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .gray))
                        .frame(maxWidth: .infinity)
                }
            }

            calendarGrid(for: currentMonth)
                .id(monthYearString(for: currentMonth))
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection),
                    removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
                ))

            legend
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.3), value: currentMonth)
    }

    // 層3：空白（未記録）が見えることが、戻ってくる理由になる
    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, label: "KEEP")
            legendItem(color: .red, label: "FAIL")
            legendItem(color: Color.gray.opacity(0.3), label: "未記録")
            Spacer()
        }
        .padding(.top, 4)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }

    // MARK: - カレンダーグリッド
    private func calendarGrid(for date: Date) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 16) {
            let firstWeekday = firstWeekdayOfMonth(in: date)
            let emptyCount = firstWeekday - 1
            let days = daysInMonth(for: date)
            let calendar = Calendar.current

            if emptyCount > 0 {
                ForEach(100..<(100 + emptyCount), id: \.self) { _ in
                    VStack(spacing: 4) {
                        Text("").frame(width: 32, height: 32)
                        Circle().fill(Color.clear).frame(width: 6, height: 6)
                    }
                }
            }

            ForEach(1...days, id: \.self) { day in
                let cellDate = getCellDate(for: date, day: day)

                let isTodayDate = calendar.isDateInToday(cellDate)
                let isSelected = selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: cellDate)
                let outcome = dayOutcome(for: cellDate)
                let isFuture = cellDate > calendar.startOfDay(for: Date())

                VStack(spacing: 4) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: isTodayDate || isSelected ? .bold : .regular))
                        .foregroundColor(isTodayDate ? .white : (isFuture ? .secondary.opacity(0.4) : .primary))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(
                                isTodayDate ? Color.red : (isSelected ? Color.gray.opacity(0.2) : Color.clear)
                            )
                        )

                    // 未記録の日も、過去の日なら薄い点で「空白」を見せる（層3）
                    if outcome != .none {
                        Circle().fill(outcome.color).frame(width: 6, height: 6)
                    } else if !isFuture {
                        Circle().fill(Color.gray.opacity(0.25)).frame(width: 6, height: 6)
                    } else {
                        Circle().fill(Color.clear).frame(width: 6, height: 6)
                    }
                }
                .onTapGesture {
                    withAnimation {
                        if isSelected {
                            selectedDate = nil
                        } else {
                            selectedDate = cellDate
                        }
                    }
                }
                // onTapGesture だけでは VoiceOver がボタンとして認識しないため明示する
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(day: day, isToday: isTodayDate, outcome: outcome))
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func accessibilityLabel(day: Int, isToday: Bool, outcome: DayOutcome) -> String {
        let dayText = isToday ? "\(day)日、今日" : "\(day)日"
        switch outcome {
        case .keep: return "\(dayText)、KEEP"
        case .fail: return "\(dayText)、FAIL"
        case .none: return "\(dayText)、未記録"
        }
    }

    private func getCellDate(for monthDate: Date, day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: monthDate)
        components.day = day
        // 呼び出し元は daysInMonth の範囲内でしか day を渡さないため通常は失敗しないが、
        // 強制アンラップは避け、失敗時は月初日にフォールバックする
        return calendar.date(from: components) ?? calendar.startOfDay(for: monthDate)
    }

    // MARK: - 2. サマリーダッシュボード
    private var summaryDashboard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("今月のサマリー")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill").font(.title).foregroundColor(.blue)
                    Text("\(observationStreak)日").font(.title2.bold())
                    Text("連続で記録中").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "shield.fill").foregroundColor(.blue)
                        Text("\(monthlySuccessCount)回").fontWeight(.bold)
                    }
                    HStack {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text("\(monthlyFailCount)回").fontWeight(.bold)
                    }
                    Text("今月の記録数").font(.caption).foregroundColor(.secondary).padding(.top, 4)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - 3. 日付をタップした時の詳細リスト表示
    private func detailList(for date: Date) -> some View {
        VStack(spacing: 12) {
            // ヘッダー部分（日付と閉じるボタン）
            HStack {
                Text(dateString(for: date))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation { selectedDate = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(.bottom, 4)

            let dayRecords = records(for: date)
            let missing = itemsMissingRecord(on: date)

            if dayRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("この日の記録はありません")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                .padding(.vertical, 30)
            } else {
                ForEach(dayRecords, id: \.record.id) { data in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.item.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            if data.record.isBackfilled {
                                Text("後から記録")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if data.record.isSuccess {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                Text("KEEP").font(.caption.bold())
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("FAIL").font(.caption.bold())
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
                }
            }

            // 遡及入力（要件定義 v2 3.3）。前日ぶんのみ、埋め忘れの項目にだけ出す
            if Calendar.current.isDateInYesterday(date), !missing.isEmpty {
                backfillSection(for: date, missing: missing)
            }
        }
    }

    // 昨日を埋め忘れた項目に、その場でKEEP/FAILを付けられるようにする
    private func backfillSection(for date: Date, missing: [NotToDoItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("昨日の記録を埋める")
                .font(.subheadline.bold())
                .foregroundColor(.orange)

            ForEach(missing) { item in
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        backfill(item: item, date: date, isSuccess: false)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 30, height: 30)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        backfill(item: item, date: date, isSuccess: true)
                    } label: {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }

    private func backfill(item: NotToDoItem, date: Date, isSuccess: Bool) {
        withAnimation {
            let record = DailyRecord(date: date, isSuccess: isSuccess, isBackfilled: true)
            item.records.append(record)
        }
    }

    // MARK: - 本物のデータから計算する裏側ロジック

    private var recordsInCurrentMonth: [DailyRecord] {
        let calendar = Calendar.current
        let allRecords = items.flatMap { $0.records }
        return allRecords.filter { record in
            calendar.isDate(record.date, equalTo: currentMonth, toGranularity: .month)
        }
    }

    private var monthlySuccessCount: Int {
        recordsInCurrentMonth.filter { $0.isSuccess }.count
    }

    private var monthlyFailCount: Int {
        recordsInCurrentMonth.filter { !$0.isSuccess }.count
    }

    private var observationStreak: Int {
        ObservationStats.compute(items: items).streak
    }

    private func dayOutcome(for date: Date) -> DayOutcome {
        let calendar = Calendar.current
        let dayRecords = items.flatMap { $0.records }.filter { calendar.isDate($0.date, inSameDayAs: date) }
        if dayRecords.isEmpty { return .none }
        // その日のどれか1件でもFAILがあれば「FAIL」として見せる（層3は空白の可視化が目的のため、KEEP優先にはしない）
        return dayRecords.contains(where: { !$0.isSuccess }) ? .fail : .keep
    }

    // 指定した日の「習慣の名前」と「記録」のセットを取得する
    private func records(for date: Date) -> [(item: NotToDoItem, record: DailyRecord)] {
        let calendar = Calendar.current
        var result: [(NotToDoItem, DailyRecord)] = []

        for item in items {
            if let record = item.records.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                result.append((item, record))
            }
        }
        return result
    }

    // 指定した日にまだ記録が無い項目（遡及入力の対象）
    private func itemsMissingRecord(on date: Date) -> [NotToDoItem] {
        let calendar = Calendar.current
        return items.filter { item in
            !item.records.contains { calendar.isDate($0.date, inSameDayAs: date) }
        }
    }

    // MARK: - カレンダー計算用の裏側ロジック
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日の記録"
        return formatter.string(from: date)
    }

    private func changeMonth(by value: Int) {
        slideDirection = value > 0 ? .trailing : .leading
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMonth = newMonth
                selectedDate = nil
            }
        }
    }

    private func daysInMonth(for date: Date) -> Int {
        let range = Calendar.current.range(of: .day, in: .month, for: date)!
        return range.count
    }

    private func firstWeekdayOfMonth(in date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstDayOfMonth = calendar.date(from: components) ?? date
        return calendar.component(.weekday, from: firstDayOfMonth)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}
