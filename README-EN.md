# DataFlow

> [中文版](https://github.com/miejoy/data-flow)

DataFlow defines how to store, pass and handle data in App. It also defines several base types and protocols which are easy to use and can make data flow in App build quickly and clearly. The State defined in this module can be used in SwiftUI smoothly and update UI automatically when data changed.

DtatFlow is in the **State** layer of a custom RSV(Resource & State & View) pattern design. It provides data support and interactive support for **View**. It also works with **Resource** layer to load resources, including device resources, network resources, etc.

[![Swift](https://github.com/miejoy/data-flow/actions/workflows/test.yml/badge.svg)](https://github.com/miejoy/data-flow/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/miejoy/data-flow/branch/main/graph/badge.svg)](https://codecov.io/gh/miejoy/data-flow)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-5.2-brightgreen.svg)](https://swift.org)

## Requirements

- iOS 13.0+ / macOS 10.15+
- Xcode 12.0+
- Swift 5.2+

## Introduction

There are several concepts need to understand first:

- State: value type, can be all kinds of storable data
- Store: reference type, holds all the states, provides state to bind view, handles and dispatchs actions
- Action: event, usually an enumeration. it must be unique and handlable

State is actually a set of protocols:

- Basic Protocols
  - StorableState: states that are storable. it is most foundational one
  - InitializableState: states can be initialized directly
  - StateContainable: states that can have substate
  - AttachableState: states that can be attached to other states
  - ReducerLoadableState: states that can load reducer automatically

- Extra Protocols
  - SharableState: states that are sharable
  - FullSharableState: states that are sharable with fully capability, combine with SharableState, ReducerLoadableState, ActionBindable

## Installation

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

Add following dependency at Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/miejoy/data-flow.git", from: "0.1.0"),
]
```

## Usage

### StorableState

1. define state

    ```swift
    import DataFlow

    struct NormalState : StorableState {
        var name: String = ""
    }
    ```

2. use it in a view

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

### SharableState

SharableState can be used cross all views

1. define state

    ```swift
    import DataFlow

    struct NormalSharedState : SharableState {
        typealias UpState = AppState

        var name: String = ""
    }
    ```

2. use it in view(s)

    ```swift
    import DataFlow
    import SwiftUI

    struct NormalSharedView: View {

        @SharedState var normalState: NormalSharedState

        var body: some View {
            Text(normalState.name)
        }
    }
    ```

### ReducerLoadableState

1. define a handleable action

    ```swift
    import DataFlow

    enum NormalAction : Action {
        case userClick
    }
    ```

2. write a extension for state to comfirm ActionBindable protocol and sign that action to BindAction

    ```swift
    extension NormalSharedState : ActionBindable {
        typealias BindAction = NormalAction
    }
    ```

3. write a extension for state to comfirm ReducerLoadableState protocol and implement the action

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

4. used in a view

    ```swift
    import DataFlow
    import SwiftUI

    struct NormalSharedView: View {

        @SharedState var normalState: NormalSharedState

        var body: some View {
            VStack {
                Text(normalState.name)
                Button("Button") {
                    $normalState.send(action: .userClick)
                }
            }
        }
    }
    ```

## Author

Raymond.huang: raymond0huang@gmail.com

## License

DataFlow is available under the MIT license. See the LICENSE file for more info.
