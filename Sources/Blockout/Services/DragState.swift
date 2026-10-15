import Foundation
import Observation

enum DragPayload: Equatable {
    case task(UUID)
    case block(UUID)
}

struct DropPreview: Equatable {
    let day: Date
    let start: Date
    let end: Date
    let title: String
}

/// What is being dragged and where it would land. SwiftUI drop delegates only see item providers
/// asynchronously, so the source records the payload when the drag starts to drive the live preview.
@MainActor
@Observable
final class DragState {
    var payload: DragPayload?
    var preview: DropPreview?

    func finish() {
        payload = nil
        preview = nil
    }
}
