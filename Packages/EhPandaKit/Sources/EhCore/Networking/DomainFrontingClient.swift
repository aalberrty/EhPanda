import Dependencies
import EhNetworking
import Foundation

/// Switches domain fronting on the app's own transport (legacy `DFClient`).
///
/// Requests already in flight finish on the session they started on. Only `\.ehClient`'s
/// transport is affected; the image downloader is switched by the app target.
public struct DomainFrontingClient: Sendable {
    public var isEnabled: @Sendable () -> Bool
    public var setEnabled: @Sendable (Bool) -> Void

    public init(
        isEnabled: @escaping @Sendable () -> Bool,
        setEnabled: @escaping @Sendable (Bool) -> Void
    ) {
        self.isEnabled = isEnabled
        self.setEnabled = setEnabled
    }

    /// Reads and flips `transport.isDomainFrontingEnabled`.
    public static func transport(_ transport: URLSessionTransport) -> DomainFrontingClient {
        DomainFrontingClient(
            isEnabled: { transport.isDomainFrontingEnabled },
            setEnabled: { transport.isDomainFrontingEnabled = $0 }
        )
    }
}

extension DomainFrontingClient: DependencyKey {
    public static let liveValue = DomainFrontingClient.transport(LiveNetwork.transport)

    public static let testValue = DomainFrontingClient(
        isEnabled: unimplemented("DomainFrontingClient.isEnabled", placeholder: false),
        setEnabled: unimplemented("DomainFrontingClient.setEnabled")
    )

    public static let previewValue = DomainFrontingClient(isEnabled: { false }, setEnabled: { _ in })
}

extension DependencyValues {
    public var domainFronting: DomainFrontingClient {
        get { self[DomainFrontingClient.self] }
        set { self[DomainFrontingClient.self] = newValue }
    }
}
