import Foundation

struct TimeoutError: Error {}

/// Runs `operation`, failing if it takes longer than `seconds` (a hung observation would
/// otherwise hang the whole test run).
func withTimeout<Value: Sendable>(
    _ seconds: Double = 5, _ operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        guard let value = try await group.next() else { throw TimeoutError() }
        return value
    }
}

/// Reads the first value of `sequence`, then for each change runs it and reads the next
/// value, returning every value read.
func observe<Sequence: AsyncSequence & Sendable>(
    _ sequence: Sequence, changes: [@Sendable () async throws -> Void]
) async throws -> [Sequence.Element] where Sequence.Element: Sendable {
    try await withTimeout {
        var iterator = sequence.makeAsyncIterator()
        var values = [Sequence.Element]()
        if let first = try await iterator.next() { values.append(first) }
        for change in changes {
            try await change()
            if let next = try await iterator.next() { values.append(next) }
        }
        return values
    }
}
