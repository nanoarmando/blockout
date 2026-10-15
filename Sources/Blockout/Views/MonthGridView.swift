import SwiftUI

/// Mes: each day shows up to two blocks in their project colors and "+N" for the remaining blocks and events.
struct MonthGridView: View {
    let cells: [Date]
    let month: Date
    let events: [CalendarEvent]
    let blocks: [Block]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(PlannerFormat.weekdayHeaders, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
            }
            Theme.line.frame(height: 1)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(cells, id: \.self) { day in
                        cell(day)
                    }
                }
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private func cell(_ day: Date) -> some View {
        let calendar = Calendar.planner
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let dayBlocks = blocks.filter { calendar.isDate($0.start, inSameDayAs: day) }.sorted { $0.start < $1.start }
        let eventCount = events.filter { calendar.isDate($0.start, inSameDayAs: day) }.count
        let shown = dayBlocks.prefix(2)
        let remaining = dayBlocks.count - shown.count + eventCount
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(PlannerFormat.day(day))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(calendar.isDateInToday(day) ? Theme.now : Theme.ink)
            ForEach(Array(shown), id: \.id) { block in
                let colorIndex = block.task?.project?.colorIndex
                Text(block.task?.blockTitle ?? "")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(ProjectPalette.foreground(colorIndex))
                    .background(ProjectPalette.fill(colorIndex), in: RoundedRectangle(cornerRadius: 4))
            }
            if remaining > 0 {
                Text("+\(remaining)").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(inMonth ? Color.clear : Theme.outside)
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Theme.lineSoft.frame(height: 1).frame(maxWidth: .infinity)
                Theme.lineSoft.frame(width: 1).frame(maxHeight: .infinity)
            }
        }
    }
}
