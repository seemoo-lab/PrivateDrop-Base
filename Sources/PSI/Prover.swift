//
//  Prover.swift
//  PSI
//
//  Created by Alex - SEEMOO on 16.07.20.
//

import Foundation
import Relic

/// This class models the prover of the PSI protocol.
/// The prover reacts to the verifier by generating the proof-of-knowledge (PoK) and sending its encrypted addressbook (U-Values) to the verifier.
/// The verifier is then able to check if it is part of the prover's addressbook.
public class Prover {
    var ids: [String]
    lazy var k: bn_t = {
        BN.generateRandomInZq()
    }()

    public var cachedU: [bn_t]?

    /// Initialize the prover with an array of contact ids.
    /// - Parameter contacts: Contact ids can be any strings like email addresses or phone numbers. e.g. `["john@appleseed.org"]`
    /// - Throws: Erorr if the framework is not initialized with `PSI.initialize()`
    public init(contacts: [String]) throws {
        guard PSI.isInitialized else {
            throw Error.notInitialized
        }
        self.ids = contacts
    }

    /// Generate the Z values from the received Y values. In this PSI implementation both are represented as points on an elliptic curve.
    /// The actual implementation is agnostic to the used curve
    /// - Parameter y: Received from the verifier.
    /// - Returns: Z values. Send them to the verifier
    public func generateZ(from y: [ec_t]) -> [ec_t] {
        let k = self.k

        var z = [ec_t]()

        for i in 0..<y.count {
            z.append(ECC.mulitply(ecPoint: y[i], number: k))
        }

        return z
    }

    /// Generate the Z values from the received Y values. In this PSI implementation both are represented as points on an elliptic curve.
    /// The actual implementation is agnostic to the used curve
    /// - Parameter y: Received from the verifier as serialized Data
    /// - Returns: Z values as serialized Data . Send them to the verifier as.
    public func generateZValuesForVerifier(from y: [Data]) -> [Data] {
        let yv = y.map(ECC.readPoint(from:))
        return self.generateZ(from: yv).map(ECC.writePointToData(point:))
    }

    /// Generates proof-of-knowledge (PoK) which is used to verify the z values received on the verifier side. The PoKs are both sent to the verifier
    /// - Parameter y: Received from the verifier
    /// - Parameter z: Z Values generated in the previous step
    /// - Returns: Two PoKs that must be sent to the verifier
    public func generatePoK(from y: [ec_t], z: [ec_t]) -> (pokAs: [ec_t], pokZ: bn_t) {
        let k = self.k

        let r = BN.generateRandomInZq()

        var aValues = [ec_t]()
        for i in 0..<y.count {
            aValues.append(ECC.mulitply(ecPoint: y[i], number: r))
        }

        // Hash all a,y,z
        let hashValues = y + aValues + z
        let c = BN.hash(ecPoints: hashValues)

        let kc = BN.multiply(a: k, b: c)
        let p = BN.add(a: r, b: kc)
        let pokZ = BN.modulus(a: p, m: ECC.order)

        return (pokAs: aValues, pokZ: pokZ)
    }

    /// Generates proof-of-knowledge (PoK) which is used to verify the z values received on the verifier side. The PoKs are both sent to the verifier
    /// - Parameter y: Received from the verifier (as serialized data)
    /// - Parameter z: Z Values generated in the previous step
    /// - Returns: Two PoKs that must be sent to the verifier (serialized as data)
    public func generatePoKForVerifier(from y: [Data], z: [Data]) -> (pokAs: [Data], pokZ: Data) {
        let yv = y.map(ECC.readPoint(from:))
        let z_ec = z.map(ECC.readPoint(from:))
        let (pokAs, pokZ) = self.generatePoK(from: yv, z: z_ec)

        return (pokAs.map(ECC.writePointToData(point:)), BN.writeToBinary(num: pokZ))
    }

    /// Generate's  the U values for all contacts that are used for the set intersection.
    /// - Returns: U values that must be sent to the verifier
    public func generateU() -> [bn_t] {
        if let cached = self.cachedU {
            return cached
        }

        let k = self.k
        var u = [bn_t?](repeating: nil, count: ids.count)

        let ids = self.ids

        let arrayQueue = DispatchQueue(
            label: "thread safe array", qos: .userInitiated, attributes: .concurrent,
            autoreleaseFrequency: .workItem, target: nil)

        if PSI.config.parallelize {
            DispatchQueue.concurrentPerform(iterations: ids.count) { (i) in
                let cId = self.ids[i]
                let hi = ECC.hashInputToECPoints(input: cId)
                let yi = ECC.mulitply(ecPoint: hi, number: k)
                let ui = BN.hash(ecPoints: [hi, yi])
                arrayQueue.async(flags: .barrier) {
                    u[i] = ui
                }
            }

            //            //Check if any entries are nil
            //            for i in 0..<u.count {
            //                if u[i] == nil {
            //                    let cId = self.ids[i]
            //                    let hi = ECC.hashInputToECPoints(input: cId)
            //                    let yi = ECC.mulitply(ecPoint: hi, number: k)
            //                    let ui = BN.hash(ecPoints: [hi, yi])
            //                    u[i] = ui
            //                }
            //            }

        } else {
            for i in 0..<self.ids.count {
                let cId = self.ids[i]
                let hi = ECC.hashInputToECPoints(input: cId)
                let yi = ECC.mulitply(ecPoint: hi, number: k)
                let ui = BN.hash(ecPoints: [hi, yi])
                u[i] = ui
            }
        }

        var updateU: [bn_t]!
        arrayQueue.sync {
            updateU = u.compactMap({ $0 })
        }

        assert(updateU.count == u.count)
        self.cachedU = updateU

        return updateU
    }

    /// Generate's  the U values for all contacts that are used for the set intersection.
    /// - Returns: U values (as serialized data) that must be sent to the verifier
    public func generateUForVerifier() -> [Data] {
        return generateU().map(BN.writeToBinary(num:))
    }

    public enum Error: Swift.Error {
        case notInitialized
    }
}
