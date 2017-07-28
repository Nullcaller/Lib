//
//  EventWrapper.swift
//  Arlesten Universe
//
//  Created by Nullcaller on 04/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

open class EventWrapper {
    public static func branch(qos: DispatchQoS.QoSClass, processor: EventProcessor, _ executeWrapped: @escaping () -> ()) {
        let event = Event()
        processor.setEvent(event)
        
        DispatchQueue.global(qos: qos).async {
            executeWrapped()
            event.setWrapCompleted()
            
            DispatchQueue.main.async {
                processor.processEvent()
            }
        }
    }
    
    public static func `continue`(processor: EventProcessor, _ executeWrapped: @escaping () -> ()) {
        executeWrapped()
        processor.event?.setMainCompleted()
        processor.processEvent()
    }
}

open class EventProcessor {
    var event: Event?
    var process: () -> ()
    
    public init(_ process: @escaping () -> ()) {
        self.process = process
    }
    
    func setEvent(_ event: Event) {
        self.event = event
    }
    
    func processEvent() {
        if !(event?.isProcessed)! && (event?.wrapEventCompleted)! && (event?.mainEventCompleted)! {
            process()
            event?.setProcessed()
        }
    }
}

class Event {
    var wrapEventCompleted = false
    var mainEventCompleted = false
    var isProcessed = false
    
    func setWrapCompleted() {
        wrapEventCompleted = true
    }
    
    func setMainCompleted() {
        mainEventCompleted = true
    }
    
    func setProcessed() {
        isProcessed = true
    }
}
