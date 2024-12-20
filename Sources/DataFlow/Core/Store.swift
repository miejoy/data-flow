//
//  Store.swift
//
//
//  Created by 黄磊 on 2020-06-20.
//  Copyright © 2020 Miejoy. All rights reserved.
//  存储器，引用类型。用于保存状态，提供给界面绑定并分发和处理界面事件

import Foundation
import Combine

/// 事件处理器
public typealias Reducer<StorableState,Action> = (_ state: inout StorableState, _ action: Action) -> Void

/// 循环观察检查存储器，保存了所有 store 的观察关系，用于避免 state 的循环观察，ObjectIdentifier 为 store 实例的唯一值
var s_mapStateObserve : [ObjectIdentifier:[ObjectIdentifier]] = [:]

/// 通用存储器
@dynamicMemberLookup
public final class Store<State: StorableState>: ObservableObject {
    
    public typealias StateChangeCallback = (_ new: State, _ old: State) -> Void
    typealias StateValueChangeCallback = (_ new: Any, _ old: Any, _ newState: State, _ oldState: State) -> Void
    
    /// 从哪里触发的处理器
    public enum ReduceFrom {
        case send
        case apply
        case dispatch
    }

    /// 状态值监听者
    struct StateValueObserver {
        let observerId: Int
        let callback: Store.StateValueChangeCallback
        
        func run(_ new: Any, _ old: Any, _ newState: State, _ oldState: State) {
            callback(new, old, newState, oldState)
        }
    }
    
    /// 保存的状态，供外部调用
    public var state : State {
        get {
            _state
        }
        set {
            StoreMonitor.shared.record(event: .willDirectUpdateStateOn(self, newValue))
            if StoreMonitor.shared.useStrictMode {
                StoreMonitor.shared.fatalError("Never update state directly! Use send/dispatch action instead")
            }
            updateStateWithNotify(newValue)
        }
    }
    /// 实际保存的状态，仅可内部调用
    @Published var _state : State {
        didSet {
            for observer in arrObservers {
                observer.run(_state, oldValue)
            }
        }
    }
    
    // 这两个属性为了解决一个 state 在处理一个 action 的途中触发需要处理另一个 action
    // 当前正在处理的 action
    var reducingAction: Action? = nil
    // 如果存在处理中的 action，这里会保存带处理的 action
    var pendingActions: [(Action, ReduceFrom)] = []
    
    /// 存储处理器 [ObjectIdentifier(Action) : ( [dependerId], Reducer) ]
    var mapReducer : [ObjectIdentifier: ([ReduceDependerId], Reducer<State,Action>)] = [:]
    var mapValueObservers : [AnyKeyPath: [StateValueObserver]] = [:]
    var arrObservers : [StateObserver<State>] = []
    /// 保持自身监听其他 store 的 AnyCancellable
    var mapCancellable : [ObjectIdentifier: [AnyKeyPath: AnyCancellable]] = [:]
    var destroyCallback : ((State) -> Void)? = nil
    var generateObserverId: Int = 0
    
    /// 通用存储空间
    var storage: StoreStorage = .init()
    
    // MARK: - Init
    
    /// 包装对应状态，生成临时存储器，不会被共享
    ///
    /// - Parameter state: 需要包装的状态
    /// - Returns: 返回对应存储器
    public static func box(_ state: State) -> Self {
        return self.init(state: state)
    }
    
    init(state: State) {
        self._state = state
        State.didBoxed(on: self)
        StoreMonitor.shared.record(event: .createStore(self))
    }
    
    // MARK: - Get & Set
    
    /// 动态嫁接 State 属性调用，可嫁接只读属性
    public subscript<Subject>(dynamicMember keyPath: KeyPath<State, Subject>) -> Subject {
        get {
            return _state[keyPath: keyPath]
        }
    }
    
    /// 动态嫁接可比较的 State 属性调用
    public subscript<Subject: Equatable>(dynamicMember keyPath: WritableKeyPath<State, Subject>) -> Subject {
        get {
            return _state[keyPath: keyPath]
        }
        set {
            if StoreMonitor.shared.useStrictMode {
                StoreMonitor.shared.fatalError("Never update state directly! Use send/dispatch action instead")
            }
            if _state[keyPath: keyPath] == newValue {
                // 相同值不更新 state
                return
            }
            var state = _state
            state[keyPath: keyPath] = newValue
            StoreMonitor.shared.record(event: .willDirectUpdateStateValueOn(self, keyPath, newValue))
            updateStateWithNotify(state, on: keyPath)
        }
    }
    
    /// 动态嫁接 State 属性调用（暂时保留，后面考虑是否移除）
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<State, Subject>) -> Subject {
        get {
            return _state[keyPath: keyPath]
        }
        set {
            if StoreMonitor.shared.useStrictMode {
                StoreMonitor.shared.fatalError("Never update state directly! Use send/dispatch action instead")
            }
            var state = _state
            state[keyPath: keyPath] = newValue
            StoreMonitor.shared.record(event: .willDirectUpdateStateValueOn(self, keyPath, newValue))
            updateStateWithNotify(state, on: keyPath)
        }
    }
    
    
    // MARK: - Register
    
    /// 注册状态处理方法
    ///
    /// - Parameter reducer: 注册的处理方法
    public func register<A:Action>(dependers: [ReduceDependerId] = [], reducer: @escaping Reducer<State,A>) {
        assert(Thread.isMainThread, "Should call on main thread")
        self.mapReducer[ObjectIdentifier(A.self)] = (dependers, { state, action in
            if let specificAction = action as? A {
                reducer(&state, specificAction)
            }
        })
    }
    
    
    // MARK: - Observe
    
    /// 观察当前状态的变化
    ///
    /// - Warning: 这里很容易出现循环观察的情况，需要自行考虑清楚，如果无法判断，请使用 observe(store:) 自动判断
    /// - Parameter callback: 当前状态变化时的回调
    public func addObserver(callback: @escaping StateChangeCallback) -> AnyCancellable {
        assert(Thread.isMainThread, "Should call on main thread")
        generateObserverId += 1
        let observerId = generateObserverId
        arrObservers.append(StateObserver(observerId: observerId, callback: callback))
        return AnyCancellable { [weak self] in
            if let index = self?.arrObservers.firstIndex(where: { $0.observerId == observerId}) {
                self?.arrObservers.remove(at: index)
            }
        }
    }
    
    /// 观察某个状态的某个值变化
    ///
    /// - Parameter keyPath: 对应值的 keyPath
    /// - Parameter callback: 对应值的变化时的回调
    public func addObserver<T: Equatable>(of keyPath: KeyPath<State, T>, callback: @escaping (_ new: T, _ old: T) -> Void) -> AnyCancellable {
        addObserver(of: keyPath) { new, old, _, _ in
            callback(new, old)
        }
    }
    
    /// 观察某个状态的某个值变化
    ///
    /// - Parameter keyPath: 对应值的 keyPath
    /// - Parameter callback: 对应值的变化时的回调
    public func addObserver<T: Equatable>(of keyPath: KeyPath<State, T>, callback: @escaping (_ new: T, _ old: T, _ newState: State, _ oldState: State) -> Void) -> AnyCancellable {
        assert(Thread.isMainThread, "Should call on main thread")
        let callback: StateValueChangeCallback = { (new, old, newState, oldState) in
            guard let new = new as? T,
                  let old = old as? T else {
                return
            }
            if new != old {
                callback(new, old, newState, oldState)
            }
        }
        
        generateObserverId += 1
        let observerId = generateObserverId
        var arrValueObservers = mapValueObservers[keyPath] ?? [StateValueObserver]()
        arrValueObservers.append(StateValueObserver(observerId: observerId, callback: callback))
        mapValueObservers[keyPath] = arrValueObservers
        
        return AnyCancellable { [weak self] in
            if var arrValueObservers = self?.mapValueObservers[keyPath] {
                if let index = arrValueObservers.firstIndex(where: { $0.observerId == observerId}) {
                    arrValueObservers.remove(at: index)
                }
                if arrValueObservers.isEmpty {
                    self?.mapValueObservers.removeValue(forKey: keyPath)
                } else {
                    self?.mapValueObservers[keyPath] = arrValueObservers
                }
            }
        }
    }
    
    /// 观察另一个存储器状态的变化，变化时会调用回调
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter callback: 被观察的存储器状态变化时的回调
    public func observe<S:StorableState>(store: Store<S>, callback: @escaping (_ new: S, _ old: S) -> Void) {
        assert(Thread.isMainThread, "Should call on main thread")
        // 添加循环观察判断
        Self.recordObserve(from: self, to: store)
        let innerCancellable = store.addObserver { new, old in
            callback(new, old)
        }
        let fromId = ObjectIdentifier(self)
        let toId = ObjectIdentifier(store)
        let cancellable = AnyCancellable {
            Self.removeObserve(fromId: fromId, toId: toId)
            innerCancellable.cancel()
        }
        storeObserveCancellable(store: store, cancellable: cancellable, keyPath: \S.self)
    }
    
    /// 观察另一个存储器状态的变化，调用回调会生成对于 Action，并自动应用
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter callback: 被观察的存储器状态变化时的回调
    public func observe<S:StorableState, A:Action>(store: Store<S>, callback: @escaping (_ new: S, _ old: S) -> A?) {
        assert(Thread.isMainThread, "Should call on main thread")
        // 添加循环观察判断
        Self.recordObserve(from: self, to: store)
        let innerCancellable = store.addObserver { [weak self] new, old in
            if let self = self, let action = callback(new, old) {
                self.apply(action: action)
            }
        }
        let fromId = ObjectIdentifier(self)
        let toId = ObjectIdentifier(store)
        let cancellable = AnyCancellable {
            Self.removeObserve(fromId: fromId, toId: toId)
            innerCancellable.cancel()
        }
        storeObserveCancellable(store: store, cancellable: cancellable, keyPath: \S.self)
    }
    
    /// 观察另一个存储器的状态中的某个值，对于值变化时会调用回调
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter keyPath: 被观察对应值的 keyPath
    /// - Parameter callback: 被观察对应值的变化时调用该回调
    public func observe<S:StorableState, T:Equatable>(store: Store<S>, of keyPath: KeyPath<S, T>, callback: @escaping (_ new: T, _ old: T) -> Void) {
        observe(store: store, of: keyPath) { new, old, newState, oldState in
            callback(new, old)
        }
    }
    
    /// 观察另一个存储器的状态中的某个值，对于值变化时会调用回调
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter keyPath: 被观察对应值的 keyPath
    /// - Parameter callback: 被观察对应值的变化时调用该回调
    public func observe<S:StorableState, T:Equatable>(store: Store<S>, of keyPath: KeyPath<S, T>, callback: @escaping (_ new: T, _ old: T, _ newState: S, _ oldState: S) -> Void) {
        assert(Thread.isMainThread, "Should call on main thread")
        let cancellable = store.addObserver(of: keyPath) { new, old, newState, oldState in
            callback(new, old, newState, oldState)
        }
        storeObserveCancellable(store: store, cancellable: cancellable, keyPath: keyPath)
    }
    
    /// 观察另一个存储器的状态中的某个值，调用回调会生成对于 Action，并自动应用
    /// - Warning: 这里需要自行确保生成的 action 不会导致被观察到 store 变化
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter keyPath: 被观察对应值的 keyPath
    /// - Parameter callback: 被观察对应值的变化时调用该回调生成可应用的事件
    public func observe<S:StorableState, T:Equatable, A:Action>(store: Store<S>, of keyPath: KeyPath<S, T>, callback: @escaping (_ new: T, _ old: T) -> A?) {
        observe(store: store, of: keyPath) { (new, old, _, _) -> A? in
            callback(new, old)
        }
    }
    
    /// 观察另一个存储器的状态中的某个值，调用回调会生成对于 Action，并自动应用
    /// - Warning: 这里需要自行确保生成的 action 不会导致被观察到 store 变化
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter keyPath: 被观察对应值的 keyPath
    /// - Parameter callback: 被观察对应值的变化时调用该回调生成可应用的事件
    public func observe<S:StorableState, T:Equatable, A:Action>(store: Store<S>, of keyPath: KeyPath<S, T>, callback: @escaping (_ new: T, _ old: T, _ newState: S, _ oldState: S) -> A?) {
        assert(Thread.isMainThread, "Should call on main thread")
        let cancellable = store.addObserver(of: keyPath) { [weak self] new, old, newState, oldState in
            if let self = self, let action = callback(new, old, newState, oldState) {
                self.apply(action: action)
            }
        }
        storeObserveCancellable(store: store, cancellable: cancellable, keyPath: keyPath)
    }
    
    /// 取消观察另一个存储器的状态所有值
    public func unobserveAll<S>(store: Store<S>) {
        mapCancellable.removeValue(forKey: ObjectIdentifier(store))
    }
    
    /// 取消观察另一个存储器的状态
    public func unobserve<S>(store: Store<S>) {
        unobserve(store: store, of: \S.self)
    }
    
    /// 取消观察另一个存储器的状态对应值
    public func unobserve<S>(store: Store<S>, of keyPath: PartialKeyPath<S>) {
        let key = ObjectIdentifier(store)
        guard var mapKeypathToCancellable = mapCancellable[key] else {
            return
        }
        mapKeypathToCancellable.removeValue(forKey: keyPath)
        if mapKeypathToCancellable.isEmpty {
            mapCancellable.removeValue(forKey: key)
        } else {
            mapCancellable[key] = mapKeypathToCancellable
        }
    }
    
    /// 保存观察另一个存储器的 AnyCancellable
    func storeObserveCancellable<S>(store: Store<S>, cancellable: AnyCancellable, keyPath: PartialKeyPath<S>) {
        let key = ObjectIdentifier(store)
        var mapKeypathToCancellable = mapCancellable[key] ?? [:]
        if mapKeypathToCancellable[keyPath] != nil {
            StoreMonitor.shared.fatalError("Repeat observe from \(self.state.stateId) to \(store.state.stateId) with keyPath: \(keyPath)")
        }
        mapKeypathToCancellable[keyPath] = cancellable
        mapCancellable[key] = mapKeypathToCancellable
    }
    
    /// 记录 from store 观察 to store
    static func recordObserve<FS:StorableState, TS:StorableState>(from: Store<FS>, to: Store<TS>) {
        let fromId = ObjectIdentifier(from)
        let toId = ObjectIdentifier(to)
        if isToObserveFrom(toId: toId, fromId: fromId) {
            StoreMonitor.shared.record(event: .cyclicObserve(from: from, to: to.eraseToAnyStore()))
            StoreMonitor.shared.fatalError("Exist cyclic observe from \(from.state.stateId) to \(to.state.stateId)")
        }
        var arrToObserves = s_mapStateObserve[fromId] ?? []
        arrToObserves.append(toId)
        s_mapStateObserve[fromId] = arrToObserves
    }
    
    static func removeObserve(fromId: ObjectIdentifier, toId: ObjectIdentifier) {
        if var arrToObserves = s_mapStateObserve[fromId], !arrToObserves.isEmpty {
            arrToObserves.removeAll { $0 == toId }
            if arrToObserves.isEmpty {
                s_mapStateObserve.removeValue(forKey: fromId)
            } else {
                s_mapStateObserve[fromId] = arrToObserves
            }
        }
    }
    
    /// 判断 to store 是否反向绑定了 from store
    static func isToObserveFrom(toId: ObjectIdentifier, fromId: ObjectIdentifier) -> Bool {
        guard let arrToObserves = s_mapStateObserve[toId] else {
            return false
        }
        let foundToSubId = arrToObserves.first { toSubId in
            if (toSubId == fromId) {
                return true
            }
            return isToObserveFrom(toId: toSubId, fromId: fromId)
        }
        if foundToSubId != nil {
            return true
        }
        return false
    }
    
    
    // MARK: - Action
    
    /// 界面发送事件，需要在主线程调用（界面过来的基本都是主线程），可以生成新的界面状态
    ///
    /// - Parameter action: 需要执行的事件
    public func send<A:Action>(action : A) {
        assert(Thread.isMainThread, "Should call on main thread")
        reduce(action: action, from: .send)
    }
    
    /// 应用对应事件，主要用于非用户触发的状态间的调用，需要确保在主线程调用
    ///
    /// - Parameter action: 需要应用的事件
    public func apply<A:Action>(action : A) {
        assert(Thread.isMainThread, "Should call on main thread")
        reduce(action: action, from: .apply)
    }
    
    /// 底层事件派发用于更新状态，不需要考虑线程
    ///
    /// - Parameters:
    ///   - action: 派发的对应事件
    ///   - completion: 事件执行完成之后的回调，会在主线程调用
    public func dispatch<A:Action>(action: A, completion: (()->Void)? = nil) {
        DispatchQueue.main.async {
            self.reduce(action: action, from: .dispatch)
            completion?()
        }
    }
    
    // MARK: - Reduce
    
    /// 开始处理事件
    func reduce<A: Action>(action: A, from: ReduceFrom) {
        if let reducingAction = reducingAction {
            StoreMonitor.shared.record(event: .reduceInOtherReduce(self, curAction: action, otherAction: reducingAction))
            pendingActions.insert((action, from), at: 0)
            return
        }
        
        var isChange = false
        var newState = _state {
            didSet {
                isChange = true
            }
        }
        StoreMonitor.shared.record(event: .beforeReduceActionOn(self, from, action))
        
        if let (dependers, reducer) = mapReducer[ObjectIdentifier(A.self)] {
            guard StoreCenter.shared.checkDependency(dependers, newState, action) else {
                return
            }
            reducingAction = action
            reducer(&newState, action)
            reducingAction = nil
        } else {
            StoreMonitor.shared.record(event: .reduceNotRegisterForActionOn(self, from, action))
        }
        StoreMonitor.shared.record(event: .afterReduceActionOn(self, from, action, newState: newState))
        
        if isChange {
            updateStateWithNotify(newState)
        }
        
        if let (nextAction, nextFrom) = pendingActions.popLast() {
            reduce(action: nextAction, from: nextFrom)
        }
    }
    
    // MARK: - Notify Chage
    
    /// 更新状态并通知监听着
    func updateStateWithNotify(_ state: State, on keyPath: AnyKeyPath? = nil) {
        let oldState = _state
        _state = state
        StoreMonitor.shared.record(event: .didUpdateStateOn(self, oldState: oldState))
        if let keyPath = keyPath {
            notifyValueChange(to: _state, oldState, on: keyPath)
        } else {
            notifyChange(to: _state, oldState)
        }
    }
    
    /// 通知所有属性监听着
    func notifyChange(to newState: State, _ oldState: State) {
        for item in mapValueObservers {
            guard let newValue = newState[keyPath: item.key],
                  let oldValue = oldState[keyPath: item.key] else {
                continue
            }
            for observer in item.value {
                observer.run(newValue, oldValue, newState, oldState)
            }
        }
    }
    
    /// 通知指定属性监听着
    func notifyValueChange(to newState: State, _ oldState: State, on keyPath: AnyKeyPath) {
        guard let arrValueObservers = mapValueObservers[keyPath],
              let newValue = newState[keyPath: keyPath],
              let oldValue = oldState[keyPath: keyPath] else {
            return
        }
        for observer in arrValueObservers {
            observer.run(newValue, oldValue, newState, oldState)
        }
    }
    
    
    // MARK: - Destroy
    /// 设置存储器销毁时的回调
    /// - Parameter destroyCallback: 销毁时要调用的回调
    public func setDestroyCallback(_ destroyCallback: @escaping (State) -> Void) {
        self.destroyCallback = destroyCallback
    }
    
    deinit {
        // 这里可能有线程问题
        StoreMonitor.shared.record(event: .destroyStore(self))
        if Thread.isMainThread {
            self.destroyCallback?(self._state)
        } else {
            if let destroyCallback = self.destroyCallback {
                let tmpState = self._state
                DispatchQueue.main.async {
                    destroyCallback(tmpState)
                }
            }
        }
    }
}

// MARK: - StateObserver

/// 状态监听者
struct StateObserver<State:StorableState> {
    let observerId: Int
    let callback: Store<State>.StateChangeCallback
    
    func run(_ newState: State, _ oldState: State) {
        callback(newState, oldState)
    }
}


// MARK: - ======= 扩展方法 =======

// MARK: - StateContainable

/// 可容纳子状态的状态
extension Store where State : StateContainable {
    /// 添加子状态。注：SharableState 会自动调用
    ///
    /// - Parameter subStore: 被添加的子状态
    public func add<SubState: AttachableState>(subStore: Store<SubState>) where SubState.UpState == State {
        assert(Thread.isMainThread, "Should call on main thread")
        self._state.updateSubState(state: subStore.state)
        // 添加当前 store（即 subStore 对应 UpStore）对 subStore 的监听
        self.observe(store: subStore) { [weak self] new, _ in
            self?.state.updateSubState(state: new)
        }
        // subStore 销毁时，需要清空上级 store 保存的状态
        subStore.setDestroyCallback { [weak self] state in
            self?.state.subStates.removeValue(forKey: state.stateId)
        }
    }
}

// MARK: - InitializableState & Init

/// 可直接初始化的状态
extension Store where State : InitializableState {
    /// 可直接初始化的状态，对于存储器也可以直接初始化
    public convenience init() {
        self.init(state: State())
    }
}
