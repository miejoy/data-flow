//
//  ReduceDepender.swift
//  
//
//  Created by 黄磊 on 2022/10/1.
//

import Foundation

/// 处理过程依赖者Id
public struct ReduceDependerId: Hashable, ExpressibleByStringLiteral, CustomStringConvertible, Sendable {
    var dependerId: String
    public init(stringLiteral value: String) {
        self.dependerId = value
    }
    
    public var description: String {
        dependerId
    }
}

/// 处理过程依赖者
public protocol ReduceDepender: AnyObject {
    /// 依赖者ID
    static var dependerId: ReduceDependerId { get }
    /// 判断是否可以继续处理对应事件
    func canContinueReduce(_ state: StorableState, _ action: Action) -> Bool
}

extension ReduceDepender {
    /// 依赖者ID，默认使用类名
    public static var dependerId: ReduceDependerId {
        .init(stringLiteral: String(describing: Self.self))
    }
}


