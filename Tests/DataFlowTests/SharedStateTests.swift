//
//  SharedStateTests.swift
//  
//
//  Created by 黄磊 on 2022/4/23.
//

import XCTest
import SwiftUI
@testable import DataFlow

class SharedStateTests: XCTestCase {
    
    // 正常状态的获取
    func testSharedNormalState() {
        
        let shared = Store<NormalSharedState>.shared
        
        let saved = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
        
        XCTAssert(shared === saved)
        
        let shared1 = Store<NormalSharedState>.shared
        let saved1 = s_mapSharedStore[ObjectIdentifier(NormalSharedState.self)] as! Store<NormalSharedState>
    
        XCTAssert(shared === shared1)
        XCTAssert(shared1 === saved1)
    }
    
    // 可加载处理器状态的获取
    func testSharedReducerState() {
        
        let shared = Store<SharedReducerState>.shared
        
        let saved = s_mapSharedStore[ObjectIdentifier(SharedReducerState.self)] as! Store<SharedReducerState>
        
        XCTAssert(shared === saved)
        XCTAssert(sharedReducerStateIsLoad)
        
        let shared1 = Store<SharedReducerState>.shared
        let saved1 = s_mapSharedStore[ObjectIdentifier(SharedReducerState.self)] as! Store<SharedReducerState>
    
        XCTAssert(shared === shared1)
        XCTAssert(shared1 === saved1)
    }
    
    func testNormalSharedView() {
        
        s_mapSharedStore.removeAll()
        let view = NormalSharedView()
        XCTAssertEqual(view.normalState.name, "")
        XCTAssertEqual(Store<NormalSharedState>.shared.name, "")
        
        _ = view.body
        let content = "content"
        view.normalState.name = content
        XCTAssertEqual(view.normalState.name, content)
        XCTAssertEqual(Store<NormalSharedState>.shared.name, content)
    }
    
    func testShareStore() {
        s_mapSharedStore.removeAll()
        let view = SharedStateTestView()
        XCTAssertEqual(view.testState.content, "")
        XCTAssertEqual(Store<TestState>.shared.content, "")
        
        _ = view.body
        let content = "content"
        view.$testState.send(action: .changeContent(content))
        XCTAssertEqual(view.testState.content, content)
        XCTAssertEqual(Store<TestState>.shared.content, content)
    }
}

struct SharedStateTestView: View {
    
    @SharedState var testState: TestState;
    
    var body: some View {
        VStack {
            Text(testState.content);
            Button("Random Text") {
                $testState.send(action: .changeContent(String(Int.random(in: 100...999))))
            }
        }
    }
}

enum TestAction: Action {
    case changeContent(String)
}

struct TestState: StateSharable, StateReducerLoadable, ActionBindable {
    
    typealias UpState = AppState
    typealias BindAction = TestAction
    
    var content: String = ""
    
    static func loadReducers(on store: Store<TestState>) {
        store.register { (state, action: TestAction) in
            switch action {
            case .changeContent(let string):
                state.content = string
            }
        }
    }
}

enum NormalAction : Action {
    case userClick
}

struct NormalSharedState : StateSharable {
    typealias UpState = AppState
    var name: String = ""
}

extension NormalSharedState : ActionBindable {
    typealias BindAction = NormalAction
}

struct NormalSharedView: View {
    
    @SharedState var normalState: NormalSharedState;
    
    var body: some View {
        VStack {
            Text(normalState.name)
            Button("Button") {
                normalState.name = String(Int.random(in: 100...999))
            }
        }
    }
}

var sharedReducerStateIsLoad = false
struct SharedReducerState : StateSharable, StateReducerLoadable {

    typealias UpState = AppState
    
    static func loadReducers(on store: Store<SharedReducerState>) {
        sharedReducerStateIsLoad = true
    }
}
