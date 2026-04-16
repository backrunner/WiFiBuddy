import Foundation

enum DefaultSelectionPolicy {
    static func preferredNetworkID(in observations: [NetworkObservation]) -> NetworkObservation.ID? {
        guard !observations.isEmpty else { return nil }

        guard observations.allSatisfy({ !$0.hasVisibleName }) else {
            return observations.first?.id
        }

        return observations
            .enumerated()
            .max { lhs, rhs in
                if lhs.element.rssi != rhs.element.rssi {
                    return lhs.element.rssi < rhs.element.rssi
                }
                return lhs.offset > rhs.offset
            }?
            .element
            .id
    }
}
