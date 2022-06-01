//
//  StoreMonitor.swift
//  
//
//  Created by 黄磊 on 2022/5/31.
//  主要用于对 Store 这种状态处理的观察，外部可以通过添加观察者记录数据流中的各种动向

import Foundation
import Combine

/// 存储器变化事件
public enum StoreEvent<State: StateStorable> {
    case createStore(Store<State>)
    case beforeReduceActionOn(Store<State>, Store<State>.ReduceFrom)
    case afterReduceActionOn(Store<State>, Store<State>.ReduceFrom, newState: State)
    case failedReduceActionOn(Store<State>, Store<State>.ReduceFrom)
    case didUpdateStateOn(Store<State>, oldState: State)
    case cyclicObserve(from: Store<State>, to: AnyStore)
    case destoryStore(Store<State>)
}

/// 存储器变化观察者
public protocol StoreMonitorOberver: AnyObject {
    func receiveStoreEvent<State:StateStorable>(_ event: StoreEvent<State>)
}

/// 存储器监听器
public final class StoreMonitor {
        
    struct Observer {
        let observerId: Int
        weak var delegate: StoreMonitorOberver?
    }
    
    /// 监听器共享单例
    public static var shared: StoreMonitor = .init()
    
    /// 所有观察者
    var arrObservers: [Observer] = []
    var generateObserverId: Int = 0
    /// 是否使用严格模式，即所有 state 更新必须通过 send、applay、dispach 方法
    var useStrictMode: Bool = false
    /// 是否可以直接抛 fatalError
    var canThrowFatalError = true
    
    required init() {
    }
    
    /// 添加观察者
    public func addObserver(_ observer: StoreMonitorOberver) -> AnyCancellable {
        generateObserverId += 1
        let observerId = generateObserverId
        arrObservers.append(.init(observerId: generateObserverId, delegate: observer))
        return AnyCancellable { [weak self] in
            if let index = self?.arrObservers.firstIndex(where: { $0.observerId == observerId}) {
                self?.arrObservers.remove(at: index)
            }
        }
    }
    
    /// 记录对应事件，这里只负责将所有事件传递给观察者
    func record<State:StateStorable>(event: StoreEvent<State>) {
        guard !arrObservers.isEmpty else { return }
        arrObservers.forEach { $0.delegate?.receiveStoreEvent(event) }
    }
}
