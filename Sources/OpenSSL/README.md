#  OpenSSL - PKCS7 

This sub-library contains the OpenSSL and uses its implementation of PKCS7 to sign and verify PKCS7 (also named CMS, SMIME) files. The library contains mainly two structs `PKCS7Signer` and `PKCS7Verifier`. 

## Signing 
To sign data and pack it in the PKCS7 format you need a *certificate* that has the *Key-Usage* **Digital Signature**. 

Implementation: 
```swift
let data = "This is some test string".data(using: .utf8)!

let signer = PKCS7Signer(dataToSign: data)
let signedData = try signer.sign(with: try self.getSigningCertificateURL())
```

## Verifying 
To verify data you need a trusted certificate that has signed the data. Otherwise, the signature needs to be valid and the certificate needs the same constraints as for the signing. 

Implementation: 
```swift 
//Verify the signed data
let ca = try self.getTrustedCertURL()
//Verify
let verifier = try PKCS7Verifier(pkcs7: signedData)
try verifier.verify(with: ca, verifyChain: true, certsInPem: true)
```

