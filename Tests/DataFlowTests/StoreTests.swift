//
//  StoreTests.swift
//  
//
//  Created by 黄磊 on 2020-06-25.
//

import XCTest
@testable import DataFlow
import SwiftUI

class StoreTests: XCTestCase {
    
    func testStoreObservable() {
        let normalStore = Store<NormalState>.box(NormalState())
        var willChangeCall = false
        let cancellable = normalStore.objectWillChange.sink {
            willChangeCall = true
        }
        
        XCTAssertFalse(willChangeCall)
        normalStore.name = ""
        // 相同值不会调用 willChange
        XCTAssertFalse(willChangeCall)
        XCTAssertEqual(normalStore.name, "")
        willChangeCall = false
        normalStore.state.name = "text"
        XCTAssertTrue(willChangeCall)
        XCTAssertEqual(normalStore.state.name, "text")
        cancellable.cancel()
    }
    
    func testInitializableState() {
        let normalStore = Store<NormalState>()
        XCTAssertEqual(normalStore.name, "")
    }
    
    func testStateContainableAndAttachable() {
        let containStore = Store<ContainState>.box(ContainState())
        var containGetCall = false
        
        let saveSubStateBefore = containStore.state.subStates[ContainSubState().stateId]
        XCTAssertNil(saveSubStateBefore)
        
        let subStore = Store<ContainSubState>.box(ContainSubState())
        containStore.add(subStore: subStore)
        
        let saveSubStateAfter = containStore.state.subStates[subStore.state.stateId]
        XCTAssertNotNil(saveSubStateAfter)
        
        let subsribe = containStore.objectWillChange.sink { (_) in
            containGetCall = true
        }
        
        var state = ContainSubState()
        state.subValue = 1
        subStore.state = state
        
        XCTAssert(containGetCall)
        
        subsribe.cancel()
        
        // 确保新值在上级被设置了
        let saveSubStateChange = containStore.state.subStates[subStore.state.stateId] as? ContainSubState
        XCTAssertEqual(saveSubStateChange?.subValue, 1)
    }
    
    func testReducerLoadableState() {
        _ = Store<ReducerState>.box(.init())
        XCTAssert(reducerStateIsLoad)
    }
    
    func testStateInitReducerLoadable() {
        _ = Store<InitReducerState>()
        XCTAssert(initReducerStateIsLoad)
    }
    
    func testSubscript() {
        let store = Store<SubscriptState>()
        
        XCTAssertEqual(store.normalState.name, "")
        
        store.normalState.name = "text"
        XCTAssertEqual(store.normalState.name, "text")
    }
    
    func testSubscriptEquatable() {
        let store = Store<SubscriptState>()
        
        XCTAssertEqual(store.name, "")
        
        store.name = "text"
        XCTAssertEqual(store.name, "text")
    }
    
    func testSendAnyAction() {
        let normalStore = Store<NormalState>.box(NormalState())
        var reducerCall = false
        normalStore.register { (state, action: AnyAction) in
            reducerCall = true
        }
        
        normalStore.send(action: AnyAction.any)
        let block = normalStore.mapReducer[ObjectIdentifier(AnyAction.self)]
        
        XCTAssert(reducerCall)
        XCTAssertNotNil(block)
    }
    

    func testSendSpecificAction() {
        
        let specificStore = Store<SpecificState>.box(SpecificState())
        var reducerCall = false
        specificStore.registerDefault { (state, action) in
            reducerCall = true
        }
        
        specificStore.send(action: .specific)
        let block = specificStore.mapReducer[ObjectIdentifier(SpecificAction.self)]
        
        XCTAssert(reducerCall)
        
        XCTAssertNotNil(block)
    }
    
    func testSendSpecificActionObserve() {
        
        let specificStore = Store<SpecificState>.box(SpecificState())
        let normalStore = Store<NormalState>()
        var reducerCall = false
        specificStore.registerDefault { (state, action) in
            reducerCall = true
        }
        
        var observeStateCall = false
        specificStore.observeDefault(store: normalStore) { new, old in
            observeStateCall = true
            return .specific
        }
        
        var observeValueCall = false
        specificStore.observeDefault(store: normalStore, of: \.name) { new, old in
            observeValueCall = true
            return .specific
        }
        
        XCTAssert(!reducerCall)
        XCTAssert(!observeStateCall)
        XCTAssert(!observeValueCall)
        
        normalStore.state = NormalState()
        XCTAssert(reducerCall)
        XCTAssert(observeStateCall)
        XCTAssert(!observeValueCall)

        reducerCall = false
        observeStateCall = false
        normalStore.state.name = ""
        XCTAssert(reducerCall)
        XCTAssert(observeStateCall)
        XCTAssert(!observeValueCall)
        
        reducerCall = false
        observeStateCall = false
        normalStore.state.name = "new"
        XCTAssert(reducerCall)
        XCTAssert(observeStateCall)
        XCTAssert(observeValueCall)
    }
    
    func testDispatchAction() {
        
        let normalStore = Store<NormalState>.box(NormalState())
        var reducerCall = false
        var isMainThread = false
        let expection = expectation(description: "This reducer should be call in main thread")
        normalStore.register { (state, action: SpecificAction) in
            reducerCall = true
            isMainThread = Thread.isMainThread
            expection.fulfill()
        }
        
        DispatchQueue.global().async {
            normalStore.dispatch(action: SpecificAction.specific)
        }
        
        wait(for: [expection], timeout: 10)
        
        XCTAssert(reducerCall)
        XCTAssert(isMainThread)
    }
    
    
    func testDispatchSpecificAction() {
        
        let specificStore = Store<SpecificState>.box(SpecificState())
        var reducerCall = false
        var isMainThread = false
        let expection = expectation(description: "This reducer should be call in main thread")
        specificStore.register { (state, action: SpecificAction) in
            reducerCall = true
            isMainThread = Thread.isMainThread
            expection.fulfill()
        }
        
        DispatchQueue.global().async {
            specificStore.dispatch(action: .specific)
        }
        
        wait(for: [expection], timeout: 10)
        
        XCTAssert(reducerCall)
        XCTAssert(isMainThread)
    }
    
    
    func testStoreSubscript() {
        
        s_mapSharedStore.removeAll()
        s_mapStateObserve.removeAll()
        let subStore = Store<ContainSubState>.box(ContainSubState())
        
        XCTAssertEqual(subStore.subValue, 0)
        
        subStore.state.subValue = 1
        XCTAssertEqual(subStore.subValue, 1)
        
        subStore.subValue = 2
        XCTAssertEqual(subStore.state.subValue, 2)
        
        subStore.subValue = 3
        XCTAssertEqual(subStore.state.subValue, 3)
    }
    
    func testStoreObserve() {
        let firstStore: Store<ObserveState> = Store<ObserveState>()
        let secondStore = Store<ObserveState>()
        
        var observeStateCall = false
        firstStore.observe(store: secondStore) { new, old in
            observeStateCall = true
        }
        
        var observeValueCall = false
        firstStore.observe(store: secondStore, of: \.name) { new, old in
            observeValueCall = true
        }
        
        secondStore.name = "text"
        
        XCTAssert(observeStateCall)
        XCTAssert(observeValueCall)
        
        observeStateCall = false
        observeValueCall = false
        secondStore.name = "text1"
        XCTAssert(observeStateCall)
        XCTAssert(observeValueCall)
        
        observeStateCall = false
        observeValueCall = false
        secondStore.otherValue = "text"
        XCTAssert(observeStateCall)
        XCTAssert(!observeValueCall)
    }
    
    func testStoreObserveWithAction() {
        let firstStore: Store<ObserveState> = Store<ObserveState>()
        let secondStore = Store<ObserveState>()
        
        var actionCall = false
        firstStore.register { (state, action: AnyAction) in
            switch action {
            case .any:
                actionCall = true
            }
        }
        
        var observeValueCall = false
        firstStore.observe(store: secondStore, of: \.name) { (new, old) -> AnyAction in
            observeValueCall = true
            return AnyAction.any
        }
        
        secondStore.name = "text"
        XCTAssert(observeValueCall)
        XCTAssert(actionCall)
        
        var observeStateCall = false
        firstStore.observe(store: secondStore) { (new, old) -> AnyAction in
            observeStateCall = true
            return AnyAction.any
        }
        
        actionCall = false
        observeStateCall = false
        observeValueCall = false
        secondStore.otherValue = "text"
        XCTAssert(observeStateCall)
        XCTAssert(!observeValueCall)
        XCTAssert(actionCall)
    }
    
    func testCancelObserverWhenDestory() {
        var firstStore: Store<NormalState>? = Store<NormalState>()
        let secondStore = Store<NormalState>()
        XCTAssertEqual(secondStore.arrObservers.count, 0)
        XCTAssertEqual(secondStore.mapValueObservers.count, 0)
        XCTAssertNil(secondStore.mapValueObservers[\NormalState.name])
        
        firstStore!.observe(store: secondStore) { new, old in }
        XCTAssertEqual(secondStore.arrObservers.count, 1)
        XCTAssertEqual(secondStore.generateObserverId, 1)
        
        firstStore!.observe(store: secondStore, of: \.name) { new, old in }
        XCTAssertEqual(secondStore.mapValueObservers.count, 1)
        XCTAssertEqual(secondStore.mapValueObservers[\NormalState.name]?.count, 1)
        XCTAssertEqual(secondStore.generateObserverId, 2)
        
        firstStore = nil
        XCTAssertEqual(secondStore.arrObservers.count, 0)
        XCTAssertEqual(secondStore.mapValueObservers.count, 0)
    }
    
    func testNotifyWillCallWhileStateChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let cancellable = normalStore.addObserver { new, old in
            observerCall = true
        }
        
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, false)
        XCTAssertEqual(observerCall, false)
        
        normalStore.register { (state, action: AnyAction) in
            // 这里即使不对 state 做任何操作，对应 abserver 也会被调用，这个 & 机制问题
            state.name = "new"
            reduceCall = true
        }
        
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, true)
        XCTAssertEqual(observerCall, true)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, true)
        XCTAssertEqual(observerCall, false)
    }
    
    func testNotifyWillCallWhileValueChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let cancellable = normalStore.addObserver(of: \.name) { new, old in
            observerCall = true
        }
        normalStore.register { (state, action: AnyAction) in
            state.name = "new"
            reduceCall = true
        }
        
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, true)
        XCTAssertEqual(observerCall, true)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, true)
        XCTAssertEqual(observerCall, false)
    }
    
    func testNotifyWillNeverCallWhileValueNotChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let cancellable = normalStore.addObserver(of: \.name) { _, _ in observerCall = true }
        normalStore.register { (state, action: AnyAction) in
            reduceCall = true
        }
        
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, true)
        XCTAssertEqual(observerCall, false)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        XCTAssertEqual(reduceCall, true)
        XCTAssertEqual(observerCall, false)
    }
    
    func testCyclicObserve() {
        
        StoreMonitor.shared.arrObservers = []
        class Oberver: StoreMonitorOberver {
            var cyclicObserveCall = false
            func receiveStoreEvent<State>(_ event: StoreEvent<State>) where State : StorableState {
                if case .cyclicObserve = event {
                    cyclicObserveCall = true
                }
            }
        }
        let oberver = Oberver()
        let cancellable = StoreMonitor.shared.addObserver(oberver)
        
        let fromStore = Store<NormalState>()
        let toStore = Store<SpecificState>.box(SpecificState())
        
        XCTAssert(!oberver.cyclicObserveCall)
        
        toStore.observe(store: fromStore) { new,old in }
        XCTAssert(!oberver.cyclicObserveCall)
        
        fromStore.observe(store: toStore) { new,old in }
        XCTAssert(oberver.cyclicObserveCall)
        
        cancellable.cancel()
    }
    
    func testCyclicObserveIndirect() {
        
        StoreMonitor.shared.arrObservers = []
        class Oberver: StoreMonitorOberver {
            var cyclicObserveCall = false
            func receiveStoreEvent<State>(_ event: StoreEvent<State>) where State : StorableState {
                if case .cyclicObserve = event {
                    cyclicObserveCall = true
                }
            }
        }
        let oberver = Oberver()
        let cancellable = StoreMonitor.shared.addObserver(oberver)
        
        let topStore = Store<NormalState>()
        let middleStore = Store<ContainState>.box(ContainState())
        let bottomStore = Store<ContainSubState>.box(ContainSubState())
        let otherStore = Store<SpecificState>.box(SpecificState())
        
        var isTopObserverBottom = Store<NormalState>.isToObserveFrom(toId: ObjectIdentifier(topStore), fromId: ObjectIdentifier(bottomStore))
        var isBottomObserverTop =  Store<ContainSubState>.isToObserveFrom(toId: ObjectIdentifier(bottomStore), fromId: ObjectIdentifier(topStore))
        XCTAssert(!isTopObserverBottom)
        XCTAssert(!isBottomObserverTop)
        XCTAssert(!oberver.cyclicObserveCall)
        
        topStore.observe(store: middleStore) { new,old in }
        XCTAssert(!oberver.cyclicObserveCall)
        
        middleStore.add(subStore: bottomStore)
        middleStore.observe(store: otherStore) { new, old in }
        XCTAssert(!oberver.cyclicObserveCall)
        isTopObserverBottom = Store<NormalState>.isToObserveFrom(toId: ObjectIdentifier(topStore), fromId: ObjectIdentifier(bottomStore))
        isBottomObserverTop =  Store<ContainSubState>.isToObserveFrom(toId: ObjectIdentifier(bottomStore), fromId: ObjectIdentifier(topStore))
        XCTAssert(isTopObserverBottom)
        XCTAssert(!isBottomObserverTop)
        
        bottomStore.observe(store: topStore) { new, old in }
        XCTAssert(oberver.cyclicObserveCall)
        isTopObserverBottom = Store<NormalState>.isToObserveFrom(toId: ObjectIdentifier(topStore), fromId: ObjectIdentifier(bottomStore))
        isBottomObserverTop =  Store<ContainSubState>.isToObserveFrom(toId: ObjectIdentifier(bottomStore), fromId: ObjectIdentifier(topStore))
        XCTAssert(isTopObserverBottom)
        XCTAssert(isBottomObserverTop)
        
        // 测试断开循环观察
        middleStore.setCancellable.forEach { $0.cancel() }
        middleStore.setCancellable.removeAll()
        isTopObserverBottom = Store<NormalState>.isToObserveFrom(toId: ObjectIdentifier(topStore), fromId: ObjectIdentifier(bottomStore))
        isBottomObserverTop =  Store<ContainSubState>.isToObserveFrom(toId: ObjectIdentifier(bottomStore), fromId: ObjectIdentifier(topStore))
        XCTAssert(!isTopObserverBottom)
        XCTAssert(isBottomObserverTop)
        
        cancellable.cancel()
    }
    
    func testMuiltValueObserve() {
        StoreMonitor.shared.arrObservers = []
        
        let topStore = Store<NormalState>()
        let middleStore = Store<ContainState>.box(ContainState())
        var bottomStore: Store<ContainSubState>? = Store<ContainSubState>.box(ContainSubState())
        
        XCTAssertEqual(topStore.mapValueObservers[\NormalState.name]?.count ?? 0, 0)
        
        middleStore.observe(store: topStore, of: \.name) { new, old in }
        XCTAssertEqual(topStore.mapValueObservers[\NormalState.name]?.count ?? 0, 1)
        
        bottomStore!.observe(store: topStore, of: \.name) { new, old in }
        XCTAssertEqual(topStore.mapValueObservers[\NormalState.name]?.count ?? 0, 2)
        
        bottomStore = nil
        XCTAssertEqual(topStore.mapValueObservers[\NormalState.name]?.count ?? 0, 1)
    }
    
    func testStoreDestroyCallback() {
        var normalStore : Store<NormalState>? = .init()
        var destroyCallbackCall = false
        normalStore?.setDestroyCallback {_ in
            destroyCallbackCall = true
        }
        
        XCTAssert(!destroyCallbackCall)
        normalStore = nil
        XCTAssert(destroyCallbackCall)
    }
    
    func testUpStoreRemoveSubStateWhenSubStoreDestroy() {
        let upStore : Store<ContainState> = .init(state: ContainState())
        var subStore : Store<ContainSubState>? = .init(state: ContainSubState())
        
        upStore.add(subStore: subStore!)
        
        let subStateId = subStore!.state.stateId
        XCTAssertNotNil(upStore.state.subStates[subStateId])
        
        subStore = nil
        XCTAssertNil(upStore.state.subStates[subStateId])
    }
    
    func testStrictMode() {
        StoreMonitor.shared.arrObservers = []
        StoreMonitor.shared.useStrictMode = true
        defer { StoreMonitor.shared.useStrictMode = false }
        class Oberver: StoreMonitorOberver {
            var strictModeFatalErrorCall = false
            func receiveStoreEvent<State>(_ event: StoreEvent<State>) where State : StorableState {
                if case .fatalError(let message) = event,
                    message == "Never update state directly! Use send/dispatch action instead" {
                    strictModeFatalErrorCall = true
                }
            }
        }
        let oberver = Oberver()
        let cancellable = StoreMonitor.shared.addObserver(oberver)
        
        let normalStore = Store<NormalState>()
        
        XCTAssert(!oberver.strictModeFatalErrorCall)
        normalStore.state.name = ""
        XCTAssert(oberver.strictModeFatalErrorCall)
        
        oberver.strictModeFatalErrorCall = false
        normalStore.name = ""
        XCTAssert(oberver.strictModeFatalErrorCall)
        
        let subscriptStore = Store<SubscriptState>()
        oberver.strictModeFatalErrorCall = false
        subscriptStore.normalState.name = ""
        XCTAssert(oberver.strictModeFatalErrorCall)
       
        cancellable.cancel()
    }
    
    func testOptionalStateValue() {
        let optionalStore = Store<OptionalState>()
        var optionalValueChange = false
        let cancellable = optionalStore.addObserver(of: \.name) { new, old in
            optionalValueChange = true
        }
        
        XCTAssert(!optionalValueChange)
        optionalStore.name = ""
        XCTAssert(optionalValueChange)
        
        optionalValueChange = false
        optionalStore.name = ""
        XCTAssert(!optionalValueChange)
        
        optionalStore.name = nil
        XCTAssert(optionalValueChange)
        
        cancellable.cancel()
    }
    
    func testSubscriptReadOnlyState() {
        let theName = "name"
        let readOnlyStore = Store<ReadOnlyState>.box(ReadOnlyState(name: theName))
        
        XCTAssertEqual(readOnlyStore.name, theName)
    }
    
    func testNestedStateReduce() {
        let fromStore = Store<NestedReduceFromState>.box(.init())
        let toStore = Store<NestedReduceToState>.box(.init())
        
        fromStore.observeDefault(store: toStore, of: \.stateB, callback: { new,old in .changeStateB })
        toStore.observeDefault(store: fromStore, of: \.stateA, callback: { new,old in .changeStateB })
        
        XCTAssertEqual(fromStore.state.stateA, false)
        XCTAssertEqual(fromStore.state.stateB, false)
        
        fromStore.send(action: .changeStateA)
        
        XCTAssertEqual(fromStore.state.stateA, true)
        XCTAssertEqual(fromStore.state.stateB, true)
    }
    
    func testReduceInOtherReduce() {
        let recurseStore = Store<RecurseReduceState>.box(.init())
        
        XCTAssertEqual(recurseStore.state.stateA, false)
        XCTAssertEqual(recurseStore.state.stateB, false)
        
        recurseStore.send(action: .changeStateA)
        
        XCTAssertEqual(recurseStore.state.stateA, true)
        XCTAssertEqual(recurseStore.state.stateB, true)
    }
    
    func testAnyStore() {
        let name = "name"
        let normalStore = Store<NormalState>.box(.init(name: name))
        
        let anyStore = normalStore.eraseToAnyStore()
        
        XCTAssertEqual(anyStore.stateId, normalStore.stateId)
        XCTAssertNotNil(anyStore.value as? Store<NormalState>)
        XCTAssertEqual((anyStore.value as? Store<NormalState>)?.name, normalStore.name)
        XCTAssertEqual((anyStore.value as? Store<NormalState>)?.name, name)
        XCTAssertTrue(anyStore.stateType == NormalState.self)
    }
}

enum AnyAction : Action {
    case any
}

enum SpecificAction : Action {
    case specific
}

enum NestedAction: Action {
    case changeStateA
    case changeStateB
}

struct NormalState : StorableState, InitializableState {
    var name: String = ""
}

var reducerStateIsLoad = false
struct ReducerState : StorableState, ReducerLoadableState {
    static func loadReducers(on store: Store<ReducerState>) {
        reducerStateIsLoad = true
    }
}

var initReducerStateIsLoad = false
struct InitReducerState : InitializableState, ReducerLoadableState {
    static func loadReducers(on store: Store<InitReducerState>) {
        initReducerStateIsLoad = true
    }
}

struct ContainState : StorableState, StateContainable {
    
    var subStates: [String : StorableState] = [:]
    
    typealias UpState = AppState
}

struct ContainSubState : StorableState, AttachableState {
    
    typealias UpState = ContainState
    
    var subValue : Int = 0
    var testValue : Int = 0
}

struct SpecificState : StorableState, ActionBindable {
    typealias BindAction = SpecificAction
}

struct ObserveState: StorableState, InitializableState {
    var name: String = ""
    var otherValue: String = ""
}

struct OptionalState: StorableState, InitializableState {
    var name: String? = nil
}

struct SubscriptState : StorableState, InitializableState {
    var name: String = ""
    var normalState: NormalState = .init()
}

struct ReadOnlyState: StorableState {
    let name: String
}

struct NestedReduceFromState: StorableState, ReducerLoadableState, ActionBindable {
    typealias BindAction = NestedAction
    
    var stateA: Bool = false
    var stateB: Bool = false
    
    static func loadReducers(on store: Store<NestedReduceFromState>) {
        store.registerDefault { state, action in
            switch action {
            case .changeStateA:
                state.stateA.toggle()
            case .changeStateB:
                state.stateB.toggle()
            }
        }
    }
}

struct NestedReduceToState: StorableState, ReducerLoadableState, ActionBindable {
    typealias BindAction = NestedAction
    
    var stateA: Bool = false
    var stateB: Bool = false
    
    static func loadReducers(on store: Store<NestedReduceToState>) {
        store.registerDefault { state, action in
            switch action {
            case .changeStateA:
                state.stateA.toggle()
            case .changeStateB:
                state.stateB.toggle()
            }
        }
    }
}

struct RecurseReduceState: StorableState, ReducerLoadableState, ActionBindable {
    typealias BindAction = NestedAction
    
    var stateA: Bool = false
    var stateB: Bool = false
    
    static func loadReducers(on store: Store<RecurseReduceState>) {
        store.registerDefault { [weak store] state, action in
            switch action {
            case .changeStateA:
                state.stateA.toggle()
                store?.send(action: .changeStateB)
            case .changeStateB:
                state.stateB.toggle()
            }
        }
    }
}

