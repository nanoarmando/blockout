import Foundation
import Observation
import SwiftUI

enum DragPayload: Equatable {
    case task(UUID)
    case block(UUID)

    /// "task:<uuid>" or "block:<uuid>": the drag item carries what is dragged, so drops never rely on stale state.
    var itemString: String {
        switch self {
        case .task(let id): "task:\(id.uuidString)"
        case .block(let id): "block:\(id.uuidString)"
        }
    }

    init?(itemString: String) {
        let parts = itemString.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "task": self = .task(id)
        case "block": self = .block(id)
        default: return nil
        }
    }
}

struct DropPreview: Equatable {
    let day: Date
    let start: Date
    let end: Date
    let title: String
    /// The range overlaps busy time; the preview shows the conflict and the drop is refused.
    var conflict = false
}

/// What is being dragged and where it would land. The source records the payload when the drag starts, but
/// SwiftUI on macOS does not always run the `onDrag` closure again and a cancelled drag leaves its payload behind,
/// so drop targets also read the payload from the dragged item when it enters (`load(from:)`).
@MainActor
@Observable
final class DragState {
    var payload: DragPayload?
    var preview: DropPreview?

    /// Starts a drag of `payload` and returns its item provider.
    func begin(_ payload: DragPayload) -> NSItemProvider {
        self.payload = payload
        preview = nil
        return NSItemProvider(object: payload.itemString as NSString)
    }

    /// Replaces the payload with the one carried by the dragged item (loaded asynchronously).
    func load(from info: DropInfo) {
        guard let provider = info.itemProviders(for: [.plainText]).first else { return }
        _ = provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
            // Text dragged from other apps is not a payload: clear any stale one instead of previewing it
            let payload = (object as? NSString).flatMap { DragPayload(itemString: $0 as String) }
            Task { @MainActor in
                if self?.payload != payload { self?.payload = payload }
            }
        }
    }

    func finish() {
        payload = nil
        preview = nil
    }
}
