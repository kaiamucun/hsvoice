import Foundation

/// Structured task groups await all children on exit, including a model call
/// that ignores cancellation. This one-shot race instead resumes its caller as
/// soon as the model, deadline, or caller cancellation wins. It asks both tasks
/// to cancel and drops late results. It cannot forcibly stop a non-cooperative
/// backend, but that backend cannot delay or change the caller's result.
enum RefinementDeadline {
  static func run<Value: Sendable>(
    seconds: TimeInterval, timeoutValue: Value, cancellationValue: Value,
    operation: @escaping @Sendable () async -> Value
  ) async -> Value {
    let race = RefinementRace<Value>()
    let nanoseconds = UInt64(max(0, min(seconds, 3_600)) * 1_000_000_000)
    let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int64(nanoseconds)))
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        guard race.install(continuation) else { return }
        let worker = Task.detached(priority: .userInitiated) {
          guard !Task.isCancelled else { return }
          race.finish(await operation())
        }
        let timer = Task.detached {
          do {
            try await Task.sleep(until: deadline, clock: .continuous)
            race.finish(timeoutValue)
          } catch {
            // The winning branch cancels this timer.
          }
        }
        race.register([worker, timer])
      }
    } onCancel: {
      race.finish(cancellationValue)
    }
  }
}

/// Every mutable field is protected by the lock. Resume and cancellation happen
/// outside the lock because they may schedule work that immediately reenters.
private final class RefinementRace<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Value, Never>?
  private var result: Value?
  private var tasks: [Task<Void, Never>] = []

  func install(_ continuation: CheckedContinuation<Value, Never>) -> Bool {
    lock.lock()
    if let result {
      lock.unlock()
      continuation.resume(returning: result)
      return false
    }
    self.continuation = continuation
    lock.unlock()
    return true
  }

  func register(_ tasks: [Task<Void, Never>]) {
    lock.lock()
    let finished = result != nil
    if !finished { self.tasks = tasks }
    lock.unlock()
    if finished {
      for task in tasks { task.cancel() }
    }
  }

  func finish(_ value: Value) {
    lock.lock()
    guard result == nil else {
      lock.unlock()
      return
    }
    result = value
    let continuation = self.continuation
    self.continuation = nil
    let tasks = self.tasks
    self.tasks = []
    lock.unlock()
    for task in tasks { task.cancel() }
    continuation?.resume(returning: value)
  }
}
