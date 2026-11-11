import Observation

/// The path of one `NavigationStack`. Each stack puts its router in the SwiftUI environment,
/// so a view pushes onto the stack it lives in without knowing which tab or sheet that is.
@Observable
public final class StackRouter {
    public var path: [Route] = []

    public init() {}

    public var isAtRoot: Bool { path.isEmpty }

    public func push(_ route: Route) {
        path.append(route)
    }

    public func pop() {
        _ = path.popLast()
    }

    public func popToRoot() {
        path.removeAll()
    }
}
