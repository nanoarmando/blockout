import SwiftUI
import UniformTypeIdentifiers

/// Día, Días and Semana: day columns over the working hours with events, blocks, free time and the now line.
struct TimeGridView: View {
    let days: [Date]
    let events: [CalendarEvent]
    let blocks: [Block]
    let drafts: [Block]
    let tasks: [PlannerTask]
    let openTask: (PlannerTask) -> Void

    @Environment(SettingsStore.self) private var settingsStore

    static let hourHeight: CGFloat = 52
    private static let hourColumnWidth: CGFloat = 56

    private var settings: AppSettings { settingsStore.settings }
    private var firstHour: Int { settings.workdayStartMinutes / 60 }
    private var lastHour: Int { max(firstHour + 1, Int((Double(settings.workdayEndMinutes) / 60).rounded(.up))) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.hourColumnWidth)
                ForEach(days, id: \.self) { day in
                    dayHeader(day)
                }
            }
            // Color.clear is vertically flexible; keep the header at its natural height
            .fixedSize(horizontal: false, vertical: true)
            Theme.line.frame(height: 1)
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    hourColumn
                    ForEach(days, id: \.self) { day in
                        DayColumn(
                            day: day,
                            firstHour: firstHour,
                            lastHour: lastHour,
                            events: timedEvents(on: day),
                            blocks: blocks(on: day),
                            drafts: drafts.filter { Calendar.planner.isDate($0.start, inSameDayAs: day) },
                            tasks: tasks,
                            allBlocks: blocks,
                            openTask: openTask
                        )
                    }
                }
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private func dayHeader(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PlannerFormat.weekday(day)).font(.system(size: 12)).foregroundStyle(Theme.muted)
                Text("\(PlannerFormat.day(day))").font(.system(size: 16, weight: .semibold))
                if Calendar.planner.isDateInToday(day) {
                    Text("Hoy")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.now, in: Capsule())
                }
            }
            Text(freeLabel(day)).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .overlay(alignment: .leading) { Theme.lineSoft.frame(width: 1) }
    }

    private var hourColumn: some View {
        TimelineView(.everyMinute) { context in
            ZStack(alignment: .topTrailing) {
                ForEach(firstHour..<lastHour, id: \.self) { hour in
                    Text("\(hour):00")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .padding(.trailing, 8)
                        .offset(y: CGFloat(hour - firstHour) * Self.hourHeight + 2)
                }
                if let y = Self.offset(of: context.date, firstHour: firstHour, lastHour: lastHour) {
                    Text(PlannerFormat.time(context.date))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Theme.now, in: RoundedRectangle(cornerRadius: 4))
                        .padding(.trailing, 4)
                        .offset(y: y - 8)
                }
            }
            .frame(width: Self.hourColumnWidth, height: CGFloat(lastHour - firstHour) * Self.hourHeight, alignment: .topTrailing)
        }
    }

    private func timedEvents(on day: Date) -> [CalendarEvent] {
        events.filter { !$0.isAllDay && Calendar.planner.isDate($0.start, inSameDayAs: day) }
    }

    private func blocks(on day: Date) -> [Block] {
        blocks.filter { Calendar.planner.isDate($0.start, inSameDayAs: day) }
    }

    private func freeLabel(_ day: Date) -> String {
        guard let workday = settings.workday(containing: day) else { return "Fin de semana" }
        let busy = timedEvents(on: day).map(\.interval) + blocks(on: day).map(\.interval)
        return PlannerFormat.free(SlotFinder.freeDuration(in: workday, busy: busy))
    }

    /// Vertical position of a time of day, or `nil` when it is outside the visible hours.
    static func offset(of date: Date, firstHour: Int, lastHour: Int) -> CGFloat? {
        let parts = Calendar.planner.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        guard minutes >= firstHour * 60, minutes <= lastHour * 60 else { return nil }
        return CGFloat(minutes - firstHour * 60) / 60 * hourHeight
    }
}

extension Block {
    var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }
}

private struct DayColumn: View {
    let day: Date
    let firstHour: Int
    let lastHour: Int
    let events: [CalendarEvent]
    let blocks: [Block]
    let drafts: [Block]
    let tasks: [PlannerTask]
    let allBlocks: [Block]
    let openTask: (PlannerTask) -> Void

    @Environment(SettingsStore.self) private var settingsStore
    @Environment(CalendarService.self) private var calendarService
    @Environment(DragState.self) private var dragState

    private var hourHeight: CGFloat { TimeGridView.hourHeight }
    private var height: CGFloat { CGFloat(lastHour - firstHour) * hourHeight }

    var body: some View {
        GeometryReader { geometry in
            let intervals = events.map(\.interval) + blocks.map(\.interval) + drafts.map(\.interval)
            let lanes = LaneLayout.lanes(for: intervals)
            ZStack(alignment: .topLeading) {
                hourLines
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    let rect = frame(for: event.interval, lane: lanes[index], width: geometry.size.width)
                    EventItem(event: event)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    let rect = frame(for: block.interval, lane: lanes[events.count + index], width: geometry.size.width)
                    BlockItem(block: block, height: rect.height, openTask: openTask)
                        .frame(width: rect.width, alignment: .top)
                        .offset(x: rect.minX, y: rect.minY)
                        .zIndex(1)
                }
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    let rect = frame(for: draft.interval, lane: lanes[events.count + blocks.count + index], width: geometry.size.width)
                    DraftItem(draft: draft)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .zIndex(1)
                }
                if let preview = dragState.preview, Calendar.planner.isDate(preview.day, inSameDayAs: day) {
                    let rect = frame(for: DateInterval(start: preview.start, end: preview.end), lane: (0, 1), width: geometry.size.width)
                    PreviewItem(preview: preview)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .zIndex(2)
                }
                nowLine
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) { Theme.lineSoft.frame(width: 1) }
        .contentShape(Rectangle())
        .onDrop(of: [.plainText], delegate: DayDropDelegate(column: self))
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(firstHour..<lastHour, id: \.self) { _ in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Theme.stripe.frame(height: 1)
                }
                .frame(height: hourHeight)
            }
        }
        .allowsHitTesting(false)
    }

    private var nowLine: some View {
        TimelineView(.everyMinute) { context in
            if let y = TimeGridView.offset(of: context.date, firstHour: firstHour, lastHour: lastHour) {
                let isToday = Calendar.planner.isDate(context.date, inSameDayAs: day)
                ZStack(alignment: .leading) {
                    Rectangle().fill(isToday ? Theme.now : Theme.nowSoft).frame(height: isToday ? 2 : 1)
                    if isToday {
                        Circle().fill(Theme.now).frame(width: 10, height: 10).offset(x: -5)
                    }
                }
                .offset(y: y - (isToday ? 1 : 0.5))
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .zIndex(3)
    }

    // MARK: Geometry

    private func frame(for interval: DateInterval, lane: (lane: Int, count: Int), width: CGFloat) -> CGRect {
        let inset: CGFloat = 4
        let laneWidth = (width - inset * 2) / CGFloat(lane.count)
        let top = yOffset(of: interval.start) + 1
        let height = max(16, yOffset(of: interval.end) - yOffset(of: interval.start) - 3)
        return CGRect(x: inset + laneWidth * CGFloat(lane.lane), y: top, width: max(0, laneWidth - 2), height: height)
    }

    func yOffset(of date: Date) -> CGFloat {
        let minutes = date.timeIntervalSince(Calendar.planner.startOfDay(for: day)) / 60
        return CGFloat(minutes - Double(firstHour * 60)) / 60 * hourHeight
    }

    /// The 15-minute step under the pointer, kept inside the visible hours for an item of `duration`.
    func snappedStart(at location: CGPoint, duration: TimeInterval) -> Date {
        let pointerMinutes = firstHour * 60 + Int(location.y / hourHeight * 60)
        let latest = lastHour * 60 - Int(duration / 60)
        let minutes = min(max(SlotFinder.snap(minutes: pointerMinutes), firstHour * 60), max(firstHour * 60, latest))
        return Calendar.planner.startOfDay(for: day).addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// Where the dragged item would land, or `nil` when a task does not fit in the working hours.
    func preview(at location: CGPoint) -> DropPreview? {
        switch dragState.payload {
        case .task(let id):
            guard let task = tasks.first(where: { $0.id == id }),
                  let workday = settingsStore.settings.workday(containing: day) else { return nil }
            let duration = TimeInterval(settingsStore.settings.blockMinutes(for: task) * 60)
            let busy = events.map(\.interval) + blocks.map(\.interval)
            guard let start = SlotFinder.nextFreeStart(from: snappedStart(at: location, duration: duration), duration: duration, busy: busy, workday: workday)
            else { return nil }
            return DropPreview(day: day, start: start, end: start.addingTimeInterval(duration), title: task.blockTitle)
        case .block(let id):
            // Moving an existing block is deliberate, so it may overlap other items.
            guard let block = allBlocks.first(where: { $0.id == id }) else { return nil }
            let duration = block.end.timeIntervalSince(block.start)
            let start = snappedStart(at: location, duration: duration)
            return DropPreview(day: day, start: start, end: start.addingTimeInterval(duration), title: block.task?.blockTitle ?? "")
        case nil:
            return nil
        }
    }

    func performDrop(at location: CGPoint) -> Bool {
        defer { dragState.finish() }
        guard let preview = preview(at: location) else { return false }
        switch dragState.payload {
        case .task(let id):
            guard let task = tasks.first(where: { $0.id == id }) else { return false }
            return calendarService.createBlock(for: task, start: preview.start, end: preview.end)
        case .block(let id):
            guard let block = allBlocks.first(where: { $0.id == id }) else { return false }
            if NSEvent.modifierFlags.contains(.option), let task = block.task {
                return calendarService.createBlock(for: task, start: preview.start, end: preview.end)
            }
            return calendarService.moveBlock(block, start: preview.start, end: preview.end)
        case nil:
            return false
        }
    }

    func updatePreview(at location: CGPoint) -> DropProposal {
        let preview = preview(at: location)
        if dragState.preview != preview { dragState.preview = preview }
        guard preview != nil else { return DropProposal(operation: .forbidden) }
        return DropProposal(operation: NSEvent.modifierFlags.contains(.option) ? .copy : .move)
    }

    func clearPreview() {
        if let preview = dragState.preview, Calendar.planner.isDate(preview.day, inSameDayAs: day) {
            dragState.preview = nil
        }
    }

    var isDragging: Bool { dragState.payload != nil }
}

private struct DayDropDelegate: DropDelegate {
    let column: DayColumn

    func validateDrop(info: DropInfo) -> Bool { column.isDragging }
    func dropUpdated(info: DropInfo) -> DropProposal? { column.updatePreview(at: info.location) }
    func dropExited(info: DropInfo) { column.clearPreview() }
    func performDrop(info: DropInfo) -> Bool { column.performDrop(at: info.location) }
}

private struct EventItem: View {
    let event: CalendarEvent

    var body: some View {
        Text(event.title)
            .font(.system(size: 11))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .clipped()
            .help(event.title)
    }
}

private struct PreviewItem: View {
    let preview: DropPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(preview.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            Text("Soltar · \(PlannerFormat.timeRange(preview.start, preview.end))").font(.system(size: 11)).opacity(0.85)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
        .shadow(color: .black.opacity(0.22), radius: 8, y: 6)
        .clipped()
        .allowsHitTesting(false)
    }
}

private struct BlockItem: View {
    let block: Block
    let height: CGFloat
    let openTask: (PlannerTask) -> Void

    @Environment(CalendarService.self) private var calendarService
    @Environment(DragState.self) private var dragState
    @State private var resizeMinutes = 0

    private var colorIndex: Int? { block.task?.project?.colorIndex }

    var body: some View {
        let isShort = block.end.timeIntervalSince(block.start) < 45 * 60
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                Text(block.task?.blockTitle ?? "").lineLimit(1).truncationMode(.tail)
            }
            .font(.system(size: 11, weight: .medium))
            if !isShort {
                Text(timeLabel).font(.system(size: 11)).lineLimit(1).opacity(0.85)
            }
        }
        .foregroundStyle(ProjectPalette.foreground(colorIndex))
        .padding(.horizontal, 6)
        .padding(.vertical, isShort ? 1 : 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: max(16, height + CGFloat(resizeMinutes) / 60 * TimeGridView.hourHeight))
        .background(ProjectPalette.fill(colorIndex), in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .bottom) { resizeHandle }
        .contentShape(Rectangle())
        .onTapGesture { if let task = block.task { openTask(task) } }
        .onDrag {
            dragState.payload = .block(block.id)
            return NSItemProvider(object: block.id.uuidString as NSString)
        }
        .help("\(block.task?.blockTitle ?? "") · \(timeLabel)")
    }

    private var timeLabel: String {
        let range = PlannerFormat.timeRange(block.start, block.end.addingTimeInterval(TimeInterval(resizeMinutes * 60)))
        guard let project = block.task?.project else { return range }
        return "\(range) · \(project.name)"
    }

    private var resizeHandle: some View {
        Color.clear
            .frame(height: 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let minimum = SlotFinder.stepMinutes - Int(block.end.timeIntervalSince(block.start) / 60)
                        let raw = Int((value.translation.height / TimeGridView.hourHeight * 60).rounded())
                        resizeMinutes = max(minimum, (raw / SlotFinder.stepMinutes) * SlotFinder.stepMinutes)
                    }
                    .onEnded { _ in
                        let minutes = resizeMinutes
                        resizeMinutes = 0
                        guard minutes != 0 else { return }
                        calendarService.moveBlock(block, start: block.start, end: block.end.addingTimeInterval(TimeInterval(minutes * 60)))
                    }
            )
    }
}

/// A proposed block: hatched fill and dashed outline; selecting it offers accepting or discarding only this one.
private struct DraftItem: View {
    let draft: Block

    @Environment(CalendarService.self) private var calendarService
    @State private var showsActions = false

    private var colorIndex: Int? { draft.task?.project?.colorIndex }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(draft.task?.blockTitle ?? "").font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.tail)
            Text("Propuesto · \(PlannerFormat.timeRange(draft.start, draft.end))").font(.system(size: 11)).lineLimit(1).opacity(0.85)
        }
        .foregroundStyle(ProjectPalette.foreground(colorIndex))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            HatchPattern(color: ProjectPalette.fill(colorIndex))
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { showsActions = true }
        .popover(isPresented: $showsActions, arrowEdge: .trailing) { actions }
        .help("\(draft.task?.blockTitle ?? "") · bloque propuesto")
        .accessibilityAddTraits(.isButton)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(draft.task?.blockTitle ?? "").font(.system(size: 13, weight: .semibold)).lineLimit(2)
            Text("\(PlannerFormat.dayMonth(draft.start)) · \(PlannerFormat.timeRange(draft.start, draft.end))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                Button("Descartar") {
                    showsActions = false
                    calendarService.discardDrafts([draft])
                }
                .buttonStyle(ToggleButtonStyle(isSelected: false, height: 32))
                Button("Aceptar") {
                    showsActions = false
                    calendarService.acceptDrafts([draft])
                }
                .buttonStyle(ToggleButtonStyle(isSelected: true, selectedFill: Theme.accent, selectedText: .white, height: 32))
            }
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
    }
}

/// Diagonal stripes used for drafts.
private struct HatchPattern: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 12
            }
            context.stroke(path, with: .color(color), lineWidth: 6)
        }
        .allowsHitTesting(false)
    }
}
