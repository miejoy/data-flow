//
//  AppState.swift
//
//
//  Created by 黄磊 on 2020-06-21.
//  Copyright © 2020 Miejoy. All rights reserved.
//

/// 定义默认 App 状态
public struct AppState : StateContainable, StateSharable {
    
    public var subStates: [String : StateStorable] = [:]
        
    public typealias UpState = Never
    
    public init() {
    }
}
