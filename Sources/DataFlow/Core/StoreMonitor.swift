//
//  StoreMonitor.swift
//  
//
//  Created by 黄磊 on 2022/5/31.
//  Copyright © 2022 Miejoy. All rights reserved.
//  主要用于对 Store 这种状态处理的观察，外部可以通过添加观察者记录数据流中的各种动向

import Foundation
import Combine

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
public final class StoreMonitor: BaseMonitor<StoreEvent> {
    public nonisolated(unsafe) static let shared: StoreMonitor = {
        StoreMonitor { event, observer in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    (observer as? StoreMonitorObserver)?.receiveStoreEvent(event)
                }
            } else {
                Task { @MainActor in
                    (observer as? StoreMonitorObserver)?.receiveStoreEvent(event)
                }
            }
        }
    }()
    
    /// 是否使用严格模式，即所有 state 更新必须通过 send、applay、dispach 方法
    var useStrictMode: Bool = false
    
    public func addObserver(_ observer: StoreMonitorObserver) -> AnyCancellable {
        super.addObserver(observer)
    }
    
    public override func addObserver(_ observer: MonitorObserver) -> AnyCancellable {
        Swift.fatalError("Only StoreMonitorObserver can observer this monitor")
    }
}


// MARK: - MonitorQueue

extension DispatchQueue {
    static let monitorDispatchSpecificKey: DispatchSpecificKey<String> = .init()
    static let monitorLock: DispatchQueue = {
        let queue = DispatchQueue(label: "data-flow.monitor.lock")
        queue.setSpecific(key: monitorDispatchSpecificKey, value: queue.label)
        return queue
    }()
    
    /// 在 monitor 队列中执行
    public static func syncOnMonitorQueue<T>(execute work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.monitorDispatchSpecificKey) == Self.monitorLock.label {
            return try work()
        }
        return try Self.monitorLock.sync(execute: work)
    }
}

// MARK: - BaseMonitor

public protocol MonitorEvent {
    static func fatalError(_ message: String) -> Self
}

public protocol MonitorObserver: AnyObject, Sendable {
}

/// 基础监听器
open class BaseMonitor<Event: MonitorEvent> {
    struct Observer {
        let observerId: Int
        weak var observer: MonitorObserver?
    }
    
    /// 所有观察者
    var arrObservers: [Observer] = []
    var generateObserverId: Int = 0
    var notifyObserver: (Event, MonitorObserver) -> Void

    public required init(notifyObserver: @escaping (Event, MonitorObserver) -> Void) {
        self.notifyObserver = notifyObserver
    }
    
    /// 添加观察者
    public func addObserver(_ observer: MonitorObserver) -> AnyCancellable {
        DispatchQueue.syncOnMonitorQueue {
            generateObserverId += 1
            let observerId = generateObserverId
            arrObservers.append(.init(observerId: generateObserverId, observer: observer))
            return AnyCancellable { [weak self] in
                if let index = self?.arrObservers.firstIndex(where: { $0.observerId == observerId}) {
                    self?.arrObservers.remove(at: index)
                }
            }
        }
    }
    
    /// 记录对应事件，这里只负责将所有事件传递给观察者
    public func record(event: Event) {
        DispatchQueue.syncOnMonitorQueue {
            guard !arrObservers.isEmpty else { return }
            arrObservers.forEach {
                guard let observer = $0.observer else { return }
                self.notifyObserver(event, observer)
            }
        }
    }
    
    public func fatalError(_ message: String) {
        guard !arrObservers.isEmpty else {
            #if DEBUG
            Swift.fatalError(message)
            #else
            return
            #endif
        }
        record(event: .fatalError(message))
    }
}
