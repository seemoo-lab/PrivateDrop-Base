import Foundation

/// Decoded property list of the Ask request
public struct AskRequestBody: Codable {
    /// The sender computer's name. Displayed when asking for receiving a file not from a contact
    var SenderComputerName: String?
    /// The bundle id of the sending application
    var BundleID: String?
    /// The model name of the sender
    var SenderModelName: String?
    /// The service id distributed over mDNS
    var SenderID: String?
    /// Sender wants that media formats are converted
    var ConvertMediaFormats: Bool?
    /// The sender's record data
    var SenderRecordData: Data?
    /// JPEG2000 encoded file icon
    var FileIcon: Data?
    /// Array of file infos for all files that are shared
    var Files: [FileInfo] = []

    struct FileInfo: Codable {
        var FileName: String?
        var FileType: String?
        var FileBomPath: String?
        var FileIsDirectory: Bool?
        var ConvertMediaFormats: Bool?
    }
}

struct AskResponseBody: Codable {
    /// Recevier computer name. String displayed when accepting a send
    var ReceiverComputerName: String?
    /// Model of the receiver. Can be used to display model specific icons
    var ReceiverModelName: String?
}
