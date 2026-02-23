//
//  ReduceDependerTests.swift
//  
//
//  Created by 黄磊 on 2022/10/2.
//

import XCTest
@testable import DataFlow

@MainActor
class ReduceDependerTests: XCTestCase {
    
    func testDependerDuplicateRegister() {
        StoreCenter.shared.dependerMap = [:]
        @MainActor
        final class Observer: StoreMonitorObserver {
            var dependerDuplicateRegisterFatalErrorCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                   message == "Duplicate registration of reduce depender '\(NormalDepender.dependerId)'" {
                    dependerDuplicateRegisterFatalErrorCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)
        
        let depender = NormalDepender()
        StoreCenter.shared.registerReduceDepender(depender)
        XCTAssertEqual(observer.dependerDuplicateRegisterFatalErrorCall, false)
        StoreCenter.shared.registerReduceDepender(depender)
        XCTAssertEqual(observer.dependerDuplicateRegisterFatalErrorCall, true)
        
        cancellable.cancel()
    }
    
    func testReduceWithDepender() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<DependState>.box(.init())
        let depender = NormalDepender()
        StoreCenter.shared.registerReduceDepender(depender)
        
        depender.getCall = false
        XCTAssertEqual(dependStore.getCall, false)
        
        dependStore.send(action: .test)
        
        XCTAssertEqual(depender.getCall, true)
        XCTAssertEqual(dependStore.getCall, true)
    }
    
    func testReduceWithDependerNotFulfill() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<DependState>.box(.init())
        let depender = NormalDepender()
        StoreCenter.shared.registerReduceDepender(depender)
        
        depender.getCall = true
        XCTAssertEqual(dependStore.getCall, false)
        
        dependStore.send(action: .test)
        
        XCTAssertEqual(depender.getCall, false)
        XCTAssertEqual(dependStore.getCall, false)
    }
    
    func testReduceDependerNotRegister() {
        StoreCenter.shared.dependerMap = [:]
        StoreMonitor.shared.arrObservers = []
        @MainActor
        final class Observer: StoreMonitorObserver {
            var dependerNotFoundFatalErrorCall = false
            func receiveStoreEvent(_ event: StoreEvent) {
                if case .fatalError(let message) = event,
                   message == "Needed depender '\(NormalDepender.dependerId)' not found while reduce state '\(DependState.self)' with action '\(DependAction.test)'" {
                    dependerNotFoundFatalErrorCall = true
                }
            }
        }
        let observer = Observer()
        let cancellable = StoreMonitor.shared.addObserver(observer)
        
        let dependStore = Store<DependState>.box(.init())

        XCTAssertEqual(dependStore.getCall, false)
        
        dependStore.send(action: .test)
        
        XCTAssertEqual(dependStore.getCall, false)
        XCTAssertEqual(observer.dependerNotFoundFatalErrorCall, true)
        
        cancellable.cancel()
    }
    
    func testReduceWithMultiDepender() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<MultiDependState>.box(.init())
        let firstDepender = NormalDepender()
        let secondDepender = SecondDepender()
        StoreCenter.shared.registerReduceDepender(firstDepender)
        StoreCenter.shared.registerReduceDepender(secondDepender)
        
        firstDepender.getCall = false
        secondDepender.getCall = false
        XCTAssertEqual(dependStore.getCall, false)
        
        dependStore.send(action: .test)
        
        XCTAssertEqual(firstDepender.getCall, true)
        XCTAssertEqual(secondDepender.getCall, true)
        XCTAssertEqual(dependStore.getCall, true)
    }
    
    func testReduceWithMultiDependerFailed() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<MultiDependState>.box(.init())
        let firstDepender = NormalDepender()
        let secondDepender = SecondDepender()
        StoreCenter.shared.registerReduceDepender(firstDepender)
        StoreCenter.shared.registerReduceDepender(secondDepender)
        
        firstDepender.getCall = false
        secondDepender.getCall = true
        XCTAssertEqual(dependStore.getCall, false)
        
        dependStore.send(action: .test)
        
        XCTAssertEqual(firstDepender.getCall, true)
        XCTAssertEqual(secondDepender.getCall, false)
        XCTAssertEqual(dependStore.getCall, false)
    }
}

enum DependAction: Action {
    case test
}

struct DependState: StorableState, ReducerLoadableState, ActionBindable {
    typealias BindAction = DependAction
    var getCall: Bool = false
    static func loadReducers(on store: Store<DependState>) {
        store.registerDefault(dependers: [NormalDepender.dependerId]) { state, action in
            state.getCall.toggle()
        }
    }
}

struct MultiDependState: StorableState, ReducerLoadableState, ActionBindable {
    typealias BindAction = DependAction
    var getCall: Bool = false
    static func loadReducers(on store: Store<MultiDependState>) {
        store.registerDefault(dependers: [NormalDepender.dependerId, SecondDepender.dependerId]) { state, action in
            state.getCall.toggle()
        }
    }
}

class NormalDepender: ReduceDepender {
    var getCall: Bool = false
    func canContinueReduce(_ state: StorableState, _ action: Action) -> Bool {
        getCall.toggle()
        return getCall
    }
}

class SecondDepender: ReduceDepender {
    var getCall: Bool = false
    func canContinueReduce(_ state: StorableState, _ action: Action) -> Bool {
        getCall.toggle()
        return getCall
    }
}
