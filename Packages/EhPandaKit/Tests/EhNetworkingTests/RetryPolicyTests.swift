import Foundation
import Testing
@testable import EhNetworking

struct RetryPolicyTests {
    let policy = RetryPolicy()

    @Test(arguments: ["GET", "HEAD", "get", nil])
    func idempotentMethodsRetryTransientErrors(method: String?) {
        for code in RetryPolicy.transientErrors {
            #expect(policy.shouldRetry(method: method, error: URLError(code)))
        }
        #expect(!policy.shouldRetry(method: method, error: URLError(.cancelled)))
        #expect(!policy.shouldRetry(method: method, error: URLError(.badURL)))
        #expect(!policy.shouldRetry(method: method, error: URLError(.userAuthenticationRequired)))
    }

    @Test(arguments: ["POST", "PUT", "DELETE", "PATCH"])
    func otherMethodsRetryOnlyUndeliveredErrors(method: String) {
        for code in RetryPolicy.undeliveredErrors {
            #expect(policy.shouldRetry(method: method, error: URLError(code)))
        }
        for code in RetryPolicy.transientErrors.subtracting(RetryPolicy.undeliveredErrors) {
            #expect(!policy.shouldRetry(method: method, error: URLError(code)), "\(method) retried \(code)")
        }
        #expect(!policy.shouldRetry(method: method, error: URLError(.cancelled)))
    }

    @Test func mayHaveBeenDeliveredErrorsAreNotUndelivered() {
        for code: URLError.Code in [.timedOut, .networkConnectionLost, .badServerResponse, .unknown] {
            #expect(!RetryPolicy.undeliveredErrors.contains(code))
        }
    }

    @Test func delayDoublesPerAttempt() {
        let policy = RetryPolicy(baseDelay: .milliseconds(100), jitterFraction: 0.25)
        #expect(policy.delay(afterAttempt: 1, random: 0) == .milliseconds(100))
        #expect(policy.delay(afterAttempt: 2, random: 0) == .milliseconds(200))
        #expect(policy.delay(afterAttempt: 3, random: 0) == .milliseconds(400))
    }

    @Test func jitterAddsUpToTheConfiguredFraction() {
        let policy = RetryPolicy(baseDelay: .milliseconds(100), jitterFraction: 0.25)
        #expect(policy.delay(afterAttempt: 1, random: 0.5) == .microseconds(112_500))
        #expect(policy.delay(afterAttempt: 2, random: 0.999) < .milliseconds(250))
    }
}
