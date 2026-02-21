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

/// 存储空间使用的带默认值的 Key
public struct DefaultStoreStorageKey<Value>: @unchecked Sendable {
    let name: String
    // 这里必须每次都通过 block 构造一个，避免不同 store 使用相同默认值实例
    let defaultValue: () -> Value
    public init(_ name: String, _ defaultValue: @autoclosure @escaping () -> Value, _ fileId: String = #fileID, _ line: Int = #line) {
        self.name = "\(name)-\(fileId):\(line)"
        self.defaultValue = defaultValue
    }
}

/// 对应状态存储空间使用的 Key
public struct StateOnStoreStorageKey<Value, State: StorableState>: Sendable {
    let name: String
    public init(_ name: String, _ fileId: String = #fileID, _ line: Int = #line) {
        self.name = "\(name)-\(fileId):\(line)"
    }
}

/// 对应状态存储空间使用的带默认值的 Key
public struct DefaultStateOnStoreStorageKey<Value, State: StorableState>: @unchecked Sendable {
    let name: String
    // 这里必须每次都通过 block 构造一个，避免不同 store 使用相同默认值实例
    let defaultValue: () -> Value
    public init(_ name: String, _ defaultValue: @autoclosure @escaping () -> Value, _ fileId: String = #fileID, _ line: Int = #line) {
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
            let defaultValue = key.defaultValue()
            set(key, to: defaultValue)
            return defaultValue
        }
    }
    
    func get<Value, State: StorableState>(_ key: StateOnStoreStorageKey<Value, State>) -> Value? {
        DispatchQueue.syncOnStoreQueue {
            return self.storage[key.name] as? Value
        }
    }
    
    func get<Value, State: StorableState>(_ key: DefaultStateOnStoreStorageKey<Value, State>) -> Value {
        DispatchQueue.syncOnStoreQueue {
            if let value = self.storage[key.name] as? Value {
                return value
            }
            let defaultValue = key.defaultValue()
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
    
    func set<Value, State: StorableState>(_ key: StateOnStoreStorageKey<Value, State>, to value: Value?) {
        DispatchQueue.syncOnStoreQueue {
            if let value = value {
                self.storage[key.name] = value
            } else if self.storage[key.name] != nil {
                self.storage.removeValue(forKey: key.name)
            }
        }
    }
    
    func set<Value, State: StorableState>(_ key: DefaultStateOnStoreStorageKey<Value, State>, to value: Value?) {
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
    
    /// 读取和写入传入 key 中定义的存储值
    public nonisolated subscript<Value>(_ key: StateOnStoreStorageKey<Value, State>) -> Value? {
        get {
            self.storage.get(key)
        }
        set {
            self.storage.set(key, to: newValue)
        }
    }
    
    /// 读取和写入传入含默认值 key 中定义的存储值
    public nonisolated subscript<Value>(_ key: DefaultStateOnStoreStorageKey<Value, State>) -> Value? {
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
    
    /// 读取传入 Key 中定义的存储值，不存在时返回默认值
    public nonisolated subscript<Value>(
        _ key: StateOnStoreStorageKey<Value, State>,
        default defaultValue: @autoclosure () -> Value
    ) -> Value {
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
    public nonisolated subscript<Value>(_ key: DefaultStateOnStoreStorageKey<Value, State>) -> Value {
        get {
            self.storage.get(key)
        }
    }
}


// MARK: - Keys

extension DefaultStoreStorageKey where Value == String {
    public static let stateId: Self = .init("stateId", "")
}
