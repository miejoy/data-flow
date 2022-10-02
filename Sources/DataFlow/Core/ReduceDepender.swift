//
//  ReduceDepender.swift
//  
//
//  Created by 黄磊 on 2022/10/1.
//

import Foundation

public struct ReduceDependerId: Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
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
    func canReduce(_ state: StorableState, _ action: Action) -> Bool
}

extension ReduceDepender {
    public static var dependerId: ReduceDependerId {
        .init(stringLiteral: String(describing: Self.self))
    }
}


