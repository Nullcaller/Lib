//
//  ApplicationManager.swift
//  Lib
//
//  Created by Nullcaller on 21/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation
import Cocoa

open class ManagerApplication: NSObject, NSApplicationDelegate {
    public let application = NSApplication.shared()
    
    public override init() {
        super.init()
    }
    
    public func assign() -> Int32 {
        application.delegate = self
        if(application.delegate !== self) {
            return 1
        }
        return 0
    }
}
