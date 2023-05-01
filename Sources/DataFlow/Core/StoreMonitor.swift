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
public enum StoreEvent<State: StorableState> {
    case createStore(Store<State>)
    case beforeReduceActionOn(Store<State>, Store<State>.ReduceFrom, _ action: Action)
    case afterReduceActionOn(Store<State>, Store<State>.ReduceFrom, _ action: Action, newState: State)
    case reduceNotRegisterForActionOn(Store<State>, Store<State>.ReduceFrom, _ action: Action)
    case willDirectUpdateStateOn(Store<State>, _ newState: State)
    case willDirectUpdateStateValueOn(Store<State>, _ keyPath: PartialKeyPath<State>, _ newValue: Any)
    case didUpdateStateOn(Store<State>, oldState: State)
    /// 在处理当前事件时，发现正在进行另一个事件处理
    case reduceInOtherReduce(Store<State>, curAction: Action, otherAction: Action)
    case cyclicObserve(from: Store<State>, to: AnyStore)
    case destoryStore(Store<State>)
    case fatalError(String)
}

/// 存储器变化观察者
public protocol StoreMonitorOberver: AnyObject {
    func receiveStoreEvent<State:StorableState>(_ event: StoreEvent<State>)
}

/// 存储器监听器
public final class StoreMonitor {
        
    struct Observer {
        let observerId: Int
        weak var observer: StoreMonitorOberver?
    }
    
    /// 监听器共享单例
    public static var shared: StoreMonitor = .init()
    
    /// 所有观察者
    var arrObservers: [Observer] = []
    var generateObserverId: Int = 0
    /// 是否使用严格模式，即所有 state 更新必须通过 send、applay、dispach 方法
    var useStrictMode: Bool = false
    
    required init() {
    }
    
    /// 添加观察者
    public func addObserver(_ observer: StoreMonitorOberver) -> AnyCancellable {
        generateObserverId += 1
        let observerId = generateObserverId
        arrObservers.append(.init(observerId: generateObserverId, observer: observer))
        return AnyCancellable { [weak self] in
            if let index = self?.arrObservers.firstIndex(where: { $0.observerId == observerId}) {
                self?.arrObservers.remove(at: index)
            }
        }
    }
    
    /// 记录对应事件，这里只负责将所有事件传递给观察者
    @usableFromInline
    func record<State:StorableState>(event: StoreEvent<State>) {
        guard !arrObservers.isEmpty else { return }
        arrObservers.forEach { $0.observer?.receiveStoreEvent(event) }
    }
    
    @usableFromInline
    func fatalError(_ message: String) {
        guard !arrObservers.isEmpty else {
            #if DEBUG
            Swift.fatalError(message)
            #else
            return
            #endif
        }
        let event = StoreEvent<Never>.fatalError(message)
        arrObservers.forEach { $0.observer?.receiveStoreEvent(event) }
    }
}
