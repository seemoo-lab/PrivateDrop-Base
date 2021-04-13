//
//  LibarchiveTests.swift
//  PrivateDrop BaseTests
//
//  Created by Alex - SEEMOO on 21.07.20.
//

import Libarchive
import Security
import XCTest

class LibarchiveTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func createTestArchive() throws -> Data {
        let testData = "This is a test file".data(using: .utf8)!

        let archivedData = try Libarchive.createCPIO(with: testData, filename: "testData.txt")

        return archivedData
    }

    func testWrite() throws {
        var randomDataBuffer = [UInt8](repeating: 0, count: 3096)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomDataBuffer.count, &randomDataBuffer)
        let randomData = Data(randomDataBuffer)

        let archivedData = try Libarchive.createCPIO(with: randomData, filename: "testData")

        XCTAssertGreaterThan(archivedData.count, 0)
    }

    func testRead() throws {
        let archive = try createTestArchive()

        let exportDir = try Libarchive.readCPIO(cpio: archive)

        // Read the files
        let file = try Data(contentsOf: exportDir.appendingPathComponent("testData.txt"))

        XCTAssertEqual(String(data: file, encoding: .utf8), "This is a test file")

        // Remove content of export dir
        if exportDir.lastPathComponent.contains("OpenDrop") {
            try FileManager.default.removeItem(at: exportDir)
        }
    }

    func testArchiveDirectory() throws {
        #if os(macOS)
            let archiveDirectory = URL(fileURLWithPath: #file).deletingLastPathComponent()
                .appendingPathComponent("TestResources/Test-Archive")
        #else
            let archiveDirectory = Bundle(for: LibarchiveTests.self).resourceURL!
                .appendingPathComponent(
                    "Test-Archive")
        #endif

        let archive = try Libarchive.archiveToCPIO(directory: archiveDirectory)

        // Unarchive
        let exportDir = try Libarchive.readCPIO(cpio: archive)

        let baseDir = exportDir.appendingPathComponent("Test-Archive")

        // Read the files
        let textFile = try Data(contentsOf: baseDir.appendingPathComponent("TextFile.txt"))

        XCTAssertEqual(
            String(data: textFile, encoding: .utf8),
            "This is a sample text file for archiving with libarchive\n")

        let owlFile = try Data(contentsOf: baseDir.appendingPathComponent("owl.png"))

        let originalOwlFile = try Data(
            contentsOf: archiveDirectory.appendingPathComponent("owl.png"))

        XCTAssertEqual(owlFile, originalOwlFile)

        let btleMap = try Data(contentsOf: baseDir.appendingPathComponent("subdir/btlemap.png"))

        let originalBtleMap = try Data(
            contentsOf: archiveDirectory.appendingPathComponent("subdir/btlemap.png"))

        XCTAssertEqual(btleMap, originalBtleMap)

        // Remove content of export dir
        if exportDir.lastPathComponent.contains("OpenDrop") {
            try FileManager.default.removeItem(at: exportDir)
        }
    }
}
