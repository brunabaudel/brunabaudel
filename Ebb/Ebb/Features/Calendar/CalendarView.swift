import SwiftData
import SwiftUI

struct CalendarView: View {
    let schema: SchemaConfig

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var displayMode: CalendarDisplayMode = .month
    @State private var visibleMonth = Date.now
    @State private var visibleWeekStart = Date.now
    @State private var selectedDay = Date.now
    @State private var editingEntry: SymptomEntry?

    private var calendar: Calendar { .ebbCalendar }
    private var overlay: CalendarCycleOverlay {
        cycleService.makeOverlay(from: entries)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    overviewChips
                    displayModeToggle
                    gridSection
                    legend
                    dayDetail
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingEntry) { entry in
                TapLogView(schema: schema, entry: entry)
            }
            .onAppear {
                let today = calendar.startOfDay(for: .now)
                selectedDay = today
                visibleMonth = calendar.startOfMonth(for: today)
                visibleWeekStart = calendar.startOfWeek(for: today)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(navigationTitle)
                .font(.system(.title2, design: .serif))
            Spacer()
            HStack(spacing: 18) {
                Button { navigateBackward() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Previous \(displayMode == .month ? "month" : "week")")

                Button { navigateForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Next \(displayMode == .month ? "month" : "week")")
            }
            .foregroundStyle(theme.muted)
        }
    }

    private var navigationTitle: String {
        switch displayMode {
        case .month:
            let month = visibleMonth.formatted(.dateTime.month(.wide))
            let year = visibleMonth.formatted(.dateTime.year())
            return "\(month) \(year)"
        case .week:
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: visibleWeekStart) ?? visibleWeekStart
            let startDay = visibleWeekStart.formatted(.dateTime.day())
            let endDay = weekEnd.formatted(.dateTime.day())
            let month = visibleWeekStart.formatted(.dateTime.month(.wide))
            return "\(startDay)–\(endDay) \(month)"
        }
    }

    // MARK: - Overview chips

    private var overviewChips: some View {
        HStack(spacing: 8) {
            overviewChip(
                value: "\(migraineCountInScope)",
                label: "migraines",
                accent: theme.pain
            )
            overviewChip(
                value: cycleDayLabel,
                label: "cycle day",
                accent: theme.cycle
            )
            overviewChip(
                value: daysToPeriodLabel,
                label: "days to period",
                accent: theme.text
            )
        }
        .padding(.top, 15)
    }

    private func overviewChip(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(theme.line, lineWidth: 1)
        }
    }

    private var migraineCountInScope: Int {
        switch displayMode {
        case .month:
            return overlay.migraineCount(in: entries, monthContaining: visibleMonth)
        case .week:
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: visibleWeekStart) ?? visibleWeekStart
            return entries.filter { entry in
                entry.fieldValues["migraine_present"] == .boolean(true)
                    && entry.timestamp >= visibleWeekStart
                    && entry.timestamp <= calendar.endOfDay(for: weekEnd)
            }.count
        }
    }

    private var cycleDayLabel: String {
        overlay.cycleDay(for: selectedDay).map(String.init) ?? "—"
    }

    private var daysToPeriodLabel: String {
        overlay.daysUntilNextPeriod(from: selectedDay).map(String.init) ?? "—"
    }

    // MARK: - Toggle

    private var displayModeToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "Week", mode: .week)
            toggleButton(title: "Month", mode: .month)
        }
        .padding(3)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.line, lineWidth: 1)
        }
        .padding(.top, 14)
    }

    private func toggleButton(title: String, mode: CalendarDisplayMode) -> some View {
        Button {
            displayMode = mode
            syncVisibleRangeToSelection()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(displayMode == mode ? theme.onPain : theme.muted)
                .background {
                    if displayMode == mode {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(theme.pain)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    @ViewBuilder
    private var gridSection: some View {
        switch displayMode {
        case .month:
            monthGrid
        case .week:
            weekStrip
        }
    }

    private var monthGrid: some View {
        VStack(spacing: 7) {
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(monthGridDays, id: \.self) { day in
                    monthDayCell(day)
                }
            }
        }
        .padding(.top, 18)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(rotatedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var rotatedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private func monthDayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let hasMigraine = hasMigraine(on: day)

        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(dayBackground(for: day, inMonth: inMonth))
                if overlay.isPredictedPeriod(day) {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(theme.pain.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                } else if isToday {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(theme.pain, lineWidth: 2)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(theme.line, lineWidth: 1)
                }
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(inMonth ? theme.text : theme.muted.opacity(0.35))

                if hasMigraine {
                    Circle()
                        .fill(theme.pain)
                        .frame(width: 5, height: 5)
                        .shadow(color: theme.pain.opacity(0.6), radius: 3)
                        .offset(y: 14)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(for: day, hasMigraine: hasMigraine))
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 16) {
            if overlay.anchorPeriodStart != nil {
                Text("Tap a day to see its entries. Migraines often cluster around bleeding.")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 13)
            }

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    weekDayCell(day)
                }
            }

            weekPhaseBar
        }
        .padding(.top, overlay.anchorPeriodStart == nil ? 18 : 0)
    }

    private func weekDayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let hasMigraine = hasMigraine(on: day)
        let loggedPeriod = overlay.isLoggedPeriod(day)

        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(isSelected ? theme.onPain.opacity(0.65) : theme.muted)
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? theme.onPain : theme.text)

                HStack(spacing: 3) {
                    if hasMigraine {
                        Circle()
                            .fill(isSelected ? theme.onPain : theme.pain)
                            .frame(width: 6, height: 6)
                    }
                    if loggedPeriod {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isSelected ? theme.onPain.opacity(0.8) : theme.pain.opacity(0.85))
                            .frame(width: 14, height: 4)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(weekDayBackground(for: day, isSelected: isSelected))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(weekDayBorder(for: day, isSelected: isSelected), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(for: day, hasMigraine: hasMigraine))
    }

    private var weekPhaseBar: some View {
        HStack(spacing: 9) {
            Text("luteal")
                .font(.caption2.monospaced())
                .foregroundStyle(theme.cycle)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.cycleDim)
                        .frame(width: proxy.size.width * 0.57)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.pain.opacity(0.75))
                        .frame(width: proxy.size.width * 0.43)
                }
            }
            .frame(height: 6)
            Text("menstrual")
                .font(.caption2.monospaced())
                .foregroundStyle(theme.pain)
        }
        .font(.caption2)
        .foregroundStyle(theme.muted)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    // MARK: - Legend

    private var legend: some View {
        FlowLayout(spacing: 9) {
            legendItem(icon: { Circle().fill(theme.pain).frame(width: 7, height: 7) }, label: "Migraine")
            legendItem(icon: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.cycleDim)
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(theme.cycleDim, lineWidth: 1) }
                    .frame(width: 11, height: 11)
            }, label: "Luteal (higher risk)")
            legendItem(icon: {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.pain.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 11, height: 11)
            }, label: "Period predicted")
            legendItem(icon: {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.pain, lineWidth: 2)
                    .frame(width: 9, height: 9)
            }, label: "Today")
        }
        .padding(.top, 14)
    }

    private func legendItem<Icon: View>(@ViewBuilder icon: () -> Icon, label: String) -> some View {
        HStack(spacing: 6) {
            icon()
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.muted)
        }
    }

    // MARK: - Day detail

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(.body, design: .serif))
                Spacer()
                if let phase = overlay.phase(for: selectedDay),
                   let cycleDay = overlay.cycleDay(for: selectedDay) {
                    Text("\(phase.displayName.lowercased()) · day \(cycleDay)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.cycle)
                }
            }

            let dayEntries = overlay.entries(on: selectedDay, from: entries)
            if dayEntries.isEmpty {
                Text("Nothing logged this day.")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            } else {
                ForEach(dayEntries) { entry in
                    Button { editingEntry = entry } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            EntryCard(entry: entry, schema: schema)
                            Text(DaySummaryBuilder.describe(entry, schema: schema, compact: true))
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                                .lineLimit(2)
                                .padding(.leading, 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.line, lineWidth: 1)
        }
        .padding(.top, 14)
    }

    // MARK: - Styling helpers

    private func dayBackground(for day: Date, inMonth: Bool) -> Color {
        if !inMonth { return .clear }
        if overlay.isLoggedPeriod(day) { return theme.painDim.opacity(0.55) }
        if overlay.isLuteal(day) { return theme.cycleDim }
        return .clear
    }

    private func weekDayBackground(for day: Date, isSelected: Bool) -> Color {
        if isSelected { return theme.pain }
        if overlay.isLoggedPeriod(day) { return theme.painDim.opacity(0.7) }
        if overlay.isLuteal(day) { return theme.cycleDim }
        return theme.surface
    }

    private func weekDayBorder(for day: Date, isSelected: Bool) -> Color {
        if isSelected { return theme.pain }
        if overlay.isLoggedPeriod(day) { return theme.pain.opacity(0.55) }
        return theme.line
    }

    private func hasMigraine(on day: Date) -> Bool {
        overlay.entries(on: day, from: entries).contains { $0.fieldValues["migraine_present"] == .boolean(true) }
    }

    private func dayAccessibilityLabel(for day: Date, hasMigraine: Bool) -> String {
        var parts = [day.formatted(date: .complete, time: .omitted)]
        if let phase = overlay.phase(for: day), let cycleDay = overlay.cycleDay(for: day) {
            parts.append("\(phase.displayName), cycle day \(cycleDay)")
        }
        if overlay.isLoggedPeriod(day) { parts.append("logged period") }
        if overlay.isPredictedPeriod(day) { parts.append("predicted period") }
        if hasMigraine { parts.append("migraine logged") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Navigation

    private func navigateBackward() {
        switch displayMode {
        case .month:
            if let month = calendar.date(byAdding: .month, value: -1, to: visibleMonth) {
                visibleMonth = month
            }
        case .week:
            if let week = calendar.date(byAdding: .day, value: -7, to: visibleWeekStart) {
                visibleWeekStart = week
            }
        }
    }

    private func navigateForward() {
        switch displayMode {
        case .month:
            if let month = calendar.date(byAdding: .month, value: 1, to: visibleMonth) {
                visibleMonth = month
            }
        case .week:
            if let week = calendar.date(byAdding: .day, value: 7, to: visibleWeekStart) {
                visibleWeekStart = week
            }
        }
    }

    private func syncVisibleRangeToSelection() {
        switch displayMode {
        case .month:
            visibleMonth = calendar.startOfMonth(for: selectedDay)
        case .week:
            visibleWeekStart = calendar.startOfWeek(for: selectedDay)
        }
    }

    private var monthGridDays: [Date] {
        calendar.monthGridDays(containing: visibleMonth)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: visibleWeekStart) }
    }
}

// MARK: - Display mode

private enum CalendarDisplayMode {
    case month
    case week
}

// MARK: - Calendar helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func endOfDay(for date: Date) -> Date {
        self.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay(for: date))
            ?? startOfDay(for: date)
    }

    func monthGridDays(containing month: Date) -> [Date] {
        let monthStart = startOfMonth(for: month)
        let weekday = component(.weekday, from: monthStart)
        let leading = (weekday - firstWeekday + 7) % 7
        guard let gridStart = date(byAdding: .day, value: -leading, to: monthStart) else {
            return [monthStart]
        }
        return (0..<42).compactMap { date(byAdding: .day, value: $0, to: gridStart) }
    }
}

#Preview("Empty") {
    CalendarView(schema: try! SchemaConfig.load())
        .modelContainer(for: SymptomEntry.self, inMemory: true)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
}

#Preview("With data") {
    let schema = try! SchemaConfig.load()
    let container = try! ModelContainer(for: SymptomEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let cal = Calendar.ebbCalendar
    let june1 = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
    let june14 = cal.date(from: DateComponents(year: 2026, month: 6, day: 14))!

    container.mainContext.insert(SymptomEntry(
        timestamp: june1,
        schemaVersion: schema.schemaVersion,
        fieldValues: ["bleeding": .choice("medium")]
    ))
    container.mainContext.insert(SymptomEntry(
        timestamp: cal.date(bySettingHour: 20, minute: 40, second: 0, of: june14)!,
        schemaVersion: schema.schemaVersion,
        fieldValues: [
            "migraine_present": .boolean(true),
            "severity": .scale(4),
            "location": .choices(["right"]),
        ]
    ))

    return CalendarView(schema: schema)
        .modelContainer(container)
        .environment(\.theme, .plumEmber)
        .environment(CycleService(provider: MockCycleDataProvider()))
}
