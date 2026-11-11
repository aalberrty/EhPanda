@testable import EhFeatures
import Observation
import Testing

@MainActor
struct ObservedValuesTests {
    @Observable
    final class Counter {
        var value = 0
    }

    @Test func trackedValuesStartWithTheCurrentValueAndFollowChanges() async {
        let counter = Counter()
        let seen = Recorder()
        let following = Task { await forEachTrackedValue(of: { counter.value }, { seen.values.append($0) }) }
        defer { following.cancel() }

        await waitUntil { seen.values == [0] }
        counter.value = 1
        await waitUntil { seen.values == [0, 1] }
        counter.value = 2
        await waitUntil { seen.values == [0, 1, 2] }
    }

    @Test func trackedValuesStopWhenCancelled() async {
        let counter = Counter()
        let seen = Recorder()
        let following = Task { await forEachTrackedValue(of: { counter.value }, { seen.values.append($0) }) }

        await waitUntil { seen.values == [0] }
        following.cancel()
        await following.value
        counter.value = 1
        #expect(seen.values == [0])
    }

    @Test func observedValuesFollowChanges() async {
        let counter = Counter()
        let seen = Recorder()
        let following = Task { await forEachObservedValue(of: { counter.value }, { seen.values.append($0) }) }
        defer { following.cancel() }

        await waitUntil { seen.values.last == 0 }
        counter.value = 1
        await waitUntil { seen.values.last == 1 }
    }

    @MainActor
    final class Recorder {
        var values: [Int] = []
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(2))
        }
        #expect(condition())
    }
}
