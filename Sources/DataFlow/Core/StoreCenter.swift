//
//  StoreCenter.swift
//  
//
//  Created by 黄磊 on 2022/10/1.
//

import Foundation

public final class StoreCenter {
    public static var shared: StoreCenter = .init()
    
    var dependerMap: [ReduceDependerId: ReduceDepender] = [:]
    
    public func registeReduceDepender<D: ReduceDepender>(_ depender: D) {
        assert(Thread.isMainThread, "Should call on main thread")
        if dependerMap[D.dependerId] != nil {
            StoreMonitor.shared.fatalError("Duplicate registration of reduce depender '\(D.dependerId)'")
        }
        dependerMap[D.dependerId] = depender
    }
    
    func checkDependency(_ dependers: [ReduceDependerId], _ state: StorableState, _ action: Action) -> Bool {
        let dependerNotFulfill = dependers.firstIndex { dependerId in
            guard let depender = dependerMap[dependerId] else {
                StoreMonitor.shared.fatalError("Needed depender '\(dependerId)' node while reduce state '\(type(of: state))' with action '\(action)'")
                return true
            }
            return !depender.canContinueReduce(state, action)
        }
        return dependerNotFulfill == nil
    }
}
