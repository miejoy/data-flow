//
//  StoreMonitor.swift
//  
//
//  Created by 黄磊 on 2022/5/31.
//  Copyright © 2022 Miejoy. All rights reserved.
//  主要用于对 Store 这种状态处理的观察，外部可以通过添加观察者记录数据流中的各种动向

import Foundation
import Combine
import ModuleMonitor

/// 存储器变化事件
public enum StoreEvent: @unchecked Sendable, MonitorEvent {
    case createStore(AnyStore)
    case beforeReduceActionOn(AnyStore, ReduceActionFrom, _ action: Action)
    case afterReduceActionOn(AnyStore, ReduceActionFrom, _ action: Action, newState: StorableState)
    case reduceNotRegisterForActionOn(AnyStore, ReduceActionFrom, _ action: Action)
    case willDirectUpdateStateOn(AnyStore, _ newState: StorableState)
    case willDirectUpdateStateValueOn(AnyStore, _ keyPath: AnyKeyPath, _ newValue: Any)
    case didUpdateStateOn(AnyStore, oldState: StorableState)
    /// 在处理当前事件时，发现正在进行另一个事件处理
    case reduceInOtherReduce(AnyStore, curAction: Action, otherAction: Action)
    case cyclicObserve(from: AnyStore, to: AnyStore)
    case destroyStore(AnyStore)
    case fatalError(String)
}

/// 存储器变化观察者
public protocol StoreMonitorObserver: MonitorObserver {
    @MainActor
    func receiveStoreEvent(_ event: StoreEvent)
}

/// 存储器监听器
public final class StoreMonitor: ModuleMonitor<StoreEvent> {
    public nonisolated(unsafe) static let shared: StoreMonitor = {
        StoreMonitor { event, observer in
            DispatchQueue.executeOnMain {
                (observer as? StoreMonitorObserver)?.receiveStoreEvent(event)
            }
        }
    }()
    
    /// 是否使用严格模式，即所有 state 更新必须通过 send、apply、dispatch 方法
    var useStrictMode: Bool = false
    
    public func addObserver(_ observer: StoreMonitorObserver) -> AnyCancellable {
        super.addObserver(observer)
    }
    
    public override func addObserver(_ observer: MonitorObserver) -> AnyCancellable {
        Swift.fatalError("Only StoreMonitorObserver can observer this monitor")
    }
}
