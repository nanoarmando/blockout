import SwiftUI

struct UrgencyBars: View {
    let level: Int

    private static let labels = ["", "Urgencia baja", "Urgencia media", "Urgencia alta"]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index <= level ? Theme.ink : Theme.barOff)
                    .frame(width: 3, height: CGFloat(index * 4))
            }
        }
        .frame(height: 12, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel(Self.labels[min(max(level, 0), 3)])
    }
}

struct ProjectChip: View {
    let project: Project
    var fontSize: CGFloat = 12

    var body: some View {
        Text(project.name)
            .font(.system(size: fontSize, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .foregroundStyle(ProjectPalette.foreground(project.colorIndex))
            .background(ProjectPalette.fill(project.colorIndex), in: Capsule())
    }
}

struct CompletionButton: View {
    let isDone: Bool
    var size: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .strokeBorder(Theme.check, lineWidth: 1.5)
                .background(Circle().fill(isDone ? Theme.check : Theme.card))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "Reabrir tarea" : "Completar tarea")
    }
}

/// The mockup's toggle button: strong fill when selected, outlined otherwise.
struct ToggleButtonStyle: ButtonStyle {
    var isSelected: Bool
    var selectedFill = Theme.strong
    var selectedText = Theme.onStrong
    var height: CGFloat = 32
    var bordered = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .foregroundStyle(isSelected ? selectedText : Theme.ink)
            .background(isSelected ? selectedFill : (bordered ? Theme.card : .clear), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if bordered && !isSelected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.control)
                }
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Lays out overlapping intervals side by side: each item gets a lane and the lane count of its cluster.
enum LaneLayout {
    static func lanes(for intervals: [DateInterval]) -> [(lane: Int, count: Int)] {
        let order = intervals.indices.sorted { intervals[$0].start < intervals[$1].start }
        var result = Array(repeating: (lane: 0, count: 1), count: intervals.count)
        var cluster: [Int] = []
        var laneEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func closeCluster() {
            for index in cluster { result[index].count = laneEnds.count }
            cluster = []
            laneEnds = []
        }

        for index in order {
            let interval = intervals[index]
            if interval.start >= clusterEnd { closeCluster() }
            if let free = laneEnds.firstIndex(where: { $0 <= interval.start }) {
                laneEnds[free] = interval.end
                result[index].lane = free
            } else {
                laneEnds.append(interval.end)
                result[index].lane = laneEnds.count - 1
            }
            cluster.append(index)
            clusterEnd = max(clusterEnd, interval.end)
        }
        closeCluster()
        return result
    }
}

/// Places children left to right and wraps them onto new lines, like the mockup's meta rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1] = (last.indices + [index], last.width + spacing + size.width, max(last.height, size.height))
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}
