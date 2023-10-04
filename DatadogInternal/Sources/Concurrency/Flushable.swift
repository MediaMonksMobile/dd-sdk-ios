/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

public protocol Flushable {
    /// Awaits completion of all asynchronous operations.
    ///
    /// **blocks the caller thread**
    func flush()
}

public protocol Flushable2 {
    /// Schedules the submission of a block to execute when all tasks have finished executing.
    ///
    /// This function schedules a notification block to be invoked when
    /// all asynchronous operations associated with the instance have completed. If the
    /// complying instance has no operations (no asynchronous tasks scheduled in background),
    /// the notification block object should be submitted immediately.
    ///
    /// - Parameters:
    ///   - completion: The completion to be performed when the flush is completed.
    func flush(completion: @escaping () -> Void)
}

extension Flushable2 {
    @available(iOS 13.0, *)
    public func flush() async {
        await withCheckedContinuation { flush(completion: $0.resume) }
    }

    internal func waitFlush() {
        let semaphore = DispatchSemaphore(value: 0)
        flush() { semaphore.signal() }
        semaphore.wait()
    }
}

extension Sequence where Element: Flushable2 {
    public func flush(completion: @escaping () -> Void) {
        flush(queue: .global(), completion: completion)
    }

    public func flush(queue: DispatchQueue, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        group.enter()
        forEach {
            group.enter()
            $0.flush(completion: group.leave)
        }
        group.leave()
        group.notify(queue: queue, execute: completion)
    }
}
