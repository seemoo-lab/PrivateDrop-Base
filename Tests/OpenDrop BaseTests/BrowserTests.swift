import Foundation
import Network
import XCTest

@testable import PrivateDrop_Base

final class BrowserTests: XCTestCase, NetServiceDelegate {

    var testService: NetService = NetService()

    override func setUp() {
        testService = NetService(
            domain: "local.", type: "_airdrop._tcp.", name: UUID().uuidString, port: 54321)
        testService.includesPeerToPeer = true
        testService.publish(options: .noAutoRename)  // Make sure name is unique
    }

    override func tearDown() {
        testService.stop()
    }

    func testStopBrowsing() {
        let client = Browser(interface: .localOnly)
        client.startBrowsing()
        client.stopBrowsing()
    }

    func testDiscoveredService() {
        let expectation = XCTestExpectation(description: "Find test AirDrop service")

        class TestClientDelegate: BrowserDelegate {
            let expectation: XCTestExpectation
            let serviceName: String

            init(_ expectation: XCTestExpectation, serviceName: String) {
                self.expectation = expectation
                self.serviceName = serviceName
            }

            func added(service: NWBrowser.Result) {
                if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) =
                    service
                    .endpoint
                {
                    if name == serviceName { expectation.fulfill() }
                }
            }

            func removed(service: NWBrowser.Result) {}
        }

        let client = Browser(interface: .localOnly)
        client.startBrowsing()
        let delegate = TestClientDelegate(expectation, serviceName: testService.name)
        client.delegate = delegate

        wait(for: [expectation], timeout: 10.0)
    }

    func testRemovedService() {
        let addExpectation = XCTestExpectation(description: "Find test AirDrop service")
        let removeExpectation = XCTestExpectation(description: "Stop test AirDrop service")

        class TestClientDelegate: BrowserDelegate {
            let addExpectation: XCTestExpectation
            let removeExpectation: XCTestExpectation
            let serviceName: String

            init(
                addExpectation: XCTestExpectation, removeExpectation: XCTestExpectation,
                serviceName: String
            ) {
                self.addExpectation = addExpectation
                self.removeExpectation = removeExpectation
                self.serviceName = serviceName
            }

            func added(service: NWBrowser.Result) {
                if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) =
                    service
                    .endpoint
                {
                    if name == serviceName { addExpectation.fulfill() }
                }
            }

            func removed(service: NWBrowser.Result) {
                if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) =
                    service
                    .endpoint
                {
                    if name == serviceName { removeExpectation.fulfill() }
                }
            }
        }

        let client = Browser(interface: .localOnly)
        client.startBrowsing()
        let delegate = TestClientDelegate(
            addExpectation: addExpectation, removeExpectation: removeExpectation,
            serviceName: testService.name)
        client.delegate = delegate

        wait(for: [addExpectation], timeout: 10.0)
        testService.stop()
        wait(for: [removeExpectation], timeout: 10.0)
    }

    func testNetServiceBrowser() {

        class BrowserDelegate: NSObject, NetServiceBrowserDelegate {
            let expectation: XCTestExpectation
            let nameToFind: String

            init(_ expectation: XCTestExpectation, nameToFind: String) {
                self.expectation = expectation
                self.nameToFind = nameToFind
            }

            func netServiceBrowser(
                _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
            ) {
                // Found AirDrop Service
                XCTAssertEqual(service.type, "_airdrop._tcp.")
                print("Found service \(String(describing: service))")
                // Apple's AirDrop names are not UUIDs just random hex strings
                if service.name == self.nameToFind {
                    browser.stop()
                    self.expectation.fulfill()
                }
            }
        }

        let netBrowser = NetServiceBrowser()
        netBrowser.includesPeerToPeer = true
        let expect = self.expectation(description: "AirDrop discovery")
        let browserDelegate = BrowserDelegate(expect, nameToFind: testService.name)
        netBrowser.delegate = browserDelegate
        netBrowser.searchForServices(ofType: "_airdrop._tcp.", inDomain: "local.")
        self.wait(for: [expect], timeout: 10.0)
    }

}
