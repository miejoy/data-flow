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
    
        XCTAssert(shared === shared1)
        XCTAssert(shared1 === saved1)
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
