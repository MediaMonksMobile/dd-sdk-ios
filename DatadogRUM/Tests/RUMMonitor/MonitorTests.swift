/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import DatadogInternal
@testable import DatadogRUM

class MonitorTests: XCTestCase {
    private var core: PassthroughCoreMock! // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        core = PassthroughCoreMock()
    }

    override func tearDown() {
        core = nil
        super.tearDown()
    }

    func testWhenSessionIsSampled_itSetsRUMContextInCore() throws {
        // Given
        let sampler = Sampler(samplingRate: 100)

        // When
        let monitor = Monitor(
            core: core,
            dependencies: .mockWith(core: core, sessionSampler: sampler),
            dateProvider: DateProviderMock()
        )
        monitor.startView(key: "foo")

        // Then
        let rumBaggage = try XCTUnwrap(core.context.baggages[RUMFeature.name])
        let rumContext = try rumBaggage.decode(type: Optional<RUMCoreContext>.self)
        XCTAssertNotNil(rumContext)
    }

    func testWhenSessionIsNotSampled_itSetsNoRUMContextInCore() throws {
        // Given
        let sampler = Sampler(samplingRate: 0)

        // When
        let monitor = Monitor(
            core: core,
            dependencies: .mockWith(core: core, sessionSampler: sampler),
            dateProvider: DateProviderMock()
        )
        monitor.startView(key: "foo")

        // Then
        let rumBaggage = try XCTUnwrap(core.context.baggages[RUMFeature.name])
        let rumContext = try rumBaggage.decode(type: Optional<RUMCoreContext>.self)
        XCTAssertNil(rumContext)
    }
}
