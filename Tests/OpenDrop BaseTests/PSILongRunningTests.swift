//
//  PSILongRunningTests.swift
//  ASN1Decoder
//
//  Created by Alex - SEEMOO on 22.07.20.
//

import Foundation
import XCTest

@testable import PSI
@testable import PrivateDrop_Base

class PSILongRunningTests: XCTestCase {

    override func setUpWithError() throws {
        PSI.initialize(config: .init(useECPointCompression: true))
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

    func testLargeContactsPerformance() throws {
        // This is an example of a performance test case.
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 10_000)
        XCTAssertEqual(contacts.count, 10002)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        let prover = try Prover(contacts: contacts)
        let verifier = try Verifier(ids: ids)

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

    func testLargeY() throws {
        // This is an example of a performance test case.
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 1_000)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        // If verifiers sends its contacts and the prover its ids the algorithm will be a lot slower.
        // This tests checks how much slower and which parts are slower
        let _ = try Prover(contacts: ids)
        let verifier = try Verifier(ids: contacts)

        self.measure {
            let _ = verifier.generateY()
        }

    }

    func testLargeZ() throws {
        // This is an example of a performance test case.
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 1_000)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        // If verifiers sends its contacts and the prover its ids the algorithm will be a lot slower.
        // This tests checks how much slower and which parts are slower
        let prover = try Prover(contacts: ids)
        let verifier = try Verifier(ids: contacts)

        // Can be precomputed
        let y = verifier.generateY()

        self.measure {
            let _ = prover.generateZ(from: y)
        }

    }

    func testLargePoK() throws {
        // This is an example of a performance test case.
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 1_000)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        // If verifiers sends its contacts and the prover its ids the algorithm will be a lot slower.
        // This tests checks how much slower and which parts are slower
        let prover = try Prover(contacts: ids)
        let verifier = try Verifier(ids: contacts)

        // Can be precomputed
        let y = verifier.generateY()
        let z = prover.generateZ(from: y)
        self.measure {
            _ = prover.generatePoK(from: y, z: z)
        }

    }

    func testLargeVerify() throws {
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 1_000)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        // If verifiers sends its contacts and the prover its ids the algorithm will be a lot slower.
        // This tests checks how much slower and which parts are slower
        let prover = try Prover(contacts: ids)
        let verifier = try Verifier(ids: contacts)

        // Can be precomputed
        let y = verifier.generateY()
        let _ = prover.generateU()
        let z = prover.generateZ(from: y)
        let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)

        // Very slow
        self.measure {
            try! verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)
        }

    }

    func testLargeIntersect() throws {
        var contacts = ["+49624154200", "+4961511627303"]

        contacts += self.generateRandomTestSet(of: 1_000)

        let ids = ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"]

        // If verifiers sends its contacts and the prover its ids the algorithm will be a lot slower.
        // This tests checks how much slower and which parts are slower
        let prover = try Prover(contacts: ids)
        let verifier = try Verifier(ids: contacts)

        // Can be precomputed
        let y = verifier.generateY()
        let u = prover.generateU()
        let z = prover.generateZ(from: y)
        let (pokAs, pokZ) = prover.generatePoK(from: y, z: z)
        try! verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

        // Very fast
        self.measure {
            _ = verifier.intersect(with: u)
        }
    }
}
