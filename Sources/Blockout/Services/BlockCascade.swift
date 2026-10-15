import Foundation

/// Where the blocks after an extended block go. Pure, so the menu summary and the writer share it.
enum BlockCascade {
    struct Item: Equatable {
        let id: UUID
        let interval: DateInterval
    }

    struct Move: Equatable {
        let id: UUID
        let from: DateInterval
        let to: DateInterval
    }

    struct Result: Equatable {
        var moved: [Move] = []
        /// Blocks that would end after the working hours.
        var removed: [Item] = []
    }

    /// Pushes each later block that now overlaps to start when the previous one ends, keeping its length, and past
    /// any calendar event it would overlap. Events never move. The chain stops at the first block that does not need
    /// to move. Blocks that would end after `workdayEnd` are removed and do not push the following ones.
    /// - Parameters:
    ///   - blocks: confirmed blocks of the day after the extended one (drafts are never moved).
    ///   - events: timed calendar events of the day.
    ///   - from: the new end of the extended block.
    static func cascade(blocks: [Item], events: [DateInterval], from: Date, workdayEnd: Date) -> Result {
        let sortedEvents = events.sorted { $0.start < $1.start }
        var result = Result()
        var cursor = from
        for block in blocks.sorted(by: { $0.interval.start < $1.interval.start }) {
            guard block.interval.start < cursor else { break }
            var start = cursor
            let duration = block.interval.duration
            for event in sortedEvents where start < event.end && start.addingTimeInterval(duration) > event.start {
                start = event.end
            }
            let target = DateInterval(start: start, duration: duration)
            if target.end > workdayEnd {
                result.removed.append(block)
            } else {
                result.moved.append(Move(id: block.id, from: block.interval, to: target))
                cursor = target.end
            }
        }
        return result
    }
}
