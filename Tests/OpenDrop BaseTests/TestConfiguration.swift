//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 22.06.20.
//

import Foundation
import XCTest

/// Contains information about which tests to run and which not
struct TestConfig {
    /// Tests that involve network operations, like starting a server or sending a request
    static let networkTests = ["testDiscover()", "testDiscoverIntegrationTest()"]
    static let runNetworkTests = true
    /// Tests that can run longer than 5s
    static let longRunningTests = ["testDiscoverIntegrationTest()"]
    static let runLongRunningTests = false

    static func runTest(_ functionName: String = #function) -> Bool {
        if !runNetworkTests && networkTests.contains(functionName) {
            return false
        }

        if !runLongRunningTests && longRunningTests.contains(functionName) {
            return false
        }

        return true
    }
}
