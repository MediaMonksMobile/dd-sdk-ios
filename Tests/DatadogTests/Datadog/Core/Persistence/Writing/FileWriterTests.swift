/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class FileWriterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        temporaryDirectory.create()
    }

    override func tearDown() {
        temporaryDirectory.delete()
        super.tearDown()
    }

    func testItWritesDataToSingleFile() throws {
        let writer = FileWriter(
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: PerformancePreset.mockAny(),
                dateProvider: SystemDateProvider()
            )
        )

        writer.write(value: ["key1": "value1"])
        writer.write(value: ["key2": "value2"])
        writer.write(value: ["key3": "value3"])

        XCTAssertEqual(try temporaryDirectory.files().count, 1)
        let data = try temporaryDirectory.files()[0].read()

        let reader = DataBlockReader(data: data)
        var block = try reader.next()
        XCTAssertEqual(block?.type, .event)
        XCTAssertEqual(block?.data, #"{"key1":"value1"}"#.utf8Data)
        block = try reader.next()
        XCTAssertEqual(block?.type, .event)
        XCTAssertEqual(block?.data, #"{"key2":"value2"}"#.utf8Data)
        block = try reader.next()
        XCTAssertEqual(block?.type, .event)
        XCTAssertEqual(block?.data, #"{"key3":"value3"}"#.utf8Data)
    }

    func testGivenErrorVerbosity_whenIndividualDataExceedsMaxWriteSize_itDropsDataAndPrintsError() throws {
        let dd = DD.mockWith(logger: CoreLoggerMock())
        defer { dd.reset() }

        let writer = FileWriter(
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock(
                    maxFileSize: .max,
                    maxDirectorySize: .max,
                    maxFileAgeForWrite: .distantFuture,
                    minFileAgeForRead: .mockAny(),
                    maxFileAgeForRead: .mockAny(),
                    maxObjectsInFile: .max,
                    maxObjectSize: 23 // 23 bytes is enough for TLV with {"key1":"value1"} JSON
                ),
                dateProvider: SystemDateProvider()
            )
        )

        writer.write(value: ["key1": "value1"]) // will be written

        XCTAssertEqual(try temporaryDirectory.files().count, 1)
        var reader = try DataBlockReader(data: temporaryDirectory.files()[0].read())
        var blocks = try XCTUnwrap(reader.all())
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].data, #"{"key1":"value1"}"#.utf8Data)

        writer.write(value: ["key2": "value3 that makes it exceed 23 bytes"]) // will be dropped

        reader = try DataBlockReader(data: temporaryDirectory.files()[0].read())
        blocks = try XCTUnwrap(reader.all())
        XCTAssertEqual(blocks.count, 1) // same content as before
        XCTAssertEqual(dd.logger.errorLog?.message, "Failed to write data")
        XCTAssertEqual(dd.logger.errorLog?.error?.message, "data exceeds the maximum size of 23 bytes.")
    }

    func testGivenErrorVerbosity_whenDataCannotBeEncoded_itPrintsError() throws {
        let dd = DD.mockWith(logger: CoreLoggerMock())
        defer { dd.reset() }

        let writer = FileWriter(
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: PerformancePreset.mockAny(),
                dateProvider: SystemDateProvider()
            )
        )

        writer.write(value: FailingEncodableMock(errorMessage: "failed to encode `FailingEncodable`."))

        XCTAssertEqual(dd.logger.errorLog?.message, "Failed to write data")
        XCTAssertEqual(dd.logger.errorLog?.error?.message, "failed to encode `FailingEncodable`.")
    }

    func testGivenErrorVerbosity_whenIOExceptionIsThrown_itPrintsError() throws {
        let dd = DD.mockWith(logger: CoreLoggerMock())
        defer { dd.reset() }

        let writer = FileWriter(
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: PerformancePreset.mockAny(),
                dateProvider: SystemDateProvider()
            )
        )

        writer.write(value: ["ok"]) // will create the file
        try? temporaryDirectory.files()[0].makeReadonly()
        writer.write(value: ["won't be written"])
        try? temporaryDirectory.files()[0].makeReadWrite()

        XCTAssertEqual(dd.logger.errorLog?.message, "Failed to write data")
        XCTAssertTrue(dd.logger.errorLog!.error!.message.contains("You don’t have permission"))
    }

    /// NOTE: Test added after incident-4797
    func testWhenIOExceptionsHappenRandomly_theFileIsNeverMalformed() throws {
        let writer = FileWriter(
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock(
                    maxFileSize: .max,
                    maxDirectorySize: .max,
                    maxFileAgeForWrite: .distantFuture, // write to single file
                    minFileAgeForRead: .distantFuture,
                    maxFileAgeForRead: .distantFuture,
                    maxObjectsInFile: .max, // write to single file
                    maxObjectSize: .max
                ),
                dateProvider: SystemDateProvider()
            )
        )

        let ioInterruptionQueue = DispatchQueue(label: "com.datadohq.file-writer-random-io")

        func randomlyInterruptIO(for file: File?) {
            ioInterruptionQueue.async { try? file?.makeReadonly() }
            ioInterruptionQueue.async { try? file?.makeReadWrite() }
        }

        struct Foo: Codable {
            var foo = "bar"
        }

        // Write 300 of `Foo`s and interrupt writes randomly
        (0..<300).forEach { _ in
            writer.write(value: Foo())
            randomlyInterruptIO(for: try? temporaryDirectory.files().first)
        }

        ioInterruptionQueue.sync { }

        XCTAssertEqual(try temporaryDirectory.files().count, 1)

        let data = try temporaryDirectory.files()[0].read()
        let blocks = try DataBlockReader(data: data).all()

        // Assert that data written is not malformed
        let jsonDecoder = JSONDecoder()
        let events = try blocks.map { try jsonDecoder.decode(Foo.self, from: $0.data) }

        // Assert that some (including all) `Foo`s were written
        XCTAssertGreaterThan(events.count, 0)
        XCTAssertLessThanOrEqual(events.count, 300)
    }

    func testItWritesEncryptedDataToSingleFile() throws {
        // Given 
        let writer = FileWriter(
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: PerformancePreset.mockAny(),
                dateProvider: SystemDateProvider()
            ),
            encryption: DataEncryptionMock(
                encrypt: { _ in "foo".utf8Data }
            )
        )

        // When
        writer.write(value: ["key1": "value1"])
        writer.write(value: ["key2": "value3"])
        writer.write(value: ["key3": "value3"])

        // Then
        XCTAssertEqual(try temporaryDirectory.files().count, 1)
        let data = try temporaryDirectory.files()[0].read()

        let reader = DataBlockReader(data: data)
        var block = try reader.next()
        XCTAssertEqual(block?.type, .event)
        XCTAssertEqual(block?.data, "foo".utf8Data)
        block = try reader.next()
        XCTAssertEqual(block?.type, .event)
        XCTAssertEqual(block?.data, "foo".utf8Data)
        block = try reader.next()
        XCTAssertEqual(block?.type, .event)
        XCTAssertEqual(block?.data, "foo".utf8Data)
    }
}
