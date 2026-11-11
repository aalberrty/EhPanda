import Foundation

public enum LoadingState: Sendable, Hashable {
    case idle
    case loading
    case failed(AppError)
}

extension LoadingState {
    public var isIdle: Bool { self == .idle }
    public var isLoading: Bool { self == .loading }

    /// The error when the state is `.failed`.
    public var failed: AppError? {
        if case .failed(let error) = self { error } else { nil }
    }
}
