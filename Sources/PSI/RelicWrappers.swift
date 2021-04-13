//
//  RelicWrappers.swift
//  PSI
//
//  Created by Alex - SEEMOO on 16.07.20.
//

import Foundation
import Relic

/// A wrapper for big number computation of relic. It contains helper functions. Does not initialize as it just contains static functions
public struct BN {
    private init() {}

    /// Create a new, empty and allocated big number
    /// - Returns: Big number set to 0
    public static func newBN() -> bn_t {
        var n = bn_t()
        bn_initialize(&n)
        return n
    }

    /// Create a big number representation from binary data. Can be used to load written big numbers
    /// - Parameter data: Data that contains the binarye representation of a big number
    /// - Returns: an actual big number
    public static func bigNumberFromBinary(data: Data) -> bn_t {
        var result: bn_t = BN.newBN()

        let byteBuffer = Array(data)
        bn_read_bin(&result, byteBuffer, Int32(byteBuffer.count))

        return result
    }

    /// Create a big number from a hexadecimal string
    /// - Parameter string: Hexadecimal string
    /// - Returns: a big number with the hex value
    public static func bigNumberFromString(string: String) -> bn_t {
        var result = BN.newBN()
        let cString = string.cString(using: .utf8)!
        let len = strlen(cString)
        bn_read_str(&result, cString, Int32(len), 16)

        return result
    }

    /// Generate a random big number in the order of the EC curve
    /// - Returns: a random big number
    public static func generateRandomInZq() -> bn_t {
        var modulus = ECC.order

        var result = BN.newBN()
        bn_rand_mod(&result, &modulus)

        return result
    }

    /// Hash multiple points on an elliptic curve to a big number representation
    /// - Parameter ecPoints: An array of ec points
    /// - Returns: All points are hashed together and this hash is represented as a big number
    public static func hash(ecPoints: [ec_t]) -> bn_t {
        var buffer = Data()
        for point in ecPoints {
            let binary = ECC.writePointToData(point: point)
            buffer.append(binary)
        }

        // Hash the buffer
        var hashArray = [UInt8](repeating: 0, count: Parameters.SHA256_SIZE)
        var bufferArray = Array(buffer)
        md_map_sh256(&hashArray, &bufferArray, Int32(bufferArray.count))

        let hash = Data(hashArray)

        return self.bigNumberFromBinary(data: hash)
    }

    /// a + b with big numbers
    /// - Parameters:
    ///   - a: a big number
    ///   - b: a big number
    /// - Returns: a + b
    public static func add(a: bn_t, b: bn_t) -> bn_t {
        var result = BN.newBN()
        var valA = a
        var valB = b
        bn_add(&result, &valA, &valB)

        return result
    }

    /// a - b with big numbers
    /// - Parameters:
    ///   - a: a big number
    ///   - b: a big number
    /// - Returns: a - b
    public static func sub(a: bn_t, b: bn_t) -> bn_t {
        var result = BN.newBN()
        var valA = a
        var valB = b
        bn_sub(&result, &valA, &valB)

        return result
    }

    /// a * b with big numbers
    /// - Parameters:
    ///   - a: a big number
    ///   - b: a big number
    /// - Returns: a * b
    public static func multiply(a: bn_t, b: bn_t) -> bn_t {
        var result = BN.newBN()
        var valA = a
        var valB = b
        bn_mul_comba(&result, &valA, &valB)

        return result
    }

    /// a % m with big numbers
    /// - Parameters:
    ///   - a: A big number
    ///   - m: The modulus
    /// - Returns: a % m
    public static func modulus(a: bn_t, m: bn_t) -> bn_t {
        var result = BN.newBN()
        var valA = a
        var modulus = m
        bn_w_modulus(&result, &valA, &modulus)

        return result
    }

    public static func pow(base: bn_t, exponent: bn_t, modulus: bn_t) -> bn_t {
        var result = BN.newBN()
        var bBase = base
        var eExponent = exponent
        var mModulus = modulus
        bn_mxp_slide(&result, &bBase, &eExponent, &mModulus)
        return result
    }

    /// Checks if two big numbers are equal by calling into Relic
    /// - Parameters:
    ///   - a: a big number
    ///   - b: a big number
    /// - Returns: true if a == b
    public static func areEqual(a: bn_t, b: bn_t) -> Bool {
        var lhs = a
        var rhs = b
        let cmp = bn_cmp(&lhs, &rhs)
        return cmp == RLC_EQ
    }

    /// Writes a big number to binary. Can be read with `bigNumberFromBinary`
    /// - Parameter num: a big number
    /// - Returns: Data that contain the big number in binary representation
    public static func writeToBinary(num: bn_t) -> Data {
        var val = num
        let size = bn_size_bin(&val)

        // Create the buffer

        guard size > 0 else { return Data() }
        var arrayBuffer = [UInt8](repeating: 0, count: Int(size))
        bn_write_bin(&arrayBuffer, Int32(arrayBuffer.count), &val)

        return Data(arrayBuffer)
    }
}

/// A wrapping struct that defines helper functions for elliptic curve computation to access the relic library. Does not intialize and contains only static functions
public struct ECC {
    private init() {}

    public static var order: bn_t {
        var order = BN.newBN()
        ec_curve_get_order(&order)
        return order
    }

    /// Hash the input with SHA384 and map that has to a point on the elliptic curve.
    /// - Parameter input: String input
    /// - Returns: ec point that refers to the hashed string
    public static func hashInputToECPoints_potentially_insecure(input: String) -> ec_t {
        let cString = Array(input.data(using: .utf8)!)

        var hashArray = [UInt8](repeating: 0, count: Parameters.SHA384_SIZE)
        md_map_sh384(&hashArray, cString, Int32(cString.count))
        let hash = Data(hashArray)

        // Get big number from hash
        var hash_bn = BN.bigNumberFromBinary(data: hash)

        var modHash = BN.newBN()

        var order = ECC.order

        // Modulo the hash with the curve order
        bn_w_modulus(&modHash, &hash_bn, &order)

        // Create a curve point
        var curvePoint = ec_t()
        ec_multiply_gen(&curvePoint, &modHash)

        return curvePoint
    }

    /// Hash the input with SHA384 and map that has to a point on the elliptic curve.
    /// - Parameter input: String input
    /// - Returns: ec point that refers to the hashed string
    public static func hashInputToECPoints(input: String) -> ec_t {

        //        return self.hashInputToECPoints_potentially_insecure(input: input)

        let cString = Array(input.data(using: .utf8)!)

        var curvePoint = ec_t()
        ep_map(&curvePoint, cString, Int32(cString.count))

        return curvePoint
    }

    /// Write EC Point to a binary reprsentation
    /// - Parameter point: ec point that should be converted to binary
    /// - Returns: Data that contains the binary ec value
    public static func writePointToData(point: ec_t) -> Data {
        var mPoint = point
        let compressionFlag: Int32 = PSI.config.useECPointCompression ? 1 : 0

        let size = ec_binary_size(&mPoint, compressionFlag)

        var arrayBuffer = [UInt8](repeating: 0, count: Int(size))

        ec_write_binary(&arrayBuffer, Int32(arrayBuffer.count), &mPoint, compressionFlag)

        return Data(arrayBuffer)
    }

    /// Read an EC point from a binary (Data) representation
    /// - Parameter data: Data that contains an ec point
    /// - Returns: an EC point
    public static func readPoint(from data: Data) -> ec_t {
        var arrayBuffer = [UInt8](data)

        var point = ec_t()
        ec_read_binary(&point, &arrayBuffer, Int32(arrayBuffer.count))

        return point
    }

    /// Multiply an ec point with a number.
    /// - Parameters:
    ///   - ecPoint: an ec point
    ///   - number: a number
    /// - Returns: `ecPoint * number` calculated with relic
    public static func mulitply(ecPoint: ec_t, number: bn_t) -> ec_t {
        var result = ec_t()
        var p = ecPoint
        var n = number
        ec_multiply(&result, &p, &n)

        return result
    }

    /// Adds two elliptic curve points. Computes A + B
    /// - Parameters:
    ///   - a: Elliptic curve point
    ///   - b: Elliptic curve point
    /// - Returns: A + B
    public static func add(a: ec_t, b: ec_t) -> ec_t {
        var result = ec_t()
        var valA = a
        var valB = b
        ec_addition(&result, &valA, &valB)
        return result
    }

    /// Checks if two elliptic curve points are equal. Uses Relic
    /// - Parameters:
    ///   - a: an EC point
    ///   - b: an EC Point
    /// - Returns: true if a == b
    public static func areEqual(a: ec_t, b: ec_t) -> Bool {
        var valA = a
        var valB = b
        let cmp = ec_compare(&valA, &valB)
        return cmp == RLC_EQ
    }

    public static func currentCurve() -> String {
        let fieldId = fp_param_get()
        switch Int(fieldId) {
        case NIST_256:
            return "NIST_256"
        case PRIME_25519:
            return "CURVE_25519"
        default:
            return "\(fieldId)"
        }
    }
}
