//
//  StoreCenter.swift
//  
//
//  Created by 黄磊 on 2022/10/1.
//

import Foundation

/// 存储器中心，用于管理 ReduceDepender 的注册和依赖检查
@MainActor
public final class StoreCenter {
    /// 单例实例
    public nonisolated(unsafe) static var shared: StoreCenter = .init()
    
    /// 依赖者映射表，存储所有注册的 ReduceDepender
    var dependerMap: [ReduceDependerId: ReduceDepender] = [:]
    
    nonisolated init() {}
    
    /// 注册 ReduceDepender
    /// - Parameter depender: 需要注册的依赖者
    public func registerReduceDepender<D: ReduceDepender>(_ depender: D) {
        if dependerMap[D.dependerId] != nil {
            StoreMonitor.shared.fatalError("Duplicate registration of reduce depender '\(D.dependerId)'")
        }
        dependerMap[D.dependerId] = depender
    }
    
    /// 检查依赖是否满足
    /// - Parameters:
    ///   - dependers: 需要检查的依赖者 ID 列表
    ///   - state: 当前状态
    ///   - action: 当前事件
    /// - Returns: 如果所有依赖都满足则返回 true，否则返回 false
    func checkDependency(_ dependers: [ReduceDependerId], _ state: StorableState, _ action: Action) -> Bool {
        let dependerNotFulfill = dependers.firstIndex { dependerId in
            guard let depender = dependerMap[dependerId] else {
                StoreMonitor.shared.fatalError("Needed depender '\(dependerId)' not found while reduce state '\(type(of: state))' with action '\(action)'")
                return true
            }
            return !depender.canContinueReduce(state, action)
        }
        return dependerNotFulfill == nil
    }
}
