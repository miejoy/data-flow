//
//  StoreConfig.swift
//
//
//  Created by 黄磊 on 2025/10/7.
//

import Foundation


/// 初始化配置使用的 Key
public struct StoreConfigKey<Value>: Hashable, CustomStringConvertible {
    let name: String

    /// 初始化配置 key
    public init(_ name: String = "") {
        self.name = name
    }

    public var description: String {
        "\(name)<\(String(describing: Value.self).replacingOccurrences(of: "()", with: "Void"))>"
    }
}

/// 初始化配置对象
public struct StoreConfig {
    let storage: [AnyHashable: Any]
    
    init(_ configPair: [StoreConfigPair]) {
        self.storage = configPair.reduce(into: [AnyHashable: Any]()) { partialResult, pair in
            partialResult[pair.key] = pair.value
        }
    }
    
    func get<Value>(_ key: StoreConfigKey<Value>) -> Value? {
        return self.storage[AnyHashable(key)] as? Value
    }
}

/// 初始化配置对
public struct StoreConfigPair {
    let key: AnyHashable
    let value: Any
    init(key: AnyHashable, value: Any) {
        self.key = key
        self.value = value
    }
    
    
    /// 构造状态存储器初始化配置对
    /// - Parameters:
    ///   - key: 配置 key
    ///   - value: 配置 值
    /// - Returns: 返回创建的配置对
    public static func make<Value>(_ key: StoreConfigKey<Value>, _ value: Value) -> Self {
        return self.init(key: AnyHashable(key), value: value)
    }
}

extension Store {
    /// 读取初始化配置
    public subscript<Value>(_ key: StoreConfigKey<Value>) -> Value? {
        get {
            self.initConfig.get(key)
        }
    }
    
    /// 读取初始化配置，不存在时返回默认值
    public subscript<Value>(_ key: StoreConfigKey<Value>, default defaultValue: @autoclosure () -> Value) -> Value {
        get {
            if let value = self.initConfig.get(key) {
                return value
            }
            return defaultValue()
        }
    }
}
