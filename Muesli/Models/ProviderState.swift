import Foundation

enum ProviderState: Equatable, Sendable {
    case inactive
    case waitingRoom
    case joined
    case left
    case indeterminate
}
