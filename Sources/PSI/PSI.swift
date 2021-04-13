//
//  PSI.swift
//
//
//  Created by Alex - SEEMOO on 15.07.20.
//

import Foundation
import OSLog
@_exported import Relic

/// Static parameters used in the PSI framework
struct Parameters {
    static let SHA256_SIZE = 32
    static let SHA384_SIZE = 48
    static let TWO = BN.bigNumberFromString(string: "2")
    static let EULER_THEOREM = BN.sub(a: ECC.order, b: Parameters.TWO)
}

/// In PSI we have a verifier and a prover.
///
/// ## Protocol Overview
/// The verifier sends it's own hashed and randomized ids (according to the PSI protocol) to the prover.
/// The prover performs cryptographic operations (z, pokZ, pokAs)  on the value's received from the verifier.
/// It also generates hashed and randomized ids of **all** its contacts (U) and sends them to the verifier.
/// The verifier is now able to (a) verify that all values from the prover are correct (b) generate matching identifers to the U values.
/// In the end, the verifier can check if any and which of its identifiers match to the prover's contacts.
///
/// **So the verifier knows if its set (own contact ids) intersects with the prover's (all contacts)**
/// ## Protocol flow
///  1. Precomputation
///  `Prover.generateU()` and `Verifier.generateY()`
///  Those values are not dependant on values from the other party
///  2. Prover part
///  Y is sent to the prover
///  Prover calculates Z, pokZ and pokAS with `generateZ(from y:)` and `generatePoK(from y:)`
///  Prover sends `Z,pokZ,pokAS and U` to the verifier
///  3. Verification and intersection
///  Verifier verifies the values and performs the intersection. **DO NOT INTERSECT PRIOR TO VERIFICATION**
///  ` verify(z: [ec_t], pokZ: bn_t, pokAs: [ec_t])` and `intersect(with u:)`
///
public struct PSI {
    static var isInitialized = false

    static var config: Config!

    public static func initialize(config: Config) {
        self.config = config

        guard !isInitialized else { return }

        if core_init() != RLC_OK {
            core_clean()
        }

        let initPlain = ep_param_set_any_plain()
        if initPlain != RLC_OK {
            core_clean()
        }

        self.isInitialized = true

        os_log("Using %@ curve", ECC.currentCurve())
    }

    public struct Config {
        let useECPointCompression: Bool
        let parallelize: Bool

        public init(useECPointCompression: Bool, parallelize: Bool = false) {
            self.useECPointCompression = useECPointCompression
            self.parallelize = parallelize
        }
    }
}
