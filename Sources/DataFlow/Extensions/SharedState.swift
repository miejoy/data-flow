//
//  SharedState.swift
//  
//
//  Created by 黄磊 on 2022/4/23.
//  Copyright © 2022 Miejoy. All rights reserved.
//

import Combine
import Foundation

/// 可共享的状态
public protocol SharableState: AttachableState, InitializableState where UpState: SharableState {
    associatedtype UpState = AppState
}
/// 完整的可共享状态
public protocol FullSharableState: SharableState, ReducerLoadableState, ActionBindable {}

extension Never: SharableState {
    public typealias UpState = Never
}

// MARK: - Extension Store

/// 保存所有的共享状态，ObjectIdentifier 为 SharableState 类型的唯一值
/// 使用 nonisolated(unsafe) 配合 DispatchQueue 锁保护，支持任意线程安全访问
nonisolated(unsafe) var s_mapSharedStore : [ObjectIdentifier:Any] = [:]

/// 可共享的状态的状态
extension Store where State : SharableState {
    
    /// 将新创建的 store 附加到 upStore（需要在 MainActor 上调用）
    @MainActor private static func attachToUpStore(_ store: Store<State>) {
        guard !(State.UpState.self is Never.Type) else { return }
        let upStore = Store<State.UpState>.shared
        if let existState = upStore.subStates[store.state.stateId] {
            StoreMonitor.shared.fatalError(
                "Attach State[\(String(describing: State.self))] to UpState[\(String(describing: State.UpState.self))] " +
                "with stateId[\(store.state.stateId)] failed: " +
                "exist State[\(String(describing: type(of: existState)))] with same stateId!"
            )
        }
        upStore.add(subStore: store)
    }
    
    /// 私有共享状态存储器创建，支持从任意线程调用
    /// 使用 DispatchQueue 锁保护 s_mapSharedStore 的读写，确保线程安全
    static nonisolated var _shared : Store<State> {
        let key = ObjectIdentifier(State.self)
        nonisolated(unsafe) var isNew: Bool = false
        let store: Store<State> = DispatchQueue.syncOnStoreQueue {
            if let theStore = s_mapSharedStore[key] as? Store<State> {
                return theStore
            }
            let theStore = self.init(state: State())
            s_mapSharedStore[key] = theStore
            isNew = true
            return theStore
        }
        
        guard isNew else { return store }
        
        // 将 upStore 附加逻辑调度到 MainActor 执行
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                attachToUpStore(store)
            }
        } else {
            Task { @MainActor in
                attachToUpStore(store)
            }
        }
        return store
    }
    
    /// 共享存储器，所有地方都可共享
    public nonisolated static var shared : Store<State> {
        return _shared
    }
}

// MARK: - Extension SharableState

extension SharableState {
    /// 共享存储器，所有地方都可共享
    public static var sharedStore: Store<Self> {
        Store<Self>.shared
    }
}

// MARK: - DispatchQueue

extension DispatchQueue {
    
    static let checkDispatchSpecificKey: DispatchSpecificKey<String> = .init()
    /// 共享 store 创建时使用的锁，目前没有移除共享 store 的方式，后面开发时移除共享 store 必须在主线程，并包上这个锁
    static let sharedStoreLock: DispatchQueue = {
        let queue = DispatchQueue(label: "data-flow.shared.lock")
        queue.setSpecific(key: checkDispatchSpecificKey, value: queue.label)
        return queue
    }()
    
    /// 检查是否允许在当前 queue 上，并同步执行代码
    public static func syncOnStoreQueue<T>(execute work: @Sendable () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.checkDispatchSpecificKey) == Self.sharedStoreLock.label {
            return try work()
        }
        return try Self.sharedStoreLock.sync(execute: work)
    }
}
