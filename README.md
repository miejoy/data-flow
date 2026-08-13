# DataFlow

> [English Version](README-EN.md)

DataFlow 定义了 App 中数据应该如何存储、传递和处理。该模块定义了几种基础类型和协议供外部使用，用户可以很方便地使用模块提供的协议、方法，快速并清晰地构造 App 内的数据流。这里定义的状态 State 可以非常方便地在流式布局的 UI 框架中使用（例如 SwiftUI），并能在数据变更时自动通知界面

DataFlow 是自定义 RSV(Resource & State & View) 设计模式中 State 层的基础模块，负责给 View 提供数据支持和交互支持，并结合 Resource 层加载各种资源，包括设备资源、网络资源等

[![Swift](https://github.com/miejoy/data-flow/actions/workflows/test.yml/badge.svg)](https://github.com/miejoy/data-flow/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/miejoy/data-flow/branch/main/graph/badge.svg)](https://codecov.io/gh/miejoy/data-flow)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-6.2-brightgreen.svg)](https://swift.org)

## 依赖

- iOS 16.0+ / macOS 13.0+
- Xcode 26.0+
- Swift 6.2+

## 简介

该模块包含几个概念需要提前了解:

- **State**: 需要存储的状态，值类型，可以包含各种可存储数据
- **Store**: 存储器，引用类型。用于保存状态，提供给界面绑定并分发和处理界面事件
- **Action**: 事件，一般用枚举。具有唯一性和可处理性

当前的 State 是以协议的方式定义的，包含如下几个协议:

- 基础协议
  - `StorableState`: 可存储的状态（需 `Sendable`），最基础的状态协议
  - `InitializableState`: 可直接无参数初始化的状态
  - `UseInitializableState`: 与 `InitializableState` 类似，额外提供对应 Store 的 init 方法
  - `StateContainable`: 可容纳子状态的标记协议（需 `Sendable`），约束 Store 可注册子 Store
  - `AttachableState`: 可附加于其他状态的状态，提供 `defaultStateId`（默认为类型名）作为 subStore 的存储 key
  - `ReducerLoadableState`: 可自动加载处理器的状态

- 扩展协议
  - `SharableState`: 可共享的状态
  - `FullSharableState`: 完整的可共享状态，包含 `SharableState`、`ReducerLoadableState`、`ActionBindable`

## 安装

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

在项目中的 Package.swift 文件添加如下依赖:

```swift
dependencies: [
    .package(url: "https://github.com/miejoy/data-flow.git", from: "0.1.0"),
]
```

## 使用

### StorableState 基础状态使用

1、定义一个状态

```swift
import DataFlow

struct NormalState : StorableState {
    var name: String = ""
}
```

2、在界面上使用

```swift
import DataFlow
import SwiftUI

struct NormalView: View {
    @StateObject var normalStore = Store<NormalState>.box(NormalState())

    var body: some View {
        Text(normalStore.name)
    }
}
```

3、在非隔离域安全读取状态属性

```swift
// subscript 自动匹配只读 KeyPath，nonisolated 可跨线程调用
let name = normalStore.name

// 显式调用 stateValue，适用于 nonisolated 域中 var 属性的读取
let name = normalStore.stateValue(\.name)
```

### SharableState 共享状态使用

可共享状态可以在所有界面共享使用

1、定义一个可共享状态

```swift
import DataFlow

struct NormalSharedState : SharableState {
    var name: String = ""
}
```

2、在界面上使用

```swift
import DataFlow
import SwiftUI

struct NormalSharedView: View {
    @ObservedObject var normalStore: Store<NormalSharedState> = .shared

    var body: some View {
        Text(normalStore.name)
    }
}
```

### ReducerLoadableState 处理器的加载和使用

1、定义一个可处理事件

```swift
import DataFlow

enum NormalAction : Action {
    case userClick
}
```

2、扩展已有状态，添加默认事件

```swift
extension NormalSharedState : ActionBindable {
    typealias BindAction = NormalAction
}
```

3、扩展已有状态支持自动加载处理器

```swift
extension NormalSharedState : ReducerLoadableState {
    static func loadReducers(on store: Store<NormalSharedState>) {
        store.registerDefault { (state, action) in
            var state = state
            switch action {
            case .userClick:
                state.name = String(Int.random(in: 100...999))
            }
            return state
        }
    }
}
```

4、在界面上使用

```swift
import DataFlow
import SwiftUI

struct NormalSharedView: View {
    @ObservedObject var normalStore: Store<NormalSharedState> = .shared

    var body: some View {
        VStack {
            Text(normalStore.name)
            Button("Button") {
                normalStore.send(action: .userClick)
            }
        }
    }
}
```

### StateContainable 子状态使用

当一个状态需要包含子状态时，父 State 遵循 `StateContainable`，子 State 遵循 `AttachableState`：

```swift
import DataFlow

// 父状态：遵循 StateContainable
struct ParentState: StorableState, StateContainable {
    var title: String = ""
}

// 子状态：遵循 AttachableState，指定 UpState 为父状态
struct ChildState: AttachableState {
    typealias UpState = ParentState
    var count: Int = 0
}
```

在 Store 中注册和获取子 Store：

```swift
let parentStore = Store<ParentState>.box(ParentState())
let childStore = Store<ChildState>.box(ChildState())

// 注册子 Store
parentStore.addSubStore(childStore)

// 获取子 Store（不传 stateId 时使用 ChildState.defaultStateId）
let retrieved = parentStore.getSubStore(of: ChildState.self)
```

同类型多实例场景——子 State 用存储属性覆盖 `stateId`：

```swift
struct ChildState: AttachableState {
    typealias UpState = ParentState
    var stateId: String = ChildState.defaultStateId  // 存储属性，可在 init 时指定
    var count: Int = 0
}

let childStore2 = Store<ChildState>.box(ChildState(stateId: "child2"))
parentStore.addSubStore(childStore2)
let retrieved2 = parentStore.getSubStore(of: ChildState.self, stateId: "child2")
```

> **stateId 机制**：`addSubStore` 用 `subStore.stateId`（默认为 `defaultStateId`，即类型名）作为 key；`getSubStore` 不传 `stateId` 时用 `S.defaultStateId`。子 Store 销毁时自动从父 Store 移除，无需手动清理。

> **通配挂载**：若子 State 的 `UpState` 设为 `AnyState`，则可挂载到任何 `StateContainable` 的父 Store（此时父 State 的 `SubState` 也需为 `AnyState`，即默认值）。`AnyState` 与 `Never` 对称，`UpState` 均为 `Never`，表示通配终点。

### 调试

在 LLDB 中使用 `po` 命令查看 Store 的完整状态树：

```swift
// 打印当前 Store 及所有子 Store 的状态（JSON 格式）
po store.dumpState()
```

输出示例：

```json
{
  "name": "hello",
  "subStates": {
    "ChildState": {
      "count": 42
    }
  }
}
```

`po store` 可查看 Store 的属性概览（通过 `CustomReflectable`）。

## 作者

Raymond.huang: raymond0huang@gmail.com

## License

DataFlow is available under the MIT license. See the LICENSE file for more info.
