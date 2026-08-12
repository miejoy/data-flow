//
//  StoreTests.swift
//
//
//  Created by 黄磊 on 2020-06-25.
//

import Testing
import Combine
import Foundation
@testable import DataFlow
@testable import ModuleMonitor

@Suite(.serialized)
@MainActor
struct StoreTests {

    @Test
    func testStoreObservable() {
        let normalStore = Store<NormalState>.box(NormalState())
        var willChangeCall = false
        let cancellable = normalStore.objectWillChange.sink {
            willChangeCall = true
        }

        #expect(willChangeCall == false)
        normalStore.name = ""
        // 相同值不会调用 willChange
        #expect(willChangeCall == false)
        #expect(normalStore.name == "")
        willChangeCall = false
        normalStore.state.name = "text"
        #expect(willChangeCall)
        #expect(normalStore.state.name == "text")
        cancellable.cancel()
    }

    @Test
    func testInitializableState() {
        let normalStore = Store<NormalState>()
        #expect(normalStore.name == "")
    }

    @Test
    func testRegisterAndRetrieveSubStore() {
        let containStore = Store<ContainState>.box(ContainState())

        // 注册前获取不到子 Store
        let subStoreBefore = containStore.getSubStore(of: ContainSubState.self)
        #expect(subStoreBefore == nil)

        let subStore = Store<ContainSubState>.box(ContainSubState())
        containStore.addSubStore(subStore)

        // 注册后可以获取到子 Store
        let retrieved = containStore.getSubStore(of: ContainSubState.self)
        #expect(retrieved != nil)
        #expect(retrieved?.state.subValue == 0)

        // 子 Store 状态更新不会触发父 Store 级联通知
        var containGetCall = false
        let subscribe = containStore.objectWillChange.sink { _ in
            containGetCall = true
        }

        var state = ContainSubState()
        state.subValue = 1
        subStore.state = state

        // 不再级联通知
        #expect(containGetCall == false)

        subscribe.cancel()

        // 子 Store 自身状态是正确的
        #expect(subStore.state.subValue == 1)
    }

    @Test
    func testDumpState() {
        let containStore = Store<ContainState>.box(ContainState())
        let subStore = Store<ContainSubState>.box(ContainSubState())
        subStore.subValue = 42
        containStore.addSubStore(subStore)

        let dump = containStore.dumpState()

        #expect(dump.contains("\"subStates\""))
        #expect(dump.contains("\"subValue\""))
        #expect(dump.contains("42"))
    }

    @Test
    func testDumpStateFormatValue() {
        // 覆盖 formatValue 各分支：String / Bool / Int / Optional(nil) / Optional(value) / 嵌套 struct
        let store = Store<DumpFormatState>.box(DumpFormatState())

        let dump = store.dumpState()

        // String
        #expect(dump.contains("\"name\": \"hello\""))
        // Bool
        #expect(dump.contains("\"flag\": true"))
        // Int（兜底 String(describing:)）
        #expect(dump.contains("\"count\": 7"))
        // Optional nil -> null
        #expect(dump.contains("\"optionalName\": null"))
        // Optional value
        #expect(dump.contains("\"optionalValue\": 99"))
        // 嵌套 struct
        #expect(dump.contains("\"nested\": {"))
        #expect(dump.contains("\"nestedName\": \"world\""))
    }

    @Test
    func testCustomMirror() {
        let store = Store<NormalState>.box(NormalState(name: "mirror"))
        let mirror = Mirror(reflecting: store)

        // customMirror 应暴露 state 属性
        let nameChild = mirror.children.first { $0.label == "name" }
        #expect(nameChild != nil)
        #expect(nameChild?.value as? String == "mirror")

        // 无子 Store 时不应出现 subStates
        #expect(mirror.children.contains { $0.label == "subStates" } == false)
    }

    @Test
    func testCustomMirrorWithSubStore() {
        let containStore = Store<ContainState>.box(ContainState())
        let subStore = Store<ContainSubState>.box(ContainSubState())
        subStore.subValue = 88
        containStore.addSubStore(subStore)

        let mirror = Mirror(reflecting: containStore)
        let subStatesChild = mirror.children.first { $0.label == "subStates" }
        #expect(subStatesChild != nil)

        // subStates 应包含子 Store
        let subMirror = Mirror(reflecting: subStatesChild!.value)
        #expect(subMirror.children.count == 1)
    }

    @Test
    func testStateValue() {
        let store = Store<NormalState>.box(NormalState(name: "hello"))

        #expect(store.stateValue(\.name) == "hello")

        store.name = "world"
        #expect(store.stateValue(\.name) == "world")
    }

    @Test
    func testStateValueCrossThread() async {
        let store = Store<NormalState>.box(NormalState(name: "cross"))

        let value = await Task.detached { () -> String in
            store.stateValue(\.name)
        }.value

        #expect(value == "cross")
    }

    @Test
    func testDumpStateCrossThread() async {
        let store = Store<NormalState>.box(NormalState(name: "dump"))

        let dump = await Task.detached { () -> String in
            store.dumpState()
        }.value

        #expect(dump.contains("\"name\""))
        #expect(dump.contains("dump"))
    }

    @Test
    func testStateIdCrossThread() async {
        let store = Store<NormalState>.box(NormalState(name: "id"))

        let stateId = await Task.detached { () -> String in
            store.stateId
        }.value

        #expect(stateId == store.stateId)
    }

    @Test
    func testReducerLoadableState() {
        reducerStateIsLoad = false
        _ = Store<ReducerState>.box(.init())
        #expect(reducerStateIsLoad)
    }

    @Test
    func testStateInitReducerLoadable() {
        initReducerStateIsLoad = false
        _ = Store<InitReducerState>()
        #expect(initReducerStateIsLoad)
    }

    @Test
    func testSubscriptProperty() {
        let store = Store<SubscriptState>()

        #expect(store.normalState.name == "")

        store.normalState.name = "text"
        #expect(store.normalState.name == "text")
    }

    @Test
    func testSubscriptEquatable() {
        let store = Store<SubscriptState>()

        #expect(store.name == "")

        store.name = "text"
        #expect(store.name == "text")
    }

    @Test
    func testSendAnyAction() {
        let normalStore = Store<NormalState>.box(NormalState())
        var reducerCall = false
        normalStore.register { (state, action: AnyAction) in
            reducerCall = true
        }

        normalStore.send(action: AnyAction.any)
        let block = normalStore.mapReducer[ObjectIdentifier(AnyAction.self)]

        #expect(reducerCall)
        #expect(block != nil)
    }

    @Test
    func testSendSpecificAction() {
        let specificStore = Store<SpecificState>.box(SpecificState())
        var reducerCall = false
        specificStore.registerDefault { (state, action) in
            reducerCall = true
        }

        specificStore.send(action: .specific)
        let block = specificStore.mapReducer[ObjectIdentifier(SpecificAction.self)]

        #expect(reducerCall)
        #expect(block != nil)
    }

    @Test
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

        #expect(reducerCall == false)
        #expect(observeStateCall == false)
        #expect(observeValueCall == false)

        normalStore.state = NormalState()
        #expect(reducerCall)
        #expect(observeStateCall)
        #expect(observeValueCall == false)

        reducerCall = false
        observeStateCall = false
        normalStore.state.name = ""
        #expect(reducerCall)
        #expect(observeStateCall)
        #expect(observeValueCall == false)

        reducerCall = false
        observeStateCall = false
        normalStore.state.name = "new"
        #expect(reducerCall)
        #expect(observeStateCall)
        #expect(observeValueCall)
    }

    @Test
    func testDispatchAction() async {
        let normalStore = Store<NormalState>.box(NormalState())
        var reducerCall = false
        var isMainThread = false

        normalStore.register { (state, action: SpecificAction) in
            reducerCall = true
            isMainThread = Thread.isMainThread
        }

        normalStore.dispatch(action: SpecificAction.specific)

        // dispatch 内部 Task { @MainActor in } 异步执行，等待一拍
        await Task.yield()
        await Task.yield()

        #expect(reducerCall)
        #expect(isMainThread)
    }

    @Test
    func testDispatchSpecificAction() async {
        let specificStore = Store<SpecificState>.box(SpecificState())
        var reducerCall = false
        var isMainThread = false

        specificStore.register { (state, action: SpecificAction) in
            reducerCall = true
            isMainThread = Thread.isMainThread
        }

        specificStore.dispatch(action: .specific)

        await Task.yield()
        await Task.yield()

        #expect(reducerCall)
        #expect(isMainThread)
    }

    @Test
    func testStoreSubscript() {
        s_mapSharedStore.removeAll()
        s_mapStateObserve.removeAll()
        let subStore = Store<ContainSubState>.box(ContainSubState())

        #expect(subStore.subValue == 0)

        subStore.state.subValue = 1
        #expect(subStore.subValue == 1)

        subStore.subValue = 2
        #expect(subStore.state.subValue == 2)

        subStore.subValue = 3
        #expect(subStore.state.subValue == 3)
    }

    @Test
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

        #expect(observeStateCall)
        #expect(observeValueCall)

        observeStateCall = false
        observeValueCall = false
        secondStore.name = "text1"
        #expect(observeStateCall)
        #expect(observeValueCall)

        observeStateCall = false
        observeValueCall = false
        secondStore.otherValue = "text"
        #expect(observeStateCall)
        #expect(observeValueCall == false)
    }

    @Test
    func testStoreObserveValueWithState() {
        let firstStore: Store<ObserveState> = Store<ObserveState>()
        let secondStore = Store<ObserveState>()

        var newName = "text"
        var observeValueCall = false
        firstStore.observe(store: secondStore, of: \.name) { new, old, newState, oldState in
            observeValueCall = true
            #expect(new == newName)
            #expect(newState.name == newName)
            #expect(new != old)
            #expect(newState.name != oldState.name)
        }

        secondStore.name = newName

        #expect(observeValueCall)

        observeValueCall = false
        newName = "text1"
        secondStore.name = newName
        #expect(observeValueCall)

        observeValueCall = false
        secondStore.otherValue = "text"
        #expect(observeValueCall == false)
    }

    @Test
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
        #expect(observeValueCall)
        #expect(actionCall)

        var observeStateCall = false
        firstStore.observe(store: secondStore) { (new, old) -> AnyAction in
            observeStateCall = true
            return AnyAction.any
        }

        actionCall = false
        observeStateCall = false
        observeValueCall = false
        secondStore.otherValue = "text"
        #expect(observeStateCall)
        #expect(observeValueCall == false)
        #expect(actionCall)
    }

    @Test
    func testStoreObserveRepeat() {
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var repeatObserveCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                   message.starts(with: "Repeat observe from ")
                {
                    repeatObserveCall = true
                }
            }
        }

        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)

        let firstStore: Store<ObserveState> = Store<ObserveState>()
        let secondStore = Store<ObserveState>()

        firstStore.observe(store: secondStore) { _,_ in}
        #expect(observer.repeatObserveCall == false)

        firstStore.observe(store: secondStore) { _,_ in}
        #expect(observer.repeatObserveCall)


        observer.repeatObserveCall = false
        firstStore.observe(store: secondStore, of: \.name) { _,_ in}
        #expect(observer.repeatObserveCall == false)

        firstStore.observe(store: secondStore, of: \.name) { _,_ in}
        #expect(observer.repeatObserveCall)

        cancellable.cancel()
    }

    @Test
    func testMapCancellableCleanupWhenObservedStoreDestroyed() {
        let firstStore = Store<ObserveState>()
        var secondStore: Store<ObserveState>? = Store<ObserveState>()
        let secondStoreObjectId = ObjectIdentifier(secondStore!)

        firstStore.observe(store: secondStore!) { _, _ in }
        firstStore.observe(store: secondStore!, of: \.name) { _, _ in }

        // B 释放前，firstStore.mapCancellable 有对应条目
        #expect(firstStore.mapCancellable[secondStoreObjectId] != nil)

        secondStore = nil

        // 期望：B 释放后 mapCancellable 自动清理
        #expect(firstStore.mapCancellable[secondStoreObjectId] == nil)
    }

    @Test
    func testObserveNewStoreAfterOldStoreDestroyed() {
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var repeatObserveCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                   message.starts(with: "Repeat observe from ")
                {
                    repeatObserveCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)
        defer { cancellable.cancel() }

        let firstStore = Store<ObserveState>()
        var secondStore: Store<ObserveState>? = Store<ObserveState>()
        let secondStoreId = ObjectIdentifier(secondStore!)

        firstStore.observe(store: secondStore!) { _, _ in }
        #expect(observer.repeatObserveCall == false)

        // 释放 B
        secondStore = nil

        // 新建 B，Swift 可能复用同一内存地址，ObjectIdentifier 和旧 B 相同
        var thirdStore: Store<ObserveState>? = Store<ObserveState>()
        if ObjectIdentifier(thirdStore!) == secondStoreId {
            // ObjectIdentifier 复用：A observe 新 B 时应该正常，不应 fatalError
            firstStore.observe(store: thirdStore!) { _, _ in }
            #expect(observer.repeatObserveCall == false)
        } else {
            // ObjectIdentifier 未复用：直接验证正常 observe
            firstStore.observe(store: thirdStore!) { _, _ in }
            #expect(observer.repeatObserveCall == false)
        }
        thirdStore = nil
    }

    @Test
    func testStoreUnobserve() {
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

        #expect(observeStateCall)
        #expect(observeValueCall)

        observeStateCall = false
        observeValueCall = false
        firstStore.unobserve(store: secondStore)
        secondStore.name = "text1"
        #expect(observeStateCall == false)
        #expect(observeValueCall)

        observeStateCall = false
        observeValueCall = false
        firstStore.unobserve(store: secondStore, of: \.name)
        secondStore.name = "text"
        #expect(observeStateCall == false)
        #expect(observeValueCall == false)
    }

    @Test
    func testStoreUnobserveAll() {
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

        #expect(observeStateCall)
        #expect(observeValueCall)

        observeStateCall = false
        observeValueCall = false
        firstStore.unobserveAll(store: secondStore)
        secondStore.name = "text1"
        #expect(observeStateCall == false)
        #expect(observeValueCall == false)
    }

    @Test
    func testCancelObserverWhenDestroy() {
        var firstStore: Store<NormalState>? = Store<NormalState>()
        let secondStore = Store<NormalState>()
        #expect(secondStore.arrObservers.count == 0)
        #expect(secondStore.mapValueObservers.count == 0)
        #expect(secondStore.mapValueObservers[\NormalState.name] == nil)

        firstStore!.observe(store: secondStore) { new, old in }
        #expect(secondStore.arrObservers.count == 1)
        #expect(secondStore.generateObserverId == 1)

        firstStore!.observe(store: secondStore, of: \.name) { new, old in }
        #expect(secondStore.mapValueObservers.count == 1)
        #expect(secondStore.mapValueObservers[\NormalState.name]?.count == 1)
        #expect(secondStore.generateObserverId == 2)

        firstStore = nil
        #expect(secondStore.arrObservers.count == 0)
        #expect(secondStore.mapValueObservers.count == 0)
    }

    @Test
    func testNotifyWillCallWhileStateChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let cancellable = normalStore.addObserver { new, old in
            observerCall = true
        }

        normalStore.send(action: AnyAction.any)
        #expect(reduceCall == false)
        #expect(observerCall == false)

        normalStore.register { (state, action: AnyAction) in
            // 这里即使不对 state 做任何操作，对应 observer 也会被调用，这个 & 机制问题
            state.name = "new"
            reduceCall = true
        }

        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall == false)
    }

    @Test
    func testNotifyWillCallWhileValueChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let oldName = normalStore.name
        let newName = "new"
        #expect(newName != oldName)
        let cancellable = normalStore.addObserver(of: \.name) { new, old in
            observerCall = true
        }
        normalStore.register { (state, action: AnyAction) in
            state.name = newName
            reduceCall = true
        }

        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall)
        #expect(normalStore.name == newName)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall == false)
        #expect(normalStore.name == newName)
    }

    @Test
    func testNotifyWillCallWhileValueAndStateChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let oldName = normalStore.name
        let newName = "new"
        #expect(newName != oldName)
        let cancellable = normalStore.addObserver(of: \.name) { new, old, newState, oldState in
            observerCall = true
            #expect(new != old)
            #expect(newState.name != oldState.name)
            #expect(new == newName)
            #expect(newState.name == newName)
        }
        normalStore.register { (state, action: AnyAction) in
            state.name = newName
            reduceCall = true
        }

        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall)
        #expect(normalStore.name == newName)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall == false)
        #expect(normalStore.name == newName)
    }

    @Test
    func testNotifyWillNeverCallWhileValueNotChange() {
        let normalStore: Store<NormalState> = Store<NormalState>()
        var reduceCall = false
        var observerCall = false
        let cancellable = normalStore.addObserver(of: \.name) { _, _ in observerCall = true }
        normalStore.register { (state, action: AnyAction) in
            reduceCall = true
        }

        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall == false)
        reduceCall = false
        observerCall = false
        cancellable.cancel()
        normalStore.send(action: AnyAction.any)
        #expect(reduceCall)
        #expect(observerCall == false)
    }

    @Test
    func testCyclicObserve() {
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var cyclicObserveCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .cyclicObserve = event {
                    cyclicObserveCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)

        let fromStore = Store<NormalState>()
        let toStore = Store<SpecificState>.box(SpecificState())

        #expect(observer.cyclicObserveCall == false)

        toStore.observe(store: fromStore) { new,old in }
        #expect(observer.cyclicObserveCall == false)

        fromStore.observe(store: toStore) { new,old in }
        #expect(observer.cyclicObserveCall)

        cancellable.cancel()
    }

    @Test
    func testCyclicObserveIndirect() {
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var cyclicObserveCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .cyclicObserve = event {
                    cyclicObserveCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)

        let topStore = Store<NormalState>()
        let middleStore = Store<ContainState>.box(ContainState())
        let bottomStore = Store<ContainSubState>.box(ContainSubState())

        #expect(observer.cyclicObserveCall == false)

        topStore.observe(store: middleStore) { new,old in }
        #expect(observer.cyclicObserveCall == false)

        // addSubStore 不再创建 observer 链
        middleStore.addSubStore(bottomStore)

        var isTopObserverBottom = Store<NormalState>.isToObserveFrom(toId: ObjectIdentifier(topStore), fromId: ObjectIdentifier(bottomStore))
        #expect(isTopObserverBottom == false)

        // 显式 observe 建立传递链：top → middle → bottom
        middleStore.observe(store: bottomStore) { new, old in }
        isTopObserverBottom = Store<NormalState>.isToObserveFrom(toId: ObjectIdentifier(topStore), fromId: ObjectIdentifier(bottomStore))
        #expect(isTopObserverBottom)

        let isBottomObserverTop = Store<ContainSubState>.isToObserveFrom(toId: ObjectIdentifier(bottomStore), fromId: ObjectIdentifier(topStore))
        #expect(isBottomObserverTop == false)

        // bottom → top 形成循环
        bottomStore.observe(store: topStore) { new, old in }
        #expect(observer.cyclicObserveCall)

        cancellable.cancel()
    }

    @Test
    func testMultiValueObserve() {
        StoreMonitor.shared.arrObservers = []

        let topStore = Store<NormalState>()
        let middleStore = Store<ContainState>.box(ContainState())
        var bottomStore: Store<ContainSubState>? = Store<ContainSubState>.box(ContainSubState())

        #expect(topStore.mapValueObservers[\NormalState.name]?.count ?? 0 == 0)

        middleStore.observe(store: topStore, of: \.name) { new, old in }
        #expect(topStore.mapValueObservers[\NormalState.name]?.count ?? 0 == 1)

        bottomStore!.observe(store: topStore, of: \.name) { new, old in }
        #expect(topStore.mapValueObservers[\NormalState.name]?.count ?? 0 == 2)

        bottomStore = nil
        #expect(topStore.mapValueObservers[\NormalState.name]?.count ?? 0 == 1)
    }

    @Test
    func testStoreDestroyCallback() {
        var normalStore : Store<NormalState>? = .init()
        var destroyCallbackCall = false
        normalStore?.addDestroyCallback {_ in
            destroyCallbackCall = true
        }

        #expect(destroyCallbackCall == false)
        normalStore = nil
        #expect(destroyCallbackCall)
    }

    @Test
    func testRemoveSubStoreWhenSubStoreDestroy() {
        let upStore : Store<ContainState> = .init(state: ContainState())
        var subStore : Store<ContainSubState>? = .init(state: ContainSubState())

        upStore.addSubStore(subStore!)

        #expect(upStore.getSubStore(of: ContainSubState.self) != nil)

        subStore = nil
        #expect(upStore.getSubStore(of: ContainSubState.self) == nil)
    }

    @Test
    func testMultipleSubStoresWithSameType() {
        let upStore = Store<ContainState>.box(ContainState())

        // 同类型两个不同实例，通过实例 stateId 区分，挂到同一 UpStore
        let store1 = Store<InstanceIdSubState>.box(InstanceIdSubState(tag: "a", stateId: "instance1"))
        let store2 = Store<InstanceIdSubState>.box(InstanceIdSubState(tag: "b", stateId: "instance2"))

        upStore.addSubStore(store1)
        upStore.addSubStore(store2)

        // 用不同 stateId 分别获取
        #expect(upStore.getSubStore(of: InstanceIdSubState.self, stateId: "instance1")?.state.tag == "a")
        #expect(upStore.getSubStore(of: InstanceIdSubState.self, stateId: "instance2")?.state.tag == "b")

        // 不传 stateId 用 defaultStateId，找不到（因为 add 时用的是实例 stateId）
        #expect(upStore.getSubStore(of: InstanceIdSubState.self) == nil)
    }

    @Test
    func testDefaultStateIdUsedWhenNoCustomStateId() {
        let upStore = Store<ContainState>.box(ContainState())

        // stateId 未自定义，add 用 stateId（= defaultStateId），get 不传也用 defaultStateId
        let subStore = Store<MultiInstanceSubState>.box(MultiInstanceSubState())
        upStore.addSubStore(subStore)

        // 不传 stateId，走 defaultStateId
        #expect(upStore.getSubStore(of: MultiInstanceSubState.self) != nil)
        #expect(upStore.getSubStore(of: MultiInstanceSubState.self)?.state.tag == "")

        // 传与 defaultStateId 一致的 stateId 也能获取
        #expect(upStore.getSubStore(of: MultiInstanceSubState.self, stateId: "MultiInstanceSubState") != nil)
    }

    @Test
    func testAddSubStoreWithWildcardUpState() {
        // 重载 2：父精确 + 子通配（State.SubState == S, S.UpState == AnyState）
        let upStore = Store<SpecificContainState>.box(SpecificContainState())
        let subStore = Store<WildcardSubState>.box(WildcardSubState(tag: "wild"))
        upStore.addSubStore(subStore)

        #expect(upStore.getSubStore(of: WildcardSubState.self) != nil)
        #expect(upStore.getSubStore(of: WildcardSubState.self)?.state.tag == "wild")
    }

    @Test
    func testSubStateIds() {
        let upStore = Store<ContainState>.box(ContainState())
        #expect(upStore.subStateIds.isEmpty)

        let sub1 = Store<ContainSubState>.box(ContainSubState())
        upStore.addSubStore(sub1)

        let sub2 = Store<MultiInstanceSubState>.box(MultiInstanceSubState())
        upStore.addSubStore(sub2)

        // 按 stateId 排序
        #expect(upStore.subStateIds == ["ContainSubState", "MultiInstanceSubState"])
    }

    @Test
    func testSubContainers() {
        let upStore = Store<ContainState>.box(ContainState())
        #expect(upStore.subContainers.isEmpty)

        let sub1 = Store<ContainSubState>.box(ContainSubState())
        upStore.addSubStore(sub1)
        let sub2 = Store<MultiInstanceSubState>.box(MultiInstanceSubState())
        upStore.addSubStore(sub2)

        #expect(upStore.subContainers.count == 2)
    }

    @Test
    func testSubStoreRuntimeCheckMismatch() {
        // 重载 1 运行时校验：State.SubState != S 且 != AnyState 时 fatalError
        StoreMonitor.shared.arrObservers = []
        StoreMonitor.shared.useStrictMode = true
        defer { StoreMonitor.shared.useStrictMode = false }
        @MainActor
        final class Observer: StoreMonitorObserver {
            var fatalErrorCalled = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                    message.contains("is neither") {
                    fatalErrorCalled = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)

        // MismatchContainState.SubState == ContainSubState，但挂载 MismatchSubState
        let upStore = Store<MismatchContainState>.box(MismatchContainState())
        let subStore = Store<MismatchSubState>.box(MismatchSubState())
        upStore.addSubStore(subStore)

        #expect(observer.fatalErrorCalled)

        cancellable.cancel()
    }

    @Test
    func testStrictMode() {
        StoreMonitor.shared.arrObservers = []
        StoreMonitor.shared.useStrictMode = true
        defer { StoreMonitor.shared.useStrictMode = false }
        @MainActor
        final class Observer: StoreMonitorObserver {
            var strictModeFatalErrorCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                    message == "Never update state directly! Use send/dispatch action instead" {
                    strictModeFatalErrorCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)

        let normalStore = Store<NormalState>()

        #expect(observer.strictModeFatalErrorCall == false)
        normalStore.state.name = ""
        #expect(observer.strictModeFatalErrorCall)

        observer.strictModeFatalErrorCall = false
        normalStore.name = ""
        #expect(observer.strictModeFatalErrorCall)

        let subscriptStore = Store<SubscriptState>()
        observer.strictModeFatalErrorCall = false
        subscriptStore.normalState.name = ""
        #expect(observer.strictModeFatalErrorCall)

        cancellable.cancel()
    }

    @Test
    func testOptionalStateValue() {
        let optionalStore = Store<OptionalState>()
        var optionalValueChange = false
        let cancellable = optionalStore.addObserver(of: \.name) { new, old in
            optionalValueChange = true
        }

        #expect(optionalValueChange == false)
        optionalStore.name = ""
        #expect(optionalValueChange)

        optionalValueChange = false
        optionalStore.name = ""
        #expect(optionalValueChange == false)

        optionalStore.name = nil
        #expect(optionalValueChange)

        cancellable.cancel()
    }

    @Test
    func testSubscriptReadOnlyState() {
        let theName = "name"
        let readOnlyStore = Store<ReadOnlyState>.box(ReadOnlyState(name: theName))

        #expect(readOnlyStore.name == theName)
    }

    @Test
    func testNestedStateReduce() {
        let fromStore = Store<NestedReduceFromState>.box(.init())
        let toStore = Store<NestedReduceToState>.box(.init())

        fromStore.observeDefault(store: toStore, of: \.stateB, callback: { new,old in .changeStateB })
        toStore.observeDefault(store: fromStore, of: \.stateA, callback: { new,old in .changeStateB })

        #expect(fromStore.state.stateA == false)
        #expect(fromStore.state.stateB == false)

        fromStore.send(action: .changeStateA)

        #expect(fromStore.state.stateA)
        #expect(fromStore.state.stateB)
    }

    @Test
    func testReduceInOtherReduce() {
        let recurseStore = Store<RecurseReduceState>.box(.init())

        #expect(recurseStore.state.stateA == false)
        #expect(recurseStore.state.stateB == false)

        recurseStore.send(action: .changeStateA)

        #expect(recurseStore.state.stateA)
        #expect(recurseStore.state.stateB)
    }

    @Test
    func testAnyStore() {
        let name = "name"
        let normalStore = Store<NormalState>.box(.init(name: name))

        let anyStore = normalStore.eraseToAny()

        #expect(anyStore.stateId == normalStore.stateId)
        #expect(anyStore.store as? Store<NormalState> != nil)
        #expect((anyStore.store as? Store<NormalState>)?.name == normalStore.name)
        #expect((anyStore.store as? Store<NormalState>)?.name == name)
        #expect((anyStore.state as? NormalState)?.name == name)
        #expect(String(describing: anyStore.stateType) == String(describing: NormalState.self))
    }

    @Test
    func testStoreStorage() {
        let normalStore = Store<NormalState>.box(.init(name: "test"))

        #expect(normalStore[.viewId] == nil)

        // 测试普通设置
        let newViewId = "NewViewId"
        normalStore[.viewId] = newViewId
        #expect(normalStore[.viewId] == newViewId)

        // 测试读取默认值时设置
        let defaultViewId = "DefaultViewId"
        #expect(normalStore[.viewId, default: defaultViewId] == newViewId)

        // 重置一下
        normalStore[.viewId] = nil
        #expect(normalStore[.viewId] == nil)

        #expect(normalStore[.viewId, default: defaultViewId] == defaultViewId)
        #expect(normalStore[.viewId] == defaultViewId)
    }

    @Test
    func testDefaultStoreStorage() {
        let normalStore = Store<NormalState>.box(.init(name: "test"))

        let defaultViewId = "DefaultViewId"
        // 首次读取
        #expect(normalStore[.defaultViewId] == defaultViewId)

        // 二次读取
        #expect(normalStore[.defaultViewId] == defaultViewId)

        // 覆盖后读取
        let newViewId = "NewViewId"
        normalStore[.defaultViewId] = newViewId
        #expect(normalStore[.defaultViewId] == newViewId)
    }

    @Test
    func testStateOnStoreStorage() {
        let normalStore = Store<NormalState>.box(.init(name: "test"))

        #expect(normalStore[.normalViewId] == nil)

        // 测试普通设置
        let newViewId = "NewViewId"
        normalStore[.normalViewId] = newViewId
        #expect(normalStore[.normalViewId] == newViewId)

        // 测试读取默认值时设置
        let defaultViewId = "DefaultViewId"
        #expect(normalStore[.normalViewId, default: defaultViewId] == newViewId)

        // 重置一下
        normalStore[.normalViewId] = nil
        #expect(normalStore[.normalViewId] == nil)

        #expect(normalStore[.normalViewId, default: defaultViewId] == defaultViewId)
        #expect(normalStore[.normalViewId] == defaultViewId)
    }

    @Test
    func testDefaultStateOnStoreStorage() {
        let normalStore = Store<NormalState>.box(.init(name: "test"))

        let defaultViewId = "DefaultNormalViewId"
        // 首次读取
        #expect(normalStore[.defaultNormalViewId] == defaultViewId)

        // 二次读取
        #expect(normalStore[.defaultNormalViewId] == defaultViewId)

        // 覆盖后读取
        let newViewId = "NewViewId"
        normalStore[.defaultNormalViewId] = newViewId
        #expect(normalStore[.defaultNormalViewId] == newViewId)
    }

    @Test
    func testGetStoreConfig() {
        let configValue = "test123"
        let normalStore = Store<NormalState>.box(.init(name: "test"), configs: [.make(.testConfig, configValue)])
        #expect(normalStore[.testConfig] == configValue)
        #expect(StoreConfigKey<String>.testConfig.description == "TextConfig<String>")
    }

    @Test
    func testGetStoreConfigWithDefaultValue() {
        let defaultConfigValue = "default123"
        let normalStore = Store<NormalState>.box(.init(name: "test"))
        #expect(normalStore[.testConfig, default: defaultConfigValue] == defaultConfigValue)
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

struct NormalState : StorableState, UseInitializableState {
    var name: String = ""
}

@MainActor var reducerStateIsLoad = false
struct ReducerState : StorableState, ReducerLoadableState {
    static func loadReducers(on store: Store<ReducerState>) {
        reducerStateIsLoad = true
    }
}

@MainActor var initReducerStateIsLoad = false
struct InitReducerState : UseInitializableState, ReducerLoadableState {
    static func loadReducers(on store: Store<InitReducerState>) {
        initReducerStateIsLoad = true
    }
}

struct ContainState : StorableState, StateContainable {
    typealias UpState = AppState
    public init() {}
}

struct ContainSubState : StorableState, AttachableState {

    typealias UpState = ContainState

    var subValue : Int = 0
    var testValue : Int = 0
}

/// 精确 SubState 的父状态，SubState 指定为其子状态类型
struct SpecificContainState: StorableState, StateContainable {
    typealias UpState = AppState
    typealias SubState = WildcardSubState
    public init() {}
}

/// 通配子状态，UpState 设为 AnyState，可挂载到任何指定 SubState 为自己的 StateContainable
struct WildcardSubState: StorableState, AttachableState {
    typealias UpState = AnyState
    var tag: String = ""
}

/// 不匹配的 SubState 类型，用于测试运行时校验
struct MismatchContainState: StorableState, StateContainable {
    typealias UpState = AppState
    typealias SubState = ContainSubState
    public init() {}
}

/// UpState 指向 MismatchContainState，但类型不匹配其 SubState（ContainSubState）
struct MismatchSubState: StorableState, AttachableState {
    typealias UpState = MismatchContainState
    var tag: String = ""
}

/// 自定义 defaultStateId 的 AttachableState，用于测试多实例场景
struct MultiInstanceSubState : StorableState, AttachableState {
    typealias UpState = ContainState
    var tag: String = ""
    static var defaultStateId: String { "MultiInstanceSubState" }
}

/// 带实例级 stateId 的 AttachableState，用于测试同类型多实例挂载
struct InstanceIdSubState : StorableState, AttachableState {
    typealias UpState = ContainState
    var tag: String = ""
    /// 实例级 stateId，每个实例可不同
    var stateId: String
    init(tag: String = "", stateId: String) {
        self.tag = tag
        self.stateId = stateId
    }
}

struct SpecificState : StorableState, ActionBindable {
    typealias BindAction = SpecificAction
}

struct ObserveState: StorableState, UseInitializableState {
    var name: String = ""
    var otherValue: String = ""
}

struct OptionalState: StorableState, UseInitializableState {
    var name: String? = nil
}

struct SubscriptState : StorableState, UseInitializableState {
    var name: String = ""
    var normalState: NormalState = .init()
}

struct ReadOnlyState: StorableState {
    let name: String
}

/// 用于测试 dumpState 中 formatValue 的各分支
struct DumpNestedState: StorableState {
    var nestedName: String = "world"
}

struct DumpFormatState: StorableState {
    var name: String = "hello"
    var flag: Bool = true
    var count: Int = 7
    var optionalName: String? = nil
    var optionalValue: Int? = 99
    var nested: DumpNestedState = .init()
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

extension StoreStorageKey where Value == String {
    static let viewId: Self = .init("viewId")
}

extension DefaultStoreStorageKey where Value == String {
    static let defaultViewId: Self = .init("defaultViewId", "DefaultViewId")
}

extension StateOnStoreStorageKey where Value == String, State == NormalState {
    static let normalViewId: Self = .init("normalViewId")
}

extension DefaultStateOnStoreStorageKey where Value == String, State == NormalState {
    static let defaultNormalViewId: Self = .init("normalViewId", "DefaultNormalViewId")
}

extension StoreConfigKey where Value == String {
    static let testConfig: StoreConfigKey<Value> = .init("TextConfig")
}
