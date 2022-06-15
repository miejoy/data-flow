//
//  SharedState.swift
//  
//
//  Created by 黄磊 on 2022/4/23.
//  Copyright © 2022 Miejoy. All rights reserved.
//

import Combine
import SwiftUI

/// 可共享的状态
public protocol StateSharable: StateAttachable, StateInitable where UpState: StateSharable {}
/// 完整的可共享状态
public protocol FullStateSharable: StateSharable, StateReducerLoadable, ActionBindable {}

extension Never: StateSharable {
    public typealias UpState = Never
}


/// 共享状态包装器
@propertyWrapper
public struct SharedState<State: StateSharable> : DynamicProperty {
    
    @ObservedObject private var store: Store<State>
    
    public init() {
        store = .shared
    }
    
    public var wrappedValue: State {
        get {
            store.state
        }
        
        nonmutating set {
            store.state = newValue
        }
    }
    
    public var projectedValue: Store<State> {
        store
    }
}

extension SharedState where State : StateReducerLoadable {
    public init() {
        store = .shared
    }
}

// MARK: - Extension Store

/// 保存所有的共享状态，ObjectIdentifier 为 StateSharable 类型的唯一值
var s_mapSharedStore : [ObjectIdentifier:Any] = [:]

/// 可共享的状态的状态
extension Store where State : StateSharable {
    
    /// 私有共享状态存储器创建
    static var _shared : Store<State> {
        let key = ObjectIdentifier(State.self)
        if let store = s_mapSharedStore[key] as? Store<State> {
            return store
        }
        let store = self.init()
        // 判断 upStore 是否添加了当前的状态
        if !(State.UpState.self is Never.Type) {
            let upStore = Store<State.UpState>.shared
            if let existState = upStore.subStates[store.state.stateId] {
                StoreMonitor.shared.fatalError(
                    "Attach State[\(String(describing: State.self))] to UpState[\(String(describing: State.UpState.self))] " +
                    "with stateId[\(store.state.stateId)] failed: " +
                    "exist State[\(String(describing: type(of: existState)))] with same stateId!"
                )
            }
            upStore.append(subStore: store)
        }
        
        s_mapSharedStore[key] = store
        return store
    }
    
    /// 共享存储器，所有地方都可共享
    public static var shared : Store<State> {
        return _shared
    }
}

/// 可共享和加载处理器的状态
extension Store where State : StateSharable & StateReducerLoadable {
    /// 共享存储器，所有地方都可共享
    public static var shared : Store<State> {
        let store = _shared
        // 放在后面防止循环调用
        State.loadReducers(on: store)
        return store
    }
}
