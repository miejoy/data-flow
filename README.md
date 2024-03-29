# DataFlow

> [English Version](README-EN.md)

DataFlow 定义了 App 中数据应该如何存储、传递和处理。该模块定义了几种基础类型和协议供外部使用，用户可以很方便的使用模块提供的协议、方法，快速并清晰的构造 App 内的数据流。这里定义的状态 State 可以非常方便的在流式布局的 UI 框架中使用（例如 SwfitUI），并能在数据变更时自动通知界面

DataFlow 是自定义 RSV(Resource & State & View) 设计模式中 State 层的基础模块，负责给 View 提供数据支持和交互支持，并结合 Resource 层加载各种资源，包括设备资源、网络资源等

[![Swift](https://github.com/miejoy/data-flow/actions/workflows/test.yml/badge.svg)](https://github.com/miejoy/data-flow/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/miejoy/data-flow/branch/main/graph/badge.svg)](https://codecov.io/gh/miejoy/data-flow)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-5.2-brightgreen.svg)](https://swift.org)

## 依赖

- iOS 13.0+ / macOS 10.15+
- Xcode 12.0+
- Swift 5.2+

## 简介

该模块包含几个概念需要提前了解一下:

- State: 需要存储的状态，值类型，可以包含各种可存储数据
- Store: 存储器，引用类型。用于保存状态，提供给界面绑定并分发和处理界面事件
- Action: 事件，一般用枚举。具有唯一性和可处理性

当前的 State 是以协议的方式定义的，包含如下几个协议:

- 基础协议
  - StorableState: 可存储的状态，这也是最基础的状态协议
  - InitializableState: 可直接无参数初始化的状态
  - StateContainable: 可容纳子状态的状态，实际定义未继承 StorableState
  - AttachableState: 可附加于其他状态的状态
  - ReducerLoadableState: 可自动加载处理器的状态

- 扩展协议
  - SharableState: 可共享的状态
  - FullSharableState: 完整的可共享状态，包含 SharableState、ReducerLoadableState、 ActionBindable

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
    @ObservedObject var normalStore = Store<NormalState>.box(NormalState())
    
    var body: some View {
        Text(normalStore.name)
    }
}
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

2、扩张已有状态，添加默认事件

```swift
extension NormalSharedState : ActionBindable {
    typealias BindAction = NormalAction
}
```

3、扩张已有状态支持自动加载处理器

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

## 作者

Raymond.huang: raymond0huang@gmail.com

## License

DataFlow is available under the MIT license. See the LICENSE file for more info.
