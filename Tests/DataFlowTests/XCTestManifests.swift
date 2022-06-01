import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(StoreTests.allTests),
        testCase(SharedStateTests.allTests),
    ]
}
#endif
