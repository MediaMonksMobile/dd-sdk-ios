/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import DatadogInternal

@testable import DatadogSessionReplay

class RUMContextReceiverTests: XCTestCase {
    private let receiver = RUMContextReceiver()

    internal struct RUMContextMock: Encodable {
        enum CodingKeys: String, CodingKey {
            case applicationID = "application.id"
            case sessionID = "session.id"
            case viewID = "view.id"
            case viewServerTimeOffset = "server_time_offset"
        }

        let applicationID: String
        let sessionID: String
        let viewID: String?
        let viewServerTimeOffset: TimeInterval?
    }

    func testWhenMessageContainsNonEmptyRUMBaggage_itNotifiesRUMContext() throws {
        // Given
        let context = DatadogContext.mockWith(
            baggages: [
                RUMContext.key: .init(
                    RUMContextMock(
                        applicationID: "app-id",
                        sessionID: "session-id",
                        viewID: "view-id",
                        viewServerTimeOffset: 123
                    )
                )
            ]
        )

        let message = FeatureMessage.context(context)
        let core = PassthroughCoreMock(messageReceiver: receiver)

        // When
        var rumContext: RUMContext?
        receiver.observe(on: NoQueue()) { context in
            rumContext = context
        }
        core.send(message: message, else: {
            XCTFail("Fallback shouldn't be called")
        })

        // Then
        XCTAssertEqual(rumContext?.applicationID, "app-id")
        XCTAssertEqual(rumContext?.sessionID, "session-id")
        XCTAssertEqual(rumContext?.viewID, "view-id")
        XCTAssertEqual(rumContext?.viewServerTimeOffset, 123)
    }

    func testWhenSucceedingMessagesContainDifferentRUMBaggages_itNotifiesRUMContextChange() throws {
        // Given
        let context1 = DatadogContext.mockWith(
            baggages: [
                RUMContext.key: .init(
                    RUMContextMock(
                        applicationID: "app-id-1",
                        sessionID: "session-id-1",
                        viewID: "view-id-1",
                        viewServerTimeOffset: 123
                    )
                )
            ]
        )
        let message1 = FeatureMessage.context(context1)
        let context2 = DatadogContext.mockWith(
            baggages: [
                RUMContext.key: .init(
                    RUMContextMock(
                        applicationID: "app-id-2",
                        sessionID: "session-id-2",
                        viewID: "view-id-2",
                        viewServerTimeOffset: 345
                    )
                )
            ]
        )
        let message2 = FeatureMessage.context(context2)
        let core = PassthroughCoreMock(messageReceiver: receiver)

        // When
        var rumContexts = [RUMContext]()
        receiver.observe(on: NoQueue()) { context in
            context.flatMap { rumContexts.append($0) }
        }
        core.send(message: message1, else: {
            XCTFail("Fallback shouldn't be called")
        })
        core.send(message: message2, else: {
            XCTFail("Fallback shouldn't be called")
        })

        // Then
        XCTAssertEqual(rumContexts.count, 2)
        XCTAssertEqual(rumContexts[0].applicationID, "app-id-1")
        XCTAssertEqual(rumContexts[0].sessionID, "session-id-1")
        XCTAssertEqual(rumContexts[0].viewID, "view-id-1")
        XCTAssertEqual(rumContexts[0].viewServerTimeOffset, 123)
        XCTAssertEqual(rumContexts[1].applicationID, "app-id-2")
        XCTAssertEqual(rumContexts[1].sessionID, "session-id-2")
        XCTAssertEqual(rumContexts[1].viewID, "view-id-2")
        XCTAssertEqual(rumContexts[1].viewServerTimeOffset, 345)
    }

    func testWhenMessageDoesntContainRUMBaggage_itCallsFallback() {
        let context = DatadogContext.mockAny()
        let message = FeatureMessage.context(context)
        let core = PassthroughCoreMock(messageReceiver: receiver)

        // When
        var fallbackCalled = false
        core.send(message: message, else: {
            fallbackCalled = true
        })

        // Then
        XCTAssertTrue(fallbackCalled)
    }
}
