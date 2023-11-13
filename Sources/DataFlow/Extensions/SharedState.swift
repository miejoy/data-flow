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
var s_mapSharedStore : [ObjectIdentifier:Any] = [:]
let s_sharedStoreLock = DispatchQueue(label: "data-flow.shared.lock")

/// 可共享的状态的状态
extension Store where State : SharableState {
    
    /// 私有共享状态存储器创建
    static var _shared : Store<State> {
        let key = ObjectIdentifier(State.self)
        var existOne: Bool = false
        let store: Store<State> = s_sharedStoreLock.sync {
            if let theStore = s_mapSharedStore[key] as? Store<State> {
                existOne = true
                return theStore
            }
            let theStore = self.init()
            s_mapSharedStore[key] = theStore
            return theStore
        }
        if existOne {
            return store
        }
        
        // 判断 upStore 是否添加了当前的状态
        if !(State.UpState.self is Never.Type) {
            let upStore = Store<State.UpState>.shared
            let attachStoreBlock = {
                // state 操作必须在主线程
                if let existState = upStore.subStates[store.state.stateId] {
                    StoreMonitor.shared.fatalError(
                        "Attach State[\(String(describing: State.self))] to UpState[\(String(describing: State.UpState.self))] " +
                        "with stateId[\(store.state.stateId)] failed: " +
                        "exist State[\(String(describing: type(of: existState)))] with same stateId!"
                    )
                }
                upStore.add(subStore: store)
            }
            if Thread.isMainThread {
                attachStoreBlock()
            } else {
                DispatchQueue.main.async {
                    attachStoreBlock()
                }
            }
        }
        return store
    }
    
    /// 共享存储器，所有地方都可共享
    public static var shared : Store<State> {
        return _shared
    }
}
