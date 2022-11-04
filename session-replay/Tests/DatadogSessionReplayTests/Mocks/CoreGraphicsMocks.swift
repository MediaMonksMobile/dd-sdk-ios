/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import CoreGraphics
import UIKit

extension CGFloat: AnyMockable, RandomMockable {
    static func mockAny() -> CGFloat {
        return 42
    }

    static func mockRandom() -> CGFloat {
        return mockRandom(min: .leastNormalMagnitude, max: .greatestFiniteMagnitude)
    }

    static func mockRandom(min: CGFloat, max: CGFloat) -> CGFloat {
        return .random(in: min...max)
    }
}

extension CGRect: AnyMockable, RandomMockable {
    static func mockAny() -> CGRect {
        return .init(x: 0, y: 0, width: 400, height: 200)
    }

    static func mockRandom() -> CGRect {
        return mockRandom(minWidth: 0, minHeight: 0)
    }

    static func mockRandom(minWidth: CGFloat = 0, minHeight: CGFloat = 0) -> CGRect {
        return .init(
            origin: .mockRandom(),
            size: .mockRandom(minWidth: minWidth, minHeight: minHeight)
        )
    }
}

extension CGPoint: AnyMockable, RandomMockable {
    static func mockAny() -> CGPoint {
        return .init(x: 0, y: 0)
    }

    static func mockRandom() -> CGPoint {
        return .init(
            x: .mockRandom(min: -1_000, max: 1_000),
            y: .mockRandom(min: -1_000, max: 1_000)
        )
    }
}

extension CGSize: AnyMockable, RandomMockable {
    static func mockAny() -> CGSize {
        return .init(width: 400, height: 200)
    }

    static func mockRandom() -> CGSize {
        return .mockRandom(minWidth: 0, minHeight: 0)
    }

    static func mockRandom(minWidth: CGFloat = 0, minHeight: CGFloat = 0) -> CGSize {
        return .init(
            width: .mockRandom(min: minWidth, max: minWidth + 1_000),
            height: .mockRandom(min: minHeight, max: minHeight + 1_000)
        )
    }
}

extension CGColor: AnyMockable, RandomMockable {
    static func mockAny() -> Self {
        return UIColor.mockAny().cgColor as! Self
    }

    static func mockRandom() -> Self {
        return UIColor.mockRandom().cgColor as! Self
    }
}