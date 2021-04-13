#  PSI

This sub-library implements the private-set-intersection (PSI) protocol that is used for PrivateDrop, to enhance the user's privacy in comparison to the default AirDrop implementation.
This implementation uses the Relic EC library configured to use the Curve25519. 

## Relic 
Relic is an EC library that implements basic Elliptic curve operations in C and makes them available to linkers. This allows us to use raw EC point multiplication, addition to generate the necessary data for the PSI protocol.

## Verifier

The verifier, as a first step, creates encrypted and hashed Y-Values and sends them to the Prover. The Prover will create a Proof-of-Knowledge and send its complete encrypted address book U-values.  By **verifiying** the proof-of-knowledge it checks if the Prover manipulated the Y-Values and is able to check if one of its ids are in the prover's address book when using the U-Values. 

## Prover 
The prover reacts to the verifier by generating the proof-of-knowledge (PoK) and sending its encrypted addressbook (U-Values) to the verifier. The verifier is then able to check if it is part of the prover's addressbook.


Implementation: 
```swift 
let prover = try Prover(contacts: ["+491755016748", "+49624154200", "+4961511627303"])
let verifier = try Verifier(ids: ["+49624154200", "+4961511627303", "+12498340392", "+249878937543"])

//1. Step happens on R -> Can be precomuted (but is also very fast)
//Can be precomputed
let y  = verifier.generateY()

//Precomputed
let u = prover.generateU()

// Send Y to S (prover)
let z = prover.generateZ(from: y)
let (pokAs, pokZ) = prover.generatePoK(from: y)

//Send u, pokZ, pokAs, and z to R (verifier)
try verifier.verify(z: z, pokZ: pokZ, pokAs: pokAs)

//Intersect
let matches = verifier.intersect(with: u)
```
