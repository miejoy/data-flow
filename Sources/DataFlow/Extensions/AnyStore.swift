//
//  AnyStore.swift
//
//
//  Created by 黄磊 on 2022/5/4.
//  Copyright © 2022 Miejoy. All rights reserved.
//

import Foundation

/// 被抹去 State 类型的存储器
public final class AnyStore {
    public var stateType: StorableState.Type
    public var value : Any
    public var stateId : String
    
    init<State: StorableState>(store: Store<State>) {
        self.stateType = State.self
        self.value = store
        self.stateId = store.stateId
    }
}

// MARK: - Extension Store

extension Store {
    /// 去除存储器指定的状态类型
    public func eraseToAnyStore() -> AnyStore {
        AnyStore(store: self)
    }
}
