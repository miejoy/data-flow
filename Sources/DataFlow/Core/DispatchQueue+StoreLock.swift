//
//  DispatchQueue+StoreLock.swift
//  data-flow
//
//  Created by 黄磊 on 2026/2/14.
//

import Dispatch

// MARK: - DispatchQueue

extension DispatchQueue {
    
    static let checkStoreDispatchSpecificKey: DispatchSpecificKey<String> = .init()
    /// 共享 store 创建时使用的锁，目前没有移除共享 store 的方式，后面开发时移除共享 store 必须在主线程，并包上这个锁
    static let storeLock: DispatchQueue = {
        let queue = DispatchQueue(label: "data-flow.store.lock")
        queue.setSpecific(key: checkStoreDispatchSpecificKey, value: queue.label)
        return queue
    }()
    
    /// 检查是否允许在当前 queue 上，并同步执行代码
    public static func syncOnStoreQueue<T>(execute work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.checkStoreDispatchSpecificKey) == Self.storeLock.label {
            return try work()
        }
        return try Self.storeLock.sync(execute: work)
    }
}
