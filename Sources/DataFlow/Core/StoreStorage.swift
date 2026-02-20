//
//  StoreStorage.swift
//
//
//  Created by 黄磊 on 2024/11/8.
//  通用存储器内部使用的存储空间

import Foundation

/// 存储空间使用的 Key
public struct StoreStorageKey<Value>: Sendable {
    let name: String
    public init(_ name: String, _ fileId: String = #fileID, _ line: Int = #line) {
        self.name = "\(name)-\(fileId):\(line)"
    }
}

public struct DefaultStoreStorageKey<Value>: @unchecked Sendable {
    let name: String
    let defaultValue: Value
    public init(_ name: String, _ defaultValue: Value, _ fileId: String = #fileID, _ line: Int = #line) {
        self.name = "\(name)-\(fileId):\(line)"
        self.defaultValue = defaultValue
    }
}

/// 存储器内部使用的存储空间，受 DispatchQueue 的 StoreLock 锁保护
final class StoreStorage {
    
    init() {}
    
    var storage: [String: Any] = [:]
    
    func get<Value>(_ key: StoreStorageKey<Value>) -> Value? {
        DispatchQueue.syncOnStoreQueue {
            return self.storage[key.name] as? Value
        }
    }
    
    func get<Value>(_ key: DefaultStoreStorageKey<Value>) -> Value {
        DispatchQueue.syncOnStoreQueue {
            if let value = self.storage[key.name] as? Value {
                return value
            }
            let defaultValue = key.defaultValue
            set(key, to: defaultValue)
            return defaultValue
        }
    }

    func set<Value>(_ key: StoreStorageKey<Value>, to value: Value?) {
        DispatchQueue.syncOnStoreQueue {
            if let value = value {
                self.storage[key.name] = value
            } else if self.storage[key.name] != nil {
                self.storage.removeValue(forKey: key.name)
            }
        }
    }
    
    func set<Value>(_ key: DefaultStoreStorageKey<Value>, to value: Value?) {
        DispatchQueue.syncOnStoreQueue {
            if let value = value {
                self.storage[key.name] = value
            } else if self.storage[key.name] != nil {
                self.storage.removeValue(forKey: key.name)
            }
        }
    }
}

extension Store {
    /// 读取和写入传入 key 中定义的存储值
    public nonisolated subscript<Value>(_ key: StoreStorageKey<Value>) -> Value? {
        get {
            self.storage.get(key)
        }
        set {
            self.storage.set(key, to: newValue)
        }
    }
    
    /// 读取和写入传入含默认值 key 中定义的存储值
    public nonisolated subscript<Value>(_ key: DefaultStoreStorageKey<Value>) -> Value? {
        get {
            self.storage.get(key)
        }
        set {
            self.storage.set(key, to: newValue)
        }
    }
    
    /// 读取传入 Key 中定义的存储值，不存在时返回默认值
    public nonisolated subscript<Value>(_ key: StoreStorageKey<Value>, default defaultValue: @autoclosure () -> Value) -> Value {
        get {
            if let value = self.storage.get(key) {
                return value
            }
            let defaultValue = defaultValue()
            self.storage.set(key, to: defaultValue)
            return defaultValue
        }
    }
    
    /// 读取传入 Key 中定义的存储值，不存在时返回 Key 中定义的默认值
    public nonisolated subscript<Value>(_ key: DefaultStoreStorageKey<Value>) -> Value {
        get {
            self.storage.get(key)
        }
    }
}


// MARK: - Keys

extension DefaultStoreStorageKey where Value == String {
    public static let stateId: Self = .init("stateId", "")
}
