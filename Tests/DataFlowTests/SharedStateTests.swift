//
//  SharedStateTests.swift
//  
//
//  Created by 黄磊 on 2022/4/23.
//

import XCTest
@testable import DataFlow

class SharedStateTests: XCTestCase {
    
    // 正常状态的获取
    func testSharedNormalState() {
        
        let shared = Store<NormalSharedState>.shared
        
        let saved = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
        XCTAssert(shared === saved)
        
        let shared1 = Store<NormalSharedState>.shared
        let saved1 = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
        let shared2 = NormalSharedState.sharedStore
        let saved2 = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
    
        XCTAssert(shared === shared1)
        XCTAssert(shared1 === saved1)
        XCTAssert(saved1 === shared2)
        XCTAssert(shared2 === saved2)
    }
    
    // 可加载处理器状态的获取
    func testSharedReducerState() {
        
        let shared = Store<SharedReducerState>.shared
        
        let saved = s_mapSharedStore[ObjectIdentifier(SharedReducerState.self)] as! Store<SharedReducerState>
        
        XCTAssert(shared === saved)
        XCTAssert(sharedReducerStateIsLoad)
        
        let shared1 = Store<SharedReducerState>.shared
        let saved1 = s_mapSharedStore[ObjectIdentifier(SharedReducerState.self)] as! Store<SharedReducerState>
    
        XCTAssert(shared === shared1)
        XCTAssert(shared1 === saved1)
    }
        
    func testFullShareStore() {
        s_mapSharedStore.removeAll()
        fullSharedStateReducerCall = false
        let sharedStore = Store<FullSharedState>.shared
        XCTAssert(fullSharedStateReducerCall)
        XCTAssertEqual(sharedStore.content, "")
        
        let content = "content"
        sharedStore.send(action: .changeContent(content))
        XCTAssertEqual(sharedStore.content, content)
    }
    
    func testDuplicateSharedState() {
        
        StoreMonitor.shared.arrObservers = []
        class Oberver: StoreMonitorOberver {
            var duplicateFatalErrorCall = false
            func receiveStoreEvent<State>(_ event: StoreEvent<State>) where State : StorableState {
                if case .fatalError(let message) = event,
                    message == ("Attach State[DuplicateSharedState] to UpState[AppState] " +
                                "with stateId[NormalSharedState] failed: " +
                                "exist State[NormalSharedState] with same stateId!") {
                    duplicateFatalErrorCall = true
                }
            }
        }
        let oberver = Oberver()
        let cancellable = StoreMonitor.shared.addObserver(oberver)
        
        _ = Store<NormalSharedState>.shared
        XCTAssert(!oberver.duplicateFatalErrorCall)
        
        _ = Store<DuplicateSharedState>.shared
        XCTAssert(oberver.duplicateFatalErrorCall)
        
        cancellable.cancel()
    }
    
    func testCreateSharedStoreOnMultiThread() {
        s_mapSharedStore.removeAll()
        
        var expectations: [XCTestExpectation] = []
        var count: Int = 0
        
        (0..<5).forEach { _ in
            let expectation = expectation(description: "This should complete")
            expectations.append(expectation)
            DispatchQueue.global().async {
                if (s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)] == nil) {
                    sleep(1)
                    _ = Store<MultiThreadSharedState>.shared
                    
                    XCTAssertNotNil(s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)])
                    count += 1
                }
                expectation.fulfill()
            }
        }
        
        XCTAssertNil(s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)])
        
        wait(for: expectations, timeout: 5)
        
        XCTAssertNotNil(s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)])
        XCTAssertTrue(count >= 2) // 至少触发两次
    }
    
    func testCreateSharedStoreOnOtherSharedStoreCreation() {
        s_mapSharedStore.removeAll()
        
        _ = Store<MultiThreadNestSharedState>.shared
        
        XCTAssertNotNil(s_mapSharedStore[ObjectIdentifier(MultiThreadNestSharedState.self)])
        XCTAssertNotNil(s_mapSharedStore[ObjectIdentifier(MultiThreadSubSharedState.self)])
        XCTAssertEqual(s_mapSharedStore.count, 3)
    }
    
    func testUseBoxOnSharableState() {
        StoreMonitor.shared.arrObservers = []
        class Oberver: StoreMonitorOberver {
            var duplicateFatalErrorCall = false
            func receiveStoreEvent<State>(_ event: StoreEvent<State>) where State : StorableState {
                if case .fatalError(let message) = event,
                    message == ("'SharableState' cann't use box() directly. " +
                                "Use 'shared' instead or set 'useBoxOnShared' config to 'true'") {
                    duplicateFatalErrorCall = true
                }
            }
        }
        let oberver = Oberver()
        let cancellable = StoreMonitor.shared.addObserver(oberver)
                
        // 配置 useBoxOnShared，不会 fatalError
        _ = Store<NormalSharedState>.box(.init(), configs: [.make(.useBoxOnShared, true)])
        XCTAssert(!oberver.duplicateFatalErrorCall)
        
        _ = Store<NormalSharedState>.box()
        XCTAssert(oberver.duplicateFatalErrorCall)
        
        cancellable.cancel()
    }
}

enum TestAction: Action {
    case changeContent(String)
}

struct TestState: SharableState, ReducerLoadableState, ActionBindable {
    typealias BindAction = TestAction
    
    var content: String = ""
    
    static func loadReducers(on store: Store<TestState>) {
        store.register { (state, action: TestAction) in
            switch action {
            case .changeContent(let string):
                state.content = string
            }
        }
    }
}

var fullSharedStateReducerCall = false
struct FullSharedState: FullSharableState {
    typealias BindAction = TestAction
    
    var content: String = ""
    
    static func loadReducers(on store: Store<FullSharedState>) {
        fullSharedStateReducerCall = true
        store.register { (state, action: TestAction) in
            switch action {
            case .changeContent(let string):
                state.content = string
            }
        }
    }
}

enum NormalAction : Action {
    case userClick
}

struct NormalSharedState : SharableState {
    var name: String = ""
}

extension NormalSharedState : ActionBindable {
    typealias BindAction = NormalAction
}

var sharedReducerStateIsLoad = false
struct SharedReducerState : SharableState, ReducerLoadableState {
    static func loadReducers(on store: Store<SharedReducerState>) {
        sharedReducerStateIsLoad = true
    }
}

struct DuplicateSharedState : SharableState {
    var name: String = ""
    
    var stateId: String = "NormalSharedState"
}

struct MultiThreadSharedState : SharableState {
    var name: String = ""
}

struct MultiThreadNestSharedState : SharableState {
    var name: String = ""
    
    init() {
        self.name = ""
        _ = Store<MultiThreadSubSharedState>.shared
    }
}

struct MultiThreadSubSharedState : SharableState {
    var name: String = ""
}
