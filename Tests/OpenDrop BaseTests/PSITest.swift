//
//  PSITest.swift
//  PrivateDrop BaseTests
//
//  Created by Alex - SEEMOO on 16.07.20.
//

import XCTest

@testable import PSI
@testable import PrivateDrop_Base

class PSITest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        print("Configuration: ")
        print("FP_PRIME: \(FP_PRIME)")

        PSI.initialize(config: .init(useECPointCompression: true))

    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    func generateRandomTestSet(of size: Int) -> [String] {
        var testSet = [String]()

        for _ in 0..<size {
            testSet.append(randomString(length: 15))
        }

        return testSet
    }

    func testBigNumberFromString() {
        let number = BN.bigNumberFromString(string: "2")
        print("Number: \(number)")
    }

    func testHashStringToCurvePoint() {
        let string = "Sample String"
        let ec_1 = ECC.hashInputToECPoints(input: string)
        let ec_2 = ECC.hashInputToECPoints(input: string)
        XCTAssert(ECC.areEqual(a: ec_1, b: ec_2))
        XCTAssert(!ECC.areEqual(a: ec_1, b: ec_t()))
    }

    func testGetOrder() {
        var order = BN.newBN()
        ec_curve_get_order(&order)
        print("Order: \(order)")
    }

    func testCurveFunctions() {
        test_ec_curve_functions()
    }

    func testParallelUComputation() throws {
        PSI.initialize(config: .init(useECPointCompression: true, parallelize: true))

        for _ in 0...20 {
            for setSize in [100, 1000] {
                let testSet = TestSetup.generateRandomTestSet(of: setSize)
                let prover = try Prover(contacts: testSet)

                let u = prover.generateU()
                XCTAssertEqual(u.count, testSet.count)
            }
        }

    }

    func testPerformanceU() throws {
        PSI.initialize(config: .init(useECPointCompression: true, parallelize: true))
        self.measure {
            let testSet = TestSetup.generateRandomTestSet(of: 5_000)
            let prover = try! Prover(contacts: testSet)

            let u = prover.generateU()
            XCTAssertEqual(u.count, testSet.count)
        }
    }

    func testProtocolFlow() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.]

        let prover = try Prover(contacts: ["+491755016748", "+49624154200", "+4961511627303"])
        let verifier = try Verifier(ids: [
            "+49624154200", "+4961511627303", "+12498340392", "+249878937543",
        ])

        // 1. Step happens on R -> Can be precomuted (but is also very fast)
        // Can be precomputed
        let y = verifier.generateY()

        // Precomputed
        let u = prover.generateU()

        // Send Y to S (prover)
        let z = prover.generateZ(from: y)
        let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)

        // Send u, pokZ, pokAs, and z to R (verifier)
        try verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

        // Intersect
        let matches = verifier.intersect(with: u)

        XCTAssertEqual(matches, ["+49624154200", "+4961511627303"])
    }

    // MARK: - Performance tests

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        let prover = try Prover(contacts: [
            "+49624154200", "+4961511627303", "+12498340392", "+249878937543",
        ])
        let verifier = try Verifier(ids: ["+491755016748", "+49624154200", "+4961511627303"])

        // 1. Step happens on R -> Can be precomuted (but is also very fast)
        // Can be precomputed
        let y = verifier.generateY()

        // Precomputed
        let u = prover.generateU()

        self.measure {
            // Send Y to S (prover)
            let z = prover.generateZ(from: y)
            let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)

            // Send u, pokZ, pokAs, and z to R (verifier)
            try! verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

            // Intersect
            let matches = verifier.intersect(with: u)

            XCTAssertEqual(matches, ["+49624154200", "+4961511627303"])
        }
    }

    func testPerformanceWithoutPrecomputation() throws {
        self.measure {
            let prover = try! Prover(contacts: ["+491755016748", "+49624154200", "+4961511627303"])
            let verifier = try! Verifier(ids: [
                "+49624154200", "+4961511627303", "+12498340392", "+249878937543",
            ])

            // 1. Step happens on R -> Can be precomuted (but is also very fast)
            // Can be precomputed
            let y = verifier.generateY()

            // Precomputed
            let u = prover.generateU()

            // Send Y to S (prover)
            let z = prover.generateZ(from: y)
            let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)

            // Send u, pokZ, pokAs, and z to R (verifier)
            try! verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

            // Intersect
            let matches = verifier.intersect(with: u)

            XCTAssertEqual(matches, ["+49624154200", "+4961511627303"])
        }
    }

    func testLargeGenerationOfY() throws {
        // This is an example of a performance test case.
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 1_000)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        // If verifiers sends its contacts and the prover its ids the algorithm will be a lot slower.
        // This tests checks how much slower and which parts are slower
        _ = try Prover(contacts: ids)
        let verifier = try Verifier(ids: contacts)

        // 1. Step happens on R -> Can be precomuted (but is also very fast)
        var y: [ec_t] = []
        self.measure {
            y = verifier.generateY()
        }
        XCTAssert(y.isEmpty == false)
    }

    // MARK: Convenience

    /// The convenience functions use only swift types (mostly data) to share values. This needs additional conversion overhead, but is also necessary for network transfers
    /// Testing showed that the overhead in conversion is marginal (0.029s to 0.03s for 10.000 entries)
    func testConvenienceFunctions() throws {
        let proverContacts = self.generateRandomTestSet(of: 10_000)
        let verifierIds = Array(proverContacts.shuffled()[0...7])

        let verifier = try Verifier(ids: verifierIds)
        let prover = try Prover(contacts: proverContacts)

        // Pre-computation
        let y = verifier.generateYFromIds()
        let u = prover.generateUForVerifier()

        self.measure {

            let z = prover.generateZValuesForVerifier(from: y)
            let (pokAs, pokZ) = prover.generatePoKForVerifier(from: y, z: z)

            do {
                try verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)
                let matches = verifier.intersect(with: u)
                XCTAssertEqual(matches, verifierIds)
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    func testPrecomputation() throws {
        let proverContacts = self.generateRandomTestSet(of: 100_000)
        let prover = try Prover(contacts: proverContacts)

        self.measure {
            _ = prover.generateUForVerifier()
        }
    }

    // MARK: Binary conversion

    func testWriteBNToBinary() throws {
        let proverContacts = self.generateRandomTestSet(of: 10)
        let prover = try Prover(contacts: proverContacts)

        let uValues = prover.generateU()
        // Write to binary
        let binaryUs = uValues.map(BN.writeToBinary(num:))

        // Read values
        let readUs = binaryUs.map(BN.bigNumberFromBinary(data:))

        // Compare
        for i in 0..<readUs.count {
            XCTAssertFalse(BN.areEqual(a: readUs[i], b: BN.newBN()))
            XCTAssertFalse(BN.areEqual(a: uValues[i], b: BN.newBN()))
            XCTAssertTrue(BN.areEqual(a: readUs[i], b: uValues[i]))
        }
    }

    func testWriteECPointToBinary() throws {
        let verifierIds = self.generateRandomTestSet(of: 10)
        let verifier = try Verifier(ids: verifierIds)

        let yValues = verifier.generateY()
        // Write to binary
        let binaryYs = yValues.map(ECC.writePointToData(point:))

        // Read values
        let readYs = binaryYs.map(ECC.readPoint(from:))

        // Compare
        for i in 0..<readYs.count {
            XCTAssertFalse(ECC.areEqual(a: readYs[i], b: ec_t()))
            XCTAssertFalse(ECC.areEqual(a: yValues[i], b: ec_t()))
            XCTAssertTrue(ECC.areEqual(a: yValues[i], b: readYs[i]))
        }
    }

    // MARK: - iOS / macOS interoperability

    func generateVerifierTestInput() throws {

        let verifierIds = self.generateRandomTestSet(of: 4)
        let verifier = try Verifier(ids: verifierIds)
        let yValues = verifier.generateY().map(ECC.writePointToData(point:)).map {
            $0.base64EncodedString()
        }
        let aValues = verifier.a.map(BN.writeToBinary(num:)).map { $0.base64EncodedString() }
        let hValues = verifier.hashedInputs.map(ECC.writePointToData(point:)).map {
            $0.base64EncodedString()
        }

        print(
            "VerifierIds: \(verifierIds)\n\n Y values: \(yValues) \n\n a values: \(aValues) \n\n h  values: \(hValues)"
        )

    }

    /// This test is used for testing the compatibility between iOS and macOS - Test is invalid, because we changed the curve in use
    func testIOSVerifier() throws {
        // TODO: Generate input for P-255 Curve 25519

        // This test is done as follows
        // The verifier code is run on iOS. Y, a, h values will be generated and stored as base64 strings
        // Those values are imported into an iOSVerifier
        // The iOSVerifier runs against a newly generated prover

        guard FP_PRIME == 255 else { return }

        let verifierIds = [
            "ui6Niu2mrUKAYCc", "qbj7EoGjp6hs2gB", "sGT4egDAltVe6ea", "j1wuggU7TchR1Uq",
        ]

        var proverContacts = self.generateRandomTestSet(of: 10)
        proverContacts.append(contentsOf: verifierIds[0...1])
        proverContacts.shuffle()

        let prover = try Prover(contacts: proverContacts)

        let iOSVerifier = try Verifier(ids: verifierIds)
        iOSVerifier.a = [
            "C9CHJaYENox39X2dIDeFexFRgLR8BEwOk612W9YgSNc=",
            "Dau07nOcudbMhB8f+C1hMENO560Vj7MCn5pje0+rewA=",
            "A3vc9d/GL1KmJFvv44uNxsQJ49vwG2pYqANzovUXeGs=",
            "Dwmp+mqPa5dvHR5zDeFJ4tWI1Aol7Ws4p3UuhBE3dmw=",
        ]
        .map({ Data(base64Encoded: $0)! }).map(BN.bigNumberFromBinary(data:))
        iOSVerifier.y = [
            "BA9WaJY3Zz7NZOPmbh0Z4MVxP7jrgWOkijKf+OCv/gr9Fgnl6vv38F4YzCKmEpmWfDchpFXe4JhG0+H/R9Q/O7o=",
            "BEH2YyS2spYaW0PUpP3y8e86LY85AVC52eX2i74E1MMvbFw4jw186nJxmKCnn2YDN7hrmvJyKJYkiMme7oNyOZk=",
            "BHoGKMvlzBEiitO5inbHjk829thwQ7yB5zf1vkoXkKPwd8hERkLot9r5PQvrmgRC5B+ugDNGrXB0YVBh1VsRJCk=",
            "BDw0TchvE///I6z4SDXooFSQWmFUEpkucMVTeQOPAuxOLGMsoYCgg6QKJdDQtrQljv+psJKwFZH6RWWoQpeBWxI=",
        ]
        .map({ Data(base64Encoded: $0)! }).map(ECC.readPoint(from:))

        iOSVerifier.hashedInputs = [
            "BHkrQYl5hedcNEs2EoA/cbociCyLJz1bATiMozC2nzrJclxuSIoRo/nKuEKY0nfmKsBUU3VgYhh07vsR8jE0ZE8=",
            "BGNA75UUuzGuUgr7GPMAfoy2UorpHvFN6olO93pCN0tTV02/A+WJ3fdFDqJIegx/S5Z5Qm3GEOp25YxI48fePPw=",
            "BB4W8Y4BV2Cr2udiLs9YKfzoZWnut4T6DlzcRPxwMFpGQhxRycPx7w4mRXCOpDocn8npUjcBqdQaAkLyMYGjtFc=",
            "BCGHqxyRJDfqjXnPgyJw2NC3P7nsHflRO2S+gz9lJHaLL7GLPn3+OvMfCh9wU8a4oof8WWFev15ZE6/3+FypFHY=",
        ]
        .map({ Data(base64Encoded: $0)! }).map(ECC.readPoint(from:))

        let u = prover.generateU()
        let y = iOSVerifier.y

        // Send Y to S (prover)
        let z = prover.generateZ(from: y)
        let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)

        // Send u, pokZ, pokAs, and z to R (verifier)
        try iOSVerifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

        // Intersect
        let matches = iOSVerifier.intersect(with: u)
        XCTAssertEqual(matches, ["ui6Niu2mrUKAYCc", "qbj7EoGjp6hs2gB"])
    }

    func testMacOSVerifier() throws {
        // Test is invalid, because we changed the curve in use

        // This test is done as follows
        // The verifier code is run on macOS once. Y, a, h values will be generated and stored as base64 strings
        // Those values are imported into an macOSVerifier

        guard FP_PRIME == 255 else { return }

        let verifierIds = [
            "zr624bXzyyZaQHT", "KcYw8iwYyBxXIZ5", "YZd60v12qDLZ9h0", "Uj0Qy9g6edrVSPf",
        ]

        var proverContacts = self.generateRandomTestSet(of: 10)
        proverContacts.append(contentsOf: verifierIds[0...1])
        proverContacts.shuffle()

        let prover = try Prover(contacts: proverContacts)

        let macOSVerifier = try Verifier(ids: verifierIds)
        macOSVerifier.a = [
            "DXgv8u5j5mA49GiIT1AuYB4EiwmR2+hie9AKorSTWX0=",
            "C6F73kN92gvY+aVzfGUdgTyCZfZb9hMBmSqbOplB6+8=",
            "C8IroTwuefIxYCm+aFNNv7Ti5ghbv7gLW9R4QVMUmRw=",
            "BRCviTpxIhMaSH4K3p7ySSl58e49gvkDW0Wg2gdVBKA=",
        ]
        .map({ Data(base64Encoded: $0)! }).map(BN.bigNumberFromBinary(data:))
        macOSVerifier.y = [
            "BBd5ZuSbH9IFkDGZEjQ2yq1fH7gKbBafDECGMcPf/uxQeb13L/9KJZ5o72yVjeADC5dznJuTuF/Ti04MghwuBVQ=",
            "BA+cItcTf2ji1PTSf9uqSOppVcuAB23VwulHqh3GK0InISl/Am2cRgKFC8Tq4EYoq+xvwD1/vpblvawp4LfCmb4=",
            "BHcQ/WoZ04zfX9MP3wD+Hrdft5uGvhvVwnwWETMvQKWCTgtU00KLiUPWDE2r3QIoCEqY/8oqtNt8Os8BD5mqHQQ=",
            "BFj06TASj00ru7NI24EzTK96H1vsPZqGNmhRJATPGBK4FW6wR5cFnyMMBs0F8WqLiqK13MZIKo/5ZmN5K17YzuU=",
        ]
        .map({ Data(base64Encoded: $0)! }).map(ECC.readPoint(from:))

        macOSVerifier.hashedInputs = [
            "BBbncnNRXfAuDCaNLxya08lGQWP7b/usx11ZhFFINQX5eEswYaMA9EZQq3d4WS+Je+a4OEGdSc/8umwnQSr0Ob8=",
            "BEC7nYTA+hKnWCxBfD226oREvod0aKeRrdlTi5d1vXcBQZmSnsbF7LJ5MjHqjAZ3FGXedI8ignrIXKJ8aHEKwKw=",
            "BBfhxd408xyJqxlPYobqPTJw3IdhQ8knW5HyLYpq5JBODGe5cgZlHUaun6u34+c9Y7ouVXOCejsAHcTLtQ3M3vs=",
            "BBzQHL08C/eY7urZIPrpY+hGJWU5NpQCVptyPZzTTvq8UX1Mi0JsSAbMwz/Qpsja7gdT1AqHNbnmCckfXUWOUqI=",
        ]
        .map({ Data(base64Encoded: $0)! }).map(ECC.readPoint(from:))

        let u = prover.generateU()
        let y = macOSVerifier.y

        // Send Y to S (prover)
        let z = prover.generateZ(from: y)
        let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)

        // Send u, pokZ, pokAs, and z to R (verifier)
        try macOSVerifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

        // Intersect
        let matches = macOSVerifier.intersect(with: u)
        XCTAssertEqual(matches, ["zr624bXzyyZaQHT", "KcYw8iwYyBxXIZ5"])
    }

}
