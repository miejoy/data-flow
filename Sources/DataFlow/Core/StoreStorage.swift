//
//  StoreStorage.swift
//
//
//  Created by 黄磊 on 2024/11/8.
//  通用存储器内部使用的存储空间

import Foundation

/// 存储空间使用的 Key
public protocol StoreStorageKey {
    /// 存储值的类型
    associatedtype Value
}

/// 有默认值的存储空间使用的 Key
public protocol DefaultStoreStorageKey: StoreStorageKey where Value == DefaultValue {
    associatedtype DefaultValue
    static var defaultValue: DefaultValue { get }
}

/// 存储器内部使用的存储空间
final class StoreStorage {
    var storage: [ObjectIdentifier: Any] = [:]
    
    func get<Key: StoreStorageKey>(_ key: Key.Type) -> Key.Value? {
        return self.storage[ObjectIdentifier(Key.self)] as? Key.Value
    }
    
    func get<Key: DefaultStoreStorageKey>(_ key: Key.Type) -> Key.Value {
        let key = ObjectIdentifier(Key.self)
        if let value = self.storage[key] as? Key.Value {
            return value
        }
        let defaultValue = Key.defaultValue
        set(Key.self, to: defaultValue)
        return defaultValue
    }

    func set<Key: StoreStorageKey>(_ key: Key.Type, to value: Key.Value?) {
        let key = ObjectIdentifier(Key.self)
        if let value = value {
            self.storage[key] = value
        } else if self.storage[key] != nil {
            self.storage.removeValue(forKey: key)
        }
    }
}

extension Store {
    /// 读取和写入传入 Key 中定义的存储值
    public subscript<Key: StoreStorageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            self.storage.get(Key.self)
        }
        set {
            self.storage.set(Key.self, to: newValue)
        }
    }
    
    /// 读取传入 Key 中定义的存储值，不存在时返回默认值
    public subscript<Key: StoreStorageKey>(_ key: Key.Type, default defaultValue: @autoclosure () -> Key.Value) -> Key.Value {
        get {
            if let value = self.storage.get(Key.self) {
                return value
            }
            let defaultValue = defaultValue()
            self.storage.set(Key.self, to: defaultValue)
            return defaultValue
        }
    }
    
    /// 读取传入 Key 中定义的存储值，不存在时返回 Key 中定义的默认值
    public subscript<Key: DefaultStoreStorageKey>(_ key: Key.Type) -> Key.Value {
        get {
            self.storage.get(Key.self)
        }
    }
}
