#  Libarchive

This sub-library contains a build of libarchive for iOS and macOS. It is used for archiving and unarchving files and folders the CPIO format. This format is  used by Apple's AirDrop implementation so a support of it is neccessary to maintain compatability 

Implementation: 
```swift 

//Archive a directory 
let archiveDirectory =  URL(fileURLWithPath: "/to-archive")

let archive = try Libarchive.archiveToCPIO(directory: archiveDirectory)

//Unarchive a directory 
let exportDir = try Libarchive.readCPIO(cpio: archive)
```
