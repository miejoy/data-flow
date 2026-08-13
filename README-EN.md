# DataFlow

> [中文版](https://github.com/miejoy/data-flow)

DataFlow defines how to store, pass and handle data in App. It also defines several base types and protocols which are easy to use and can make building data flow in App quick and clear. The State defined in this module can be used in SwiftUI smoothly and update UI automatically when data changes.

DataFlow is in the **State** layer of a custom RSV(Resource & State & View) pattern design. It provides data support and interactive support for **View**. It also works with **Resource** layer to load resources, including device resources, network resources, etc.

[![Swift](https://github.com/miejoy/data-flow/actions/workflows/test.yml/badge.svg)](https://github.com/miejoy/data-flow/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/miejoy/data-flow/branch/main/graph/badge.svg)](https://codecov.io/gh/miejoy/data-flow)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-6.2-brightgreen.svg)](https://swift.org)

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 26.0+
- Swift 6.2+

## Introduction

There are several concepts that need to be understood first:

- State: value type, can be all kinds of storable data
- Store: reference type, holds all the states, provides state to bind view, handles and dispatches actions
- Action: event, usually an enumeration. It must be unique and handleable

State is actually a set of protocols:

- Basic Protocols
  - StorableState: states that are storable. It is the most foundational one
  - InitializableState: states can be initialized directly
  - StateContainable: a marker protocol for states that can have sub-stores
  - AttachableState: states that can be attached to other states, provides `defaultStateId` (defaults to type name) as the storage key for subStores
  - ReducerLoadableState: states that can load reducer automatically

- Extra Protocols
  - SharableState: states that are sharable
  - FullSharableState: states that are sharable with full capability, combined with SharableState, ReducerLoadableState, ActionBindable

## Installation

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

Add the following dependency at Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/miejoy/data-flow.git", from: "0.1.0"),
]
```

## Usage

### StorableState

1. Define state

    ```swift
    import DataFlow

    struct NormalState : StorableState {
        var name: String = ""
    }
    ```

2. Use it in a view

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

SharableState can be used across all views

1. Define state

    ```swift
    import DataFlow

    struct NormalSharedState : SharableState {
        var name: String = ""
    }
    ```

2. Use it in view(s)

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

### ReducerLoadableState

1. Define a handleable action

    ```swift
    import DataFlow

    enum NormalAction : Action {
        case userClick
    }
    ```

2. Write an extension for state to confirm ActionBindable protocol and sign that action to BindAction

    ```swift
    extension NormalSharedState : ActionBindable {
        typealias BindAction = NormalAction
    }
    ```

3. Write an extension for state to confirm ReducerLoadableState protocol and implement the action

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

4. Used in a view

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

### StateContainable

When a state needs to contain sub-states, the parent State conforms to `StateContainable` and the child State conforms to `AttachableState`:

```swift
import DataFlow

// Parent state: conforms to StateContainable
struct ParentState: StorableState, StateContainable {
    var title: String = ""
}

// Child state: conforms to AttachableState, specifying UpState
struct ChildState: AttachableState {
    typealias UpState = ParentState
    var count: Int = 0
}
```

Register and retrieve sub-stores:

```swift
let parentStore = Store<ParentState>.box(ParentState())
let childStore = Store<ChildState>.box(ChildState())

// Register sub-store
parentStore.addSubStore(childStore)

// Retrieve sub-store (uses ChildState.defaultStateId when stateId is omitted)
let retrieved = parentStore.getSubStore(of: ChildState.self)
```

For multiple instances of the same type, override `stateId` with a stored property:

```swift
struct ChildState: AttachableState {
    typealias UpState = ParentState
    var stateId: String = ChildState.defaultStateId
    var count: Int = 0
}

let childStore2 = Store<ChildState>.box(ChildState(stateId: "child2"))
parentStore.addSubStore(childStore2)
let retrieved2 = parentStore.getSubStore(of: ChildState.self, stateId: "child2")
```

> **stateId**: `addSubStore` uses `subStore.stateId` (defaults to `defaultStateId`, i.e. the type name) as the key; `getSubStore` uses `S.defaultStateId` when `stateId` is omitted. Sub-stores are automatically removed from the parent Store upon deallocation.

> **Wildcard mounting**: If the child State's `UpState` is set to `AnyState`, it can be mounted to any `StateContainable` parent Store (the parent's `SubState` must also be `AnyState`, which is the default). `AnyState` is symmetric with `Never`, both have `UpState = Never`, representing the wildcard endpoint.

### Debugging

Use `po` in LLDB to inspect the full state tree of a Store:

```swift
// Print the current Store and all sub-stores (JSON format)
po store.dumpState()
```

Example output:

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

`po store` shows a property overview (via `CustomReflectable`).

## Author

Raymond.huang: raymond0huang@gmail.com

## License

DataFlow is available under the MIT license. See the LICENSE file for more info.
