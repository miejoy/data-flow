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
    public var state: StorableState {
        (store as! StateContainer).innerState
    }

    init<State: StorableState>(store: Store<State>) {
        self.stateType = State.self
        self.store = store
        self.stateId = store[.stateId]
    }
}

// MARK: - Extension Store

extension Store {
    /// 去除存储器指定的状态类型
    public nonisolated func eraseToAny() -> AnyStore {
        AnyStore(store: self)
    }
}

// MARK: - StateContainer

protocol StateContainer: AnyObject, Sendable {
    var innerState: StorableState { get }
    var subContainers: [StateContainer] { get }
}

// MARK: - Store: StateContainer

extension Store: StateContainer {
    nonisolated var innerState: StorableState {
        _stateLock.withLock { $0 }
    }

    nonisolated var subContainers: [StateContainer] {
        guard let subStores: [String: WeakStore] = self[.subStores] else { return [] }
        return subStores
            .sorted { $0.key < $1.key }
            .compactMap { $0.value.store }
    }
}

// MARK: - WeakStore

/// 弱引用持有底层 Store，销毁后自动置 nil
struct WeakStore: Sendable {
    weak var store: StateContainer?

    init(_ store: StateContainer) {
        self.store = store
    }
}
