import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var items: [NotToDoItem]
    @AppStorage("currentLoginStreak") private var currentLoginStreak: Int = 0
    
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
                        
                        // 🌟 変更：選択状態によって下の表示を切り替える
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
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.3), value: currentMonth)
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
                // 🌟 修正：計算ロジックを外のメソッド（getCellDate）に任せる！
                let cellDate = getCellDate(for: date, day: day)
                
                let isTodayDate = calendar.isDateInToday(cellDate)
                let isSelected = selectedDate != nil && calendar.isDate(selectedDate!, inSameDayAs: cellDate)
                let hasRecord = hasRecordOn(day: day)
                
                VStack(spacing: 4) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: isTodayDate || isSelected ? .bold : .regular))
                        .foregroundColor(isTodayDate ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(
                                isTodayDate ? Color.red : (isSelected ? Color.gray.opacity(0.2) : Color.clear)
                            )
                        )
                    
                    if hasRecord {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
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
            }
        }
    }
    
    private func getCellDate(for monthDate: Date, day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: monthDate)
        components.day = day
        return calendar.date(from: components)!
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
                    Image(systemName: "flame.fill").font(.title).foregroundColor(.orange)
                    Text("\(currentLoginStreak)日").font(.title2.bold())
                    Text("連続ログイン").font(.caption).foregroundColor(.secondary)
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
    
    // MARK: - 🌟 3. 新規：日付をタップした時の詳細リスト表示
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
            
            // その日の記録を取得
            let dayRecords = records(for: date)
            
            if dayRecords.isEmpty {
                // 記録がない日の表示
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
                // 記録がある日のリスト表示
                ForEach(dayRecords, id: \.record.id) { data in                    HStack {
                        Text(data.item.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        // KEEP / FAIL のバッジ表示
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
    
    private func hasRecordOn(day: Int) -> Bool {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        guard let targetDate = calendar.date(from: components) else { return false }
        
        return recordsInCurrentMonth.contains { record in
            calendar.isDate(record.date, inSameDayAs: targetDate)
        }
    }
    
    // 🌟 新規：指定した日の「習慣の名前」と「記録」のセットを取得する
    private func records(for date: Date) -> [(item: NotToDoItem, record: DailyRecord)] {
        let calendar = Calendar.current
        var result: [(NotToDoItem, DailyRecord)] = []
        
        for item in items {
            // その習慣の中に、指定した日と同じ日の記録があるか探す
            if let record = item.records.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                result.append((item, record))
            }
        }
        return result
    }
    
    // MARK: - カレンダー計算用の裏側ロジック
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }
    
    // 🌟 新規：「2月15日の記録」のような文字列を作る
    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
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
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let firstDayOfMonth = Calendar.current.date(from: components)!
        return Calendar.current.component(.weekday, from: firstDayOfMonth)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: NotToDoItem.self, inMemory: true)
}
