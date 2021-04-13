//
//  Verifier.swift
//  PSI
//
//  Created by Alex - SEEMOO on 16.07.20.
//

import Foundation
import Relic

public protocol VerifierDelegate: AnyObject {
    func finishedVerifying()
    func startedCalculatingV()
    func finishedCalculatingV()
}

/// The class models the **verifier** of the PSI protocol.
/// The verifier, as a first step, creates encrypted and hashed Y-Values and sends them to the Prover.
/// The Prover will create a Proof-of-Knowledge and send its complete encrypted address book U-values.
/// By **verifiying** the proof-of-knowledge it checks if the Prover manipulated the Y-Values
/// and is able to check if one of its ids are in the prover's address book when using the U-Values.
public class Verifier {
    var ids: [String]
    var y = [ec_t]()
    var a = [bn_t]()
    var hashedInputs = [ec_t]()
    var v = [bn_t]()
    weak var delegate: VerifierDelegate?

    let precomputed: Bool

    /// Initialize the verifier with its own contact ids.
    /// - Parameter ids: Contact ids should be linked to the verifiers, like its phone number or email address
    /// - Throws: Erorr if the framework is not initialized with `PSI.initialize()`
    public init(ids: [String]) throws {
        guard PSI.isInitialized else {
            throw Error.notInitialized
        }

        self.ids = ids
        self.precomputed = false
    }

    /// Initialize the verifier with pre-generated data
    ///
    /// The Verifier's values can be pre-generated and validated by a trusted third party to increase the user's security.
    /// The trusted third party provides those values and it must make sure that these values are correct
    /// - Parameters:
    ///   - ids: Contact ids linked to the verifier
    ///   - y: The pre-generated y-values in Data representation
    ///   - a: the pre-generated a-values in Data representation
    ///   - hashes: The pre-generated hashes in Data representation
    public init(ids: [String], y: [Data], a: [Data], hashes: [Data]) throws {
        guard PSI.isInitialized else {
            throw Error.notInitialized
        }

        self.ids = ids
        self.y = y.map(ECC.readPoint(from:))
        self.a = a.map(BN.bigNumberFromBinary(data:))
        self.hashedInputs = hashes.map(ECC.readPoint(from:))
        self.precomputed = true
    }

    /// Generates the Y values from the contact ids that must be sent to the prover.
    /// - Returns: Y values, must be sent to the prover
    public func generateY() -> [ec_t] {
        guard !precomputed else {
            return self.y
        }

        y = [ec_t]()
        a = [bn_t]()
        hashedInputs = [ec_t]()

        // Calculate the hashes
        self.ids.forEach { (id) in
            hashedInputs.append(ECC.hashInputToECPoints(input: id))
            // Fill the as with random values
            a.append(BN.generateRandomInZq())
        }

        // Calculate Y from hashes and A values
        for i in 0..<hashedInputs.count {
            var hashPoint = hashedInputs[i]
            var aVal = a[i]
            var result = ec_t()
            ec_multiply(&result, &hashPoint, &aVal)
            y.append(result)
        }

        return y
    }

    /// This function validates that the y-values match to the current state.
    ///
    /// Used if the y-values are pre-computed and imported
    /// - Parameter y: y
    /// - Returns: True if the generated values match
    public func validateY(with y: [Data]) -> Bool {

        var yValidation = [ec_t]()
        let yComparison = y.map(ECC.readPoint(from:))

        // Calculate Y from hashes and A values
        for i in 0..<hashedInputs.count {
            var hashPoint = hashedInputs[i]
            var aVal = a[i]
            var result = ec_t()
            ec_multiply(&result, &hashPoint, &aVal)
            yValidation.append(result)
        }

        // Check if they have the same amount of values
        guard yValidation.count == yComparison.count else { return false }

        // Check if the values are matching
        for yVal in yComparison {
            if yValidation.contains(where: { ECC.areEqual(a: yVal, b: $0) }) == false {
                return false
            }
        }

        return true
    }

    /// Generate Y values in a data representatios so they can be shared over the network
    /// - Returns: an array of serialized y values
    public func generateYFromIds() -> [Data] {
        self.generateY()
            .map(ECC.writePointToData(point:))
    }

    /// Verify the received z values by using the PoKs
    /// - Parameters:
    ///   - z: Received z values
    ///   - pokZ: a PoK value
    ///   - pokAs: an array of PoK values. One for each z value
    /// - Throws: Error if the verification fails
    public func verify(z: [ec_t], pokZ: bn_t, pokAs: [ec_t]) throws {
        try self.verifyPOK(z: z, pokZ: pokZ, pokAs: pokAs)
        self.calculateV(z: z)
    }

    /// Verify the PoK and throw an error if the verification fails. Checks if the PoK is actually made from the sent y values and not tampered
    /// - Parameters:
    ///   - z: Z values from Prover
    ///   - pokZ: PoKZ from Prover
    ///   - pokAs: PoKAs from Prover
    /// - Throws: Error if the verification failes
    public func verifyPOK(z: [ec_t], pokZ: bn_t, pokAs: [ec_t]) throws {
        guard z.count == pokAs.count else {
            throw Error.verificationFailed
        }

        // Hash all a,y,z
        let hashValues = y + pokAs + z
        var c = BN.hash(ecPoints: hashValues)
        c = BN.modulus(a: c, m: ECC.order)

        for i in 0..<y.count {
            var ahci = ECC.mulitply(ecPoint: z[i], number: c)
            ahci = ECC.add(a: pokAs[i], b: ahci)

            let gzi = ECC.mulitply(ecPoint: y[i], number: pokZ)

            if ECC.areEqual(a: gzi, b: ahci) == false {
                throw Error.verificationFailed
            }
        }

        self.delegate?.finishedVerifying()
    }

    /// Calculate the v values from  z values
    /// - Parameter z: The z values from the prover. Used to generate the v values which can be used for intersecting
    public func calculateV(z: [ec_t]) {
        self.delegate?.startedCalculatingV()
        v = [bn_t]()
        for i in 0..<z.count {
            let inversedExponent = BN.pow(
                base: a[i], exponent: Parameters.EULER_THEOREM, modulus: ECC.order)

            let zinv = ECC.mulitply(ecPoint: z[i], number: inversedExponent)
            let hashedPoints = BN.hash(ecPoints: [hashedInputs[i], zinv])
            v.append(hashedPoints)
        }
        self.delegate?.finishedCalculatingV()
    }

    /// Verify the received z values by using the PoKs
    /// - Parameters:
    ///   - z: Received z values as an array of Data
    ///   - pokZ: a PoK value serialized to data
    ///   - pokAs: an array of PoK values. One for each z value. Serialized to a data array
    /// - Throws: Error if the verification fails
    public func verify(z: [Data], pokZ: Data, pokAs: [Data]) throws {
        let zv = z.map(ECC.readPoint(from:))
        let pokZv = BN.bigNumberFromBinary(data: pokZ)
        let pokAsv = pokAs.map(ECC.readPoint(from:))

        try verify(z: zv, pokZ: pokZv, pokAs: pokAsv)
    }

    /// Intersect the received u values with the generate v values
    /// - Parameter u: u values received from the prover
    /// - Returns: The actual ids that intersect with the set of the verifier. Can be an empty array if no intersections happen
    public func intersect(with u: [bn_t]) -> [String] {

        var matchingIds = [String]()
        for i in 0..<ids.count {
            if u.first(where: { BN.areEqual(a: $0, b: v[i]) }) != nil {
                matchingIds.append(ids[i])
            }
        }
        return matchingIds
    }

    /// Intersect the received u values with the generate v values
    /// - Parameter u: u values received from the prover as serialized data
    /// - Returns: The actual ids that intersect with the set of the verifier. Can be an empty array if no intersections happen
    public func intersect(with u: [Data]) -> [String] {
        let uv = u.map(BN.bigNumberFromBinary(data:))
        return self.intersect(with: uv)
    }

    public func precompute() -> VerifierPrecomputed {
        let y = generateYFromIds()

        let hashes = self.hashedInputs.map(ECC.writePointToData(point:))
        let a = self.a.map(BN.writeToBinary(num:))

        return VerifierPrecomputed(yValues: y, hashes: hashes, aValues: a)
    }

    public enum Error: Swift.Error {
        case verificationFailed
        case notInitialized
    }

}

public struct VerifierPrecomputed {
    public let yValues: [Data]
    public let hashes: [Data]
    public let aValues: [Data]
}
