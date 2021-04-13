import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(OpenDrop_ServerTests.allTests)
        ]
    }
#endif
