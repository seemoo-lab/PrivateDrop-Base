import Foundation

// swiftlint:disable identifier_name
struct DiscoverRequestBody: Codable {
    var SenderRecordData: Data?
}

struct DiscoverResponseBody: Codable {
    /// The computer's name. To be shown on the UI when a user is presented
    var ReceiverComputerName: String?
    /// JSON Data
    var ReceiverMediaCapabilities: Data?
    /// The model of the receiver
    var ReceiverModelName: String?
    /// The Record data
    var ReceiverRecordData: Data?
}
