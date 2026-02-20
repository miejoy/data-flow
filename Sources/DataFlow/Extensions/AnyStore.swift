//
//  AnyStore.swift
//
//
//  Created by 黄磊 on 2022/5/4.
//  Copyright © 2022 Miejoy. All rights reserved.
//

import Foundation

/// 被抹去 State 类型的存储器
public struct AnyStore: Sendable {
    public let stateType: StorableState.Type
    public let store : Sendable
    public let stateId : String
    @MainActor
    public var state: StorableState {
        (store as! StateContainer).innerState
    }
    
    init<State: StorableState>(store: Store<State>) {
        self.stateType = State.self
        self.store = store
        self.stateId = store[.stateId]
    }
}

protocol StateContainer: Sendable {
    @MainActor
    var innerState: StorableState { get }
}

// MARK: - Extension Store

extension Store {
    /// 去除存储器指定的状态类型
    public func eraseToAny() -> AnyStore {
        AnyStore(store: self)
    }
}

extension Store: StateContainer {
    public var innerState: StorableState {
        state
    }
}
