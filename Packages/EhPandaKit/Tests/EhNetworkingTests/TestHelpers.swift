import Foundation
import Synchronization

/// Records the delays `RetryingTransport` asks for, without waiting.
final class SleepRecorder: Sendable {
    private let recorded = Mutex<[Duration]>([])

    var delays: [Duration] { recorded.withLock { $0 } }

    var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in recorded.withLock { $0.append(duration) } }
    }
}

func makeRequest(_ string: String = "https://e-hentai.org/", method: String = "GET") -> URLRequest {
    var request = URLRequest(url: URL(string: string)!)
    request.httpMethod = method
    return request
}

/// Waits until `condition` holds, giving up after about two seconds.
func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<2000 where !condition() {
        try await Task.sleep(for: .milliseconds(1))
    }
}

extension Error {
    var urlErrorCode: URLError.Code? { (self as? URLError)?.code }
}
