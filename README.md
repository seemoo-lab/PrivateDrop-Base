# PrivateDrop Base

The PrivateDrop Base framework is a Swift framework that supports Apple's AirDrop and the enhanced version PrivateDrop that adds an extra layer of privacy using private set intersection (PSI). 

## Configuration
AirDrop and PSI have a couple of pre-requesites to be used properly: <br> 
1. A certificate signed by Apple 
2. "Record data" signed by Apple, containing the hashed contact identifiers of the user 
3. Signed "Y"-Values (pre-computed PSI values)

Our test apps contain all those values and it is possible to use AirDrop (without PSI and without contact authentication/identification) without them. In this case AirDrop will run in the "Everyone" mode to send and receive files 

Example Code:
```swift
let configuration = PrivateDrop.Configuration(
            recordData: /*Officially signed record data by Apple*/,
            pkcs12: /*Self-signed or officially signed certificate by Apple (if record data is used)*/,
            computerName: /*A custom name*/,
            modelName: /*Device model name: e.g. MacBook 10,3*/,
            contactsOnly: /*Boolean true or false*/,
            contacts: /*An array of all contacts used. ["+49 29424 92919", "max.mustermann@de.de"]*/,
            signedY: /*Signed PSI values that include contact identifiers*/,
            otherPrecomputedValues: /*Plist file matching the precomputed values*/)
```

## Precomputation
To speed up the PSI communication it is recommended to precompute some values before communicating with other PrivateDrop devices. 
```swift 
let privatedrop = PrivateDrop(with: configuration)
privatedrop.precomputeContactValues {
    // Called when finished 
}
```

## Launching a server (e.g. receiving files)

To receive files, you would need to (1) start the PrivateDrop server and (2) add a delegate to handle the incoming file requests and files. The example code will show how to do this: 

```swift
    struct ReceiverDelegate: PrivateDropReceiverDelegate {
        
        // PrivateDrop is ready to receive files
        func privateDropReady() {
            
        }

        // Has been discovered by a peer. The peer status contains if this is a contact or not
        func discovered(with status: Peer.Status) {
            
        }
        
        // Received the request to receive a file. Call the userResponse callback with true to receive it
        func receivedAsk(request: AskRequestBody, matchingContactId: [String]?, userResponse: @escaping (Bool) -> ()) {

        }
        

        // Received files at the given URL (is a file URL to a local path)
        func receivedFiles(at: URL) {
            
        }

        func errorOccurred(error: Error) {
                
        }
        
    }

let receiverDelegate = ReceiverDelegate()
let privatedrop = PrivateDrop(with: configuration)
privatedrop.receiverDelegate = receiverDelegate
privatedrop.startListening() 
```

## Finding peers and sending files 

AirDrop normally works in two steps: At first, the sender discovers all surrounding receivers and secondly the user selects a receiver. AirDrop then sends a request to the receiver that asks the user if he/she wants to receive a file. If accepted, the file will be transferred. 
To perform these tasks with PrivateDrop follow the example code below. A sender delegate is needed for this. 

```swift 
struct SendingFiles: PrivateDropSenderDelegate {
    let privatedrop: PrivateDrop
    init() {
        self.privatedrop = PrivateDrop(with: configuration)
    }

    /// Found a peer using Bonjour. Before a Peer can receive a file use `detectIfContact`
    func found(peer: Peer) {
        //Now discover if this peer is a contact or not. We use PSI for enhanced privacy 
        self.privatedrop?.detectContact(for: peer, usePSI: true)
    }
    
    //Finished the PSI protocol with the peer
    func finishedPSI(with peer: Peer) {
        /// The PSI communication has finished. Now we know if we are in the peer's address book. 
        print(peer.psiStatus)
    }
    
    /// Contact checking finished for peer.
    func contactCheckCompleted(receiver: Peer) {
        /// The contact checking has finished. Now we also know if the peer is in our address book. 
        switch receiver.status {
            case .contacts(let contactIds): 
                // We only send files to contacts 
                do {
                    try self.privatedrop?.sendFile(at: fileURL/*local file URL*/, to: receiver)
                }catch {
                    //Handle errors here 
                    fatalError("Errors not handled")
                }
                
            default: 
                break 
        }
    }
    
    /// Peer declined the file by responding denying the ask request
    func peerDeclinedFile() {
        // The peer does not want to receive the file. 
    }
    
    /// The file has finished sending
    func finishedSending() {
        // File has been sent 
    }
    
    /// Stopped the execution because of an error that occurred
    func errorOccurred(error: Error) {}

}

let sendingFiles = SendingFiles() 
// Browse for privateDrop only receivers. 
sendingFiles.privatedrop.browse(privateDropOnly: true)

```