//
//  Action.swift
//
//
//  Created by 黄磊 on 2020-06-21.
//  Copyright © 2020 Miejoy. All rights reserved.
//  事件，一般用枚举。具有唯一性和可处理行

import Foundation

/// 通用事件协议
public protocol Action {
}

/// 可绑定事件的
public protocol ActionBindable {
    associatedtype BindAction : Action
}


// MARK: - Extension Store

/// 可绑定默认事件的状态
extension Store where State : ActionBindable {
    
    // MARK: - Register
    
    /// 注册状态处理方法
    ///
    /// - Parameter reducer: 注册的处理方法
    public func registerDefault(dependers: [ReduceDependerId] = [], reducer: @escaping Reducer<State, State.BindAction>) {
        self.mapReducer[ObjectIdentifier(State.BindAction.self)] = (dependers, { state, action in
            if let specificAction = action as? State.BindAction {
                reducer(&state, specificAction)
            }
        })
    }
    
    // MARK: - Observe
    
    /// 观察另一个存储器的状态中的某个值，调用回调会生成对于 Action，并自动应用
    /// - Warning: 这里需要自行确保生成的 action 不会导致被观察到 store 变化
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter keyPath: 被观察对应值的 keyPath
    /// - Parameter callback: 被观察对应值的变化时调用该回调生成可应用的事件
    public func observeDefault<S:StorableState, T:Equatable>(store: Store<S>, of keyPath: KeyPath<S, T>, callback: @escaping (_ new: T, _ old: T) -> State.BindAction) {
        store.addObserver(of: keyPath) { [weak self] new, old in
            let action = callback(new, old)
            self?.apply(action: action)
        }
        .store(in: &setCancellable)
    }
    
    /// 观察另一个存储器状态的变化，调用回调会生成对于 Action，并自动应用
    ///
    /// - Parameter store: 被观察的存储器
    /// - Parameter callback: 被观察的存储器状态变化时的回调
    public func observeDefault<S:StorableState>(store: Store<S>, callback: @escaping (_ new: S, _ old: S) -> State.BindAction) {
        // 添加循环观察判断
        Self.recordObserve(from: self, to: store)
        store.addObserver { [weak self] new, old in
            let action = callback(new, old)
            self?.apply(action: action)
        }
        .store(in: &setCancellable)
    }
    
    // MARK: - Action
    
    /// 界面发送事件，需要在主线程调用（界面过来的基本都是主线程），可以生成新的界面状态
    ///
    /// - Parameter action: 需要执行的事件
    public func send<A>(action : A) where State.BindAction == A {
        reduce(action: action, from: .send)
    }
    
    /// 应用对应事件，主要用于非用户触发的状态间的调用，需要确保在主线程调用
    ///
    /// - Parameter action: 需要应用的事件
    public func apply<A>(action : A) where State.BindAction == A {
        reduce(action: action, from: .apply)
    }
    
    /// 底层事件派发用于更新状态，不需要考虑线程
    ///
    /// - Parameters:
    ///   - action: 派发的对应事件
    ///   - completion: 事件执行完成之后的回调，会在主线程调用
    public func dispatch<A>(action: A, completion:(()->Void)? = nil) where State.BindAction == A  {
        DispatchQueue.main.async {
            self.reduce(action: action, from: .dispatch)
            completion?()
        }
    }
}
