//
//  ReduceDependerTests.swift
//  
//
//  Created by 黄磊 on 2022/10/2.
//

import Testing
@testable import DataFlow
@testable import ModuleMonitor

@Suite(.serialized)
@MainActor
struct ReduceDependerTests {
    
    @Test
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
        #expect(observer.dependerDuplicateRegisterFatalErrorCall == false)
        StoreCenter.shared.registerReduceDepender(depender)
        #expect(observer.dependerDuplicateRegisterFatalErrorCall)
        
        cancellable.cancel()
    }
    
    @Test
    func testReduceWithDepender() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<DependState>.box(.init())
        let depender = NormalDepender()
        StoreCenter.shared.registerReduceDepender(depender)
        
        depender.getCall = false
        #expect(dependStore.getCall == false)
        
        dependStore.send(action: .test)
        
        #expect(depender.getCall)
        #expect(dependStore.getCall)
    }
    
    @Test
    func testReduceWithDependerNotFulfill() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<DependState>.box(.init())
        let depender = NormalDepender()
        StoreCenter.shared.registerReduceDepender(depender)
        
        depender.getCall = true
        #expect(dependStore.getCall == false)
        
        dependStore.send(action: .test)
        
        #expect(depender.getCall == false)
        #expect(dependStore.getCall == false)
    }
    
    @Test
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

        #expect(dependStore.getCall == false)
        
        dependStore.send(action: .test)
        
        #expect(dependStore.getCall == false)
        #expect(observer.dependerNotFoundFatalErrorCall)
        
        cancellable.cancel()
    }
    
    @Test
    func testReduceWithMultiDepender() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<MultiDependState>.box(.init())
        let firstDepender = NormalDepender()
        let secondDepender = SecondDepender()
        StoreCenter.shared.registerReduceDepender(firstDepender)
        StoreCenter.shared.registerReduceDepender(secondDepender)
        
        firstDepender.getCall = false
        secondDepender.getCall = false
        #expect(dependStore.getCall == false)
        
        dependStore.send(action: .test)
        
        #expect(firstDepender.getCall)
        #expect(secondDepender.getCall)
        #expect(dependStore.getCall)
    }
    
    @Test
    func testReduceWithMultiDependerFailed() {
        StoreCenter.shared.dependerMap = [:]
        let dependStore = Store<MultiDependState>.box(.init())
        let firstDepender = NormalDepender()
        let secondDepender = SecondDepender()
        StoreCenter.shared.registerReduceDepender(firstDepender)
        StoreCenter.shared.registerReduceDepender(secondDepender)
        
        firstDepender.getCall = false
        secondDepender.getCall = true
        #expect(dependStore.getCall == false)
        
        dependStore.send(action: .test)
        
        #expect(firstDepender.getCall)
        #expect(secondDepender.getCall == false)
        #expect(dependStore.getCall == false)
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
