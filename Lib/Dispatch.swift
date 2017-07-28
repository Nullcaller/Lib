//
//  DispatchManager.swift
//  Lib
//
//  Created by Nullcaller on 21/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

open class Dispatch {
    public static func manage(qos: DispatchQoS.QoSClass, finalization: DispatchFinalization, branches: () -> ()...) {
        let event = DispatchFinalizationEvent(branchCount: branches.count)
        finalization.bindEvent(event: event)
        
        for i in 0..<branches.count {
            DispatchQueue.global(qos: qos).async {
                branches[i]()
                event.setCompleted(id: i)
                
                DispatchQueue.main.async {
                    finalization.try()
                }
            }
        }
    }
}

open class DispatchFinalization {
    private var action: () -> ()
    private var event: DispatchFinalizationEvent?
    
    public init(_ action: @escaping () -> ()) {
        self.action = action
    }
    
    func bindEvent(event: DispatchFinalizationEvent) {
        self.event = event
    }
    
    func `try`() {
        if !(event?.isProcessed)! && (event?.isCompleted)! {
            action()
            event?.isProcessed = true
        }
    }
}

class DispatchFinalizationEvent {
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
