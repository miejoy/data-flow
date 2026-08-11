//
//  StoreDebug.swift
//
//  Store 调试相关：dumpState（JSON 状态树）+ CustomReflectable（LLDB/Xcode 调试器）
//

import Foundation

// MARK: - DumpState

extension StateContainer {
    /// 转储当前状态及所有子状态，返回 JSON 格式的树形字符串
    ///
    /// - Parameter indent: 当前对象闭合 `}` 的缩进层级
    /// - Returns: JSON 格式的状态树（`{` 无前缀，跟随调用方 key 行）
    nonisolated func dumpState(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        let childPrefix = String(repeating: "  ", count: indent + 1)

        let mirror = Mirror(reflecting: innerState)
        var entries: [String] = []

        for child in mirror.children {
            guard let label = child.label else { continue }
            entries.append("\(childPrefix)\"\(label)\": \(Self.formatValue(child.value, indent: indent + 1))")
        }

        let subs = subContainers
        if !subs.isEmpty {
            let subIndent = indent + 2
            let subPrefix = String(repeating: "  ", count: subIndent)
            let subEntries = subs.map { sub -> String in
                "\(subPrefix)\"\(sub.innerState.stateId)\": \(sub.dumpState(indent: subIndent))"
            }
            entries.append("\(childPrefix)\"subStates\": {\n" + subEntries.joined(separator: ",\n") + "\n\(childPrefix)}")
        }

        return "{\n" + entries.joined(separator: ",\n") + "\n\(prefix)}"
    }

    /// 将任意值格式化为 JSON 片段
    nonisolated static func formatValue(_ value: Any, indent: Int) -> String {
        let mirror = Mirror(reflecting: value)

        // Optional
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first, child.label == "some" {
                return formatValue(child.value, indent: indent)
            }
            return "null"
        }

        // Struct/Class -> 嵌套对象
        if let style = mirror.displayStyle, (style == .struct || style == .class), !mirror.children.isEmpty {
            let prefix = String(repeating: "  ", count: indent)
            let childIndent = indent + 1
            let childPrefix = String(repeating: "  ", count: childIndent)
            let entries = mirror.children.compactMap { child -> String? in
                guard let label = child.label else { return nil }
                return "\(childPrefix)\"\(label)\": \(formatValue(child.value, indent: childIndent))"
            }
            return "{\n" + entries.joined(separator: ",\n") + "\n\(prefix)}"
        }

        // 基本类型
        if let string = value as? String {
            return "\"\(string)\""
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        return String(describing: value)
    }
}

// MARK: - Store DumpState

extension Store {
    /// 转储当前 Store 的状态及所有子 Store 的状态，返回 JSON 格式的树形字符串
    ///
    /// - Parameter indent: 缩进层级，外部调用时使用默认值 0
    /// - Returns: JSON 格式的状态树
    nonisolated public func dumpState(indent: Int = 0) -> String {
        (self as StateContainer).dumpState(indent: indent)
    }
}

// MARK: - CustomReflectable

extension Store: CustomReflectable {
    /// 自定义 LLDB `po` 输出，显示 state 属性和子 Store
    public nonisolated var customMirror: Mirror {
        var allChildren: [Mirror.Child] = []

        // state 属性
        for child in Mirror(reflecting: _stateLock.withLock { $0 }).children {
            guard let label = child.label else { continue }
            allChildren.append((label: label, value: child.value))
        }

        // 子 Store
        if let subStores: [String: WeakStore] = self[.subStores] {
            let subs = subStores
                .sorted { $0.key < $1.key }
                .compactMap { $0.value.store }
            if !subs.isEmpty {
                allChildren.append((label: "subStates", value: subs))
            }
        }

        return Mirror(self, children: allChildren, displayStyle: .class, ancestorRepresentation: .generated)
    }
}
