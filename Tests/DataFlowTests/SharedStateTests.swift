//
//  SharedStateTests.swift
//  
//
//  Created by 黄磊 on 2022/4/23.
//

import Testing
import Foundation
@testable import DataFlow
@testable import ModuleMonitor

@Suite(.serialized)
@MainActor
struct SharedStateTests {
    
    // 正常状态的获取
    @Test
    func testSharedNormalState() {
        let shared = Store<NormalSharedState>.shared
        
        let saved = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
        #expect(shared === saved)
        
        let shared1 = Store<NormalSharedState>.shared
        let saved1 = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
        let shared2 = NormalSharedState.sharedStore
        let saved2 = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
        #expect(shared === shared1)
        #expect(shared1 === saved1)
        #expect(saved1 === shared2)
        #expect(shared2 === saved2)
    }
    
    // 可加载处理器状态的获取
    @Test
    func testSharedReducerState() {
        let shared = Store<SharedReducerState>.shared
        
        let saved = s_mapSharedStore[ObjectIdentifier(SharedReducerState.self)] as! Store<SharedReducerState>
        
        #expect(shared === saved)
        #expect(sharedReducerStateIsLoad)
        
        let shared1 = Store<SharedReducerState>.shared
        let saved1 = s_mapSharedStore[ObjectIdentifier(SharedReducerState.self)] as! Store<SharedReducerState>
        
        #expect(shared === shared1)
        #expect(shared1 === saved1)
    }
    
    @Test
    func testFullShareStore() {
        s_mapSharedStore.removeAll()
        fullSharedStateReducerCall = false
        let sharedStore = Store<FullSharedState>.shared
        #expect(fullSharedStateReducerCall)
        #expect(sharedStore.content == "")
        
        let content = "content"
        sharedStore.send(action: .changeContent(content))
        #expect(sharedStore.content == content)
    }
    
    @Test
    func testDuplicateSharedState() {
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var duplicateFatalErrorCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                    message == ("Add SubStore[DuplicateSharedState] to UpState[AppState] " +
                                "with stateId[NormalSharedState] failed: exists SubStore with same stateId!") {
                    duplicateFatalErrorCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)
        
        _ = Store<NormalSharedState>.shared
        #expect(observer.duplicateFatalErrorCall == false)
        
        _ = Store<DuplicateSharedState>.shared
        #expect(observer.duplicateFatalErrorCall)
        
        cancellable.cancel()
    }
    
    @Test
    func testCreateSharedStoreOnMultiThread() {
        s_mapSharedStore.removeAll()
        
        nonisolated(unsafe) var count: Int = 0
        
        let group = DispatchGroup()
        for _ in 0..<5 {
            group.enter()
            DispatchQueue.global().async {
                if (s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)] == nil) {
                    sleep(1)
                    _ = Store<MultiThreadSharedState>.shared
                    if s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)] != nil {
                        count += 1
                    }
                }
                group.leave()
            }
        }
        
        // 所有任务在 sleep(1)，此时 store 尚未创建
        #expect(s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)] == nil)
        
        _ = group.wait(timeout: .now() + 10)
        
        #expect(s_mapSharedStore[ObjectIdentifier(MultiThreadSharedState.self)] != nil)
        #expect(count >= 2) // 至少触发两次
    }
    
    @Test
    func testCreateSharedStoreOnOtherSharedStoreCreation() {
        s_mapSharedStore.removeAll()
        
        _ = Store<MultiThreadNestSharedState>.shared
        
        #expect(s_mapSharedStore[ObjectIdentifier(MultiThreadNestSharedState.self)] != nil)
        #expect(s_mapSharedStore[ObjectIdentifier(MultiThreadSubSharedState.self)] != nil)
        #expect(s_mapSharedStore.count == 3)
    }
    
    @Test
    func testUseBoxOnSharableState() {
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var duplicateFatalErrorCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                    message == ("'SharableState' can't use box() directly. " +
                                "Use 'shared' instead or set 'useBoxOnShared' config to 'true'") {
                    duplicateFatalErrorCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)
        
        // 配置 useBoxOnShared，不会 fatalError
        _ = Store<NormalSharedState>.box(.init(), configs: [.make(.useBoxOnShared, true)])
        #expect(observer.duplicateFatalErrorCall == false)
        
        _ = Store<NormalSharedState>.box()
        #expect(observer.duplicateFatalErrorCall)
        
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

@MainActor var fullSharedStateReducerCall = false
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

@MainActor var sharedReducerStateIsLoad = false
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
