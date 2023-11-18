//
//  State.swift
//
//
//  Created by 黄磊 on 2020-06-21.
//  Copyright © 2020 Miejoy. All rights reserved.
//  需要存储的状态，值类型，可以包含各种可存储数据

import Foundation

/// 可存储状态协议
public protocol StorableState {
    /// 状态 ID，默认为结构体名称
    var stateId: String { get }
    /// 被装载到 Store 时调用，尽量不要重写他，如果确实要重写，请注意 ReducerLoadableState 相关方法的调用。重新该方法需要自行关注线程问题
    static func didBoxed(on store: Store<some StorableState>)
}

/// 可直接初始化的状态
public protocol InitializableState {
    init()
}

/// 可容纳子状态的
public protocol StateContainable {
    var subStates : [String:StorableState] { get set }
}

/// 可附加于其他状态的状态
public protocol AttachableState: StorableState {
    /// 上一级状态
    associatedtype UpState : StateContainable
}

/// 可自动加载处理器的状态
public protocol ReducerLoadableState : StorableState {
    /// 加载处理器，该方法只会在主线程调用。请不要直接调用，除非自己重写了 didBoxed(on:) 方法，需要调用时也确保在主线程调用
    static func loadReducers(on store: Store<Self>)
}


// MARK: - Extensions

extension StorableState {
    /// 默认 stateId
    public var stateId: String {
        String(describing: Self.self)
    }
    
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
    public static func didBoxed(on store: Store<some StorableState>) {
        if let store = store as? Store<Self> {
            if Thread.isMainThread {
                loadReducers(on: store)
            } else {
                DispatchQueue.main.async {
                    loadReducers(on: store)
                }
            }
        }
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
