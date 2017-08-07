//
//  FlowManager.swift
//  Lib
//
//  Created by Nullcaller on 21/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

public protocol ManagerPhase {
    var sequence: [() -> (Int32)] { get }
}

public extension ManagerPhase {
    public func run() -> Int32 {
        for action in sequence {
            let `return` = action()
            if(`return` != 0) {
                return `return`
            }
        }
        return 0
    }
}
