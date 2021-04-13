#  PrivateDrop Base 

This framework implements the AirDrop protocol in Swift and extends it with *PrivateDrop*. *PrivateDrop* is an extension to AirDrop that support private-set-intersection (PSI) to enhance the privacy of AirDrop. With PSI two communicating devices can be sure that they know each other before they need to share additional contact information, like hashes of phone numbers, that can be reversed. 

Furthermore, the implementation is backwards compatible to the normal AirDrop protocol.

The current implementation supports iOS and macOS, but it can be adopted for different Apple Operating systems by compiling the statically linked libraries. 

## Implementation 
To implement PrivateDrop in an app on iOS or macOS you would need only a few lines of code.  

### Configuration
The configuration is the most complicated part. For AirDrop you need the following details: 

* A TLS certificate that can be used as a server and a client certificate. 
    * Check the certificate section for further details  
*  Record data, signed by Apple (for contacts-only mode)
    * Check the record data section for further details 
* The known contact ids (for contacts-only mode)
    * An array of contact identifiers (e.g. mail addresses and phone numbers)
* Signed Y-Values (for PrivateDrop)
    * Can be generated with the Precompute PSI CLI 



```swift

try PrivateDrop.Configuration(
    recordData: recordData, // Optional. Necessary for contact identification 
    pkcs12: certificate, // TLS certificate. Password has to be `opendrop`. Can be changed in the code
    contactsOnly: true, // If only contacts are allowed  
    contacts: contacts, // array of contact ids 
    signedY: signedY, //Optional, but necessary for PSI  
    otherPrecomputedValues: precomputedVals // Optional, but necessary for PSI. pre-computed values
    )

```

### Receiving files 
The receiving files is backwards compatible to AirDrop. No additional settings need to be made to receive files from AirDrop. 

```swift

//Necessarry to detect received files and confirm ask requests 
struct ReceiverDelegate: PrivateDropReceiverDelegate {
    func discovered(with status: Peer.Status) {
        print("Discovered peer with \(status)")
    }
    
    func receivedFiles(at: URL) {
        print("Received file at \(at)")
    }
    
    func receivedAsk(request: AskRequestBody, matchingContactId: [String]?, userResponse: @escaping (Bool) -> ()) {
        //Ask requests need to be confirmed by the user. `true` if the user wants to receive the file
        userResponse(true)
    }
    
    func errorOccurred(error: Error) {
        print("An error occurred. Please handle it \(error)")
    }
    
    func privateDropReady() {
        print("PrivateDrop is ready to receive files")
    }
    
    
}

//Receiver
let privateDrop = PrivateDrop(with: privateDropConfig)
privateDrop.receiverDelegate = ReceiverDelegate()

try privateDrop.startListening()
```

### Sending 
Sending files can be performed in a private manner with **PrivateDrop** or compatible to AirDrop. The implementation is straightforward as demonstrated in the sample code: 

```swift
struct SenderDelegate: PrivateDropSenderDelegate {
    func found(peer: Peer) {
        print("Found a peer \(peer).\n Now perform contact checks")
        privateDrop.detectContact(for: peer, usePSI: peer.psiStatus != .notSupported)
    }
    
    func finishedPSI(with peer: Peer) {
        print("Finished psi for peer \(peer)")
    }
    
    func contactCheckCompleted(receiver: Peer) {
        print("Contact check for peer completed. State: \(receiver.status)")
    }
    
    func peerDeclinedFile() {
        print("Peer declined reception of the file ")
    }
    
    func finishedSending() {
        print("Peer has received the file")
    }
    
    func errorOccurred(error: Error) {
        print("An error occurred \(error)")
    }
    
    
}

//Sender
privateDrop.senderDelegate = SenderDelegate()
privateDrop.browse(privateDropOnly: true)

```

### Example implementation 
An example implementation of the basic PrivateDrop operations can be found in the PrivateDrop App Xcode Project. The `PrivateDropCLI` is a CLI that just sends a sample file to itself to verify the implementation. The `PrivateDrop App` is a more complex implementation that we used to create measurements

## Additional details

In this section, we discuss additional details necessary to setup PrivateDrop correctly.

### Certificates
In general, the certificates that work with PrivateDrop can be any certificate with a private key that can be used as a server and client certificate for TLS communication. By generating a self-signed certificate file transfer will work normally. 
To suppport authenticated file transfers with the official AirDrop implementation the original certificates signed by Apple are necessary. Those certificates are located in the iCloud Keychain of every iOS and macOS device. 
Their subject name is formatted like this com.apple.id.prd<UUID>

**PrivateDrop** works with self-signed certificates as long as they are root certificates. The AirDrop protocol explicitly allows them and the PrivateDrop authentication is performed through PSI.   

###  Record data  

The record data contains validated identifiers about the person that is using AirDrop. Those identifiers are email addresses or phone numbers. They are validated by Apple when a person makes changes to her iCloud account. Furthermore, Apple signs this data and stores it in a PKCS7 (CMS, SMIME) encoded data blob. 
The blob can be extracted from any normal AirDrop communication. To ensure that the record data is actually from the person that sending it, Apple uses the certificate, because both contain the same id. If the ids do not match the sender record will not be used. Please refer for more information to our paper.

To test **PrivateDrop** the record data does not need to match the certificate id. 

### PSI Values 

To perform private-set-intersection, the own identifiers are encrypted with random keys and by using elliptic curve point multiplication. The own identifiers, phone numbers and email addresses, should to be validated, by a trusted third party. In our testing environment we can be the trusted third party and sign custom values by using the `OpenDrop-PSI-Sign-3` certificate with the password `"opendrop"`.
The `PrecomputePSI` CLI from the `OpenDrop Other` project can be used to perform the signing.  
