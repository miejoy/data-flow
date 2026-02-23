//
//  State.swift
//
//
//  Created by 黄磊 on 2020-06-21.
//  Copyright © 2020 Miejoy. All rights reserved.
//  需要存储的状态，值类型，可以包含各种可存储数据

import Foundation

/// 可存储状态协议
public protocol StorableState: Sendable {
    /// 状态 ID，默认为结构体名称
    var stateId: String { get }
    /// 使用对应 state 装配 store，主要是在非隔离环境将 state 的部分值缓存到 store 中，方便在非隔离环境使用，尽量缓存不会变化的值。
    /// 该方法只在 store 初始化时调用，其他地方不要调用，该方法会在 didBoxed 之前调用
    /// 这里使用 some StorableState 而不是用 Self 的原因是，如果使用 Self，其他地方在使用 StorableState 时，必须用 any StorableState，且在传入时必须明确类型
    static func assembly(store: Store<some StorableState>, with state: some StorableState)
    /// 被装载到 Store 时调用，尽量不要重写他，如果确实要重写，请注意 ReducerLoadableState 相关方法的调用
    /// 该方法只在 store 初始化时调用，其他地方不要调用
    @MainActor
    static func didBoxed(on store: Store<some StorableState>)
}

/// 可直接初始化的状态
public protocol InitializableState {
    init()
}

/// 使用的可直接初始化的状态，这里与 InitializableState 唯一区别就是 UseInitializableState 会提供一个对应 Store 的 init 方法
public protocol UseInitializableState: InitializableState {}

/// 可容纳子状态的
public protocol StateContainable: Sendable {
    var subStates : [String: StorableState] { get set }
}

/// 可附加于其他状态的状态
public protocol AttachableState: StorableState {
    /// 上一级状态
    associatedtype UpState : StateContainable
}

/// 可自动加载处理器的状态
public protocol ReducerLoadableState : StorableState {
    /// 加载处理器，该方法只会在主线程调用。请不要直接调用，除非自己重写了 didBoxed(on:) 方法
    @MainActor static func loadReducers(on store: Store<Self>)
}


// MARK: - Extensions

extension StorableState {
    /// 默认 stateId
    public var stateId: String {
        String(describing: Self.self)
    }
    
    public static func assembly(store: Store<some StorableState>, with state: some StorableState) {
    }
    
    @MainActor
    public static func didBoxed(on store: Store<some StorableState>) {
    }
}


extension StateContainable {
    /// 更新子状态
    public mutating func updateSubState<State: AttachableState>(state: State) where State.UpState == Self {
        subStates[state.stateId] = state
    }    
}

extension ReducerLoadableState {
    @MainActor
    public static func didBoxed(on store: Store<some StorableState>) {
        guard let store = store as? Store<Self> else { return }
        loadReducers(on: store)
    }
}


// MARK: - Extension Never

/// 定义 上级状态终点，App 中所有状态的上级状态可设置成 AppState
extension Never : StorableState {
    public init() { fatalError("Never can not init") }
}

extension Never : StateContainable {
    public var subStates: [String : StorableState] {
        get { fatalError("Never can not get subStates") }
        set { fatalError("Never can not set subStates") }
    }
}
