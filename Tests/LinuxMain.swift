import XCTest

import DataFlowTests

var tests = [XCTestCaseEntry]()
tests += StoreTests.allTests()
tests += SharedStateTests.allTests()
XCTMain(tests)
