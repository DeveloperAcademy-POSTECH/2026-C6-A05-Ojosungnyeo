import Foundation

struct RouteTravelTimeMatrix: Equatable, Sendable {
    let durationsByOriginID: [String: [String: TimeInterval]]

    func duration(from originID: String, to destinationID: String) -> TimeInterval? {
        durationsByOriginID[originID]?[destinationID]
    }
}
