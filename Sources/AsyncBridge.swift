// ============================================================================
// AsyncBridge.swift — Run an async throws operation from the synchronous
// top-level main script, blocking until completion. Used for FoundationModels
// integration (Cleaner) which is async-only.
// ============================================================================

import Foundation

/// Block the current thread until the async operation completes.
/// Returns the value or rethrows the error. Designed for CLI top-level use only.
func runAsync<T: Sendable>(_ operation: @Sendable @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: Result<T, Error> = .failure(CancellationError())

    Task.detached {
        do {
            let value = try await operation()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    return try result.get()
}
