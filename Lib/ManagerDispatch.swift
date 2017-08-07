//
//  DispatchManager.swift
//  Lib
//
//  Created by Nullcaller on 21/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

open class ManagerDispatch {
    public static func manage(qos: DispatchQoS.QoSClass, finalization: ManagerDispatchFinalization, branches: () -> ()...) {
        let event = ManagerDispatchFinalizationEvent(branchCount: branches.count)
        finalization.bindEvent(event: event)
        
        for (index, branch) in branches.enumerated() {
            DispatchQueue.global(qos: qos).async {
                branch()
                event.setCompleted(id: index)
                
                DispatchQueue.main.async {
                    finalization.try()
                }
            }
        }
    }
}

open class ManagerDispatchFinalization {
    private var action: () -> ()
    private var event: ManagerDispatchFinalizationEvent?
    
    public init(_ action: @escaping () -> ()) {
        self.action = action
    }
    
    func bindEvent(event: ManagerDispatchFinalizationEvent) {
        self.event = event
    }
    
    func `try`() {
        if !(event?.isProcessed)! && (event?.isCompleted)! {
            action()
            event?.isProcessed = true
        }
    }
}

class ManagerDispatchFinalizationEvent {
    private var completionRegistry: [Bool] = []
    var isProcessed = false
    
    init(branchCount: Int) {
        for i in 0..<branchCount {
            completionRegistry[i] = false
        }
    }
    
    func setCompleted(id: Int) {
        completionRegistry[id] = true
    }
    
    var isCompleted: Bool {
        for completionFactor in completionRegistry {
            if(!completionFactor) {
                return false
            }
        }
        return true
    }
}
