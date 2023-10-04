/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
@testable import DatadogInternal

private class AsyncOperator: Flushable2 {
    static private(set) var referenceCount: Int = 0

    let queue: DispatchQueue
    let delay: TimeInterval

    init(
        label: String,
        delay: TimeInterval = 0.1
    ) {
        self.queue = DispatchQueue(label: label)
        self.delay = delay
        AsyncOperator.referenceCount += 1
    }

    deinit {
        AsyncOperator.referenceCount -= 1
    }

    func execute() {
        queue.async {
            // retain self 
            Thread.sleep(forTimeInterval: self.delay)
        }
    }

    func flush(completion: @escaping () -> Void) {
        queue.async(execute: completion)
    }
}

class FlushableTests: XCTestCase {
    func testSingleOperations() {
        var operation: AsyncOperator? = .init(label: "flush.test", delay: .mockRandom(min: 0.1, max: 0.5))
        operation?.waitFlush()
        XCTAssertEqual(AsyncOperator.referenceCount, 1)
        operation = nil
        XCTAssertEqual(AsyncOperator.referenceCount, 0)
    }

    func testSequenceOfOperations() {
        let operationCount: Int = 100
        var operations = (0..<operationCount).map {
            AsyncOperator(label: "\($0)", delay: .mockRandom(min: 0, max: 0.5))
        }
        operations.forEach { $0.execute() }
        operations.waitFlush()
        XCTAssertEqual(AsyncOperator.referenceCount, operationCount)
        operations.removeAll()
        XCTAssertEqual(AsyncOperator.referenceCount, 0)
    }
}
