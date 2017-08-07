//
//  Array.swift
//  Lib
//
//  Created by Nullcaller on 03/08/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

public extension Array {
    public func contains(at: Int) -> Bool {
        return self.indices.contains(at)
    }
    
    public func access(at: Int, defaultTo: Element) -> Element {
        if let property = self.access(at: at) {
            return property
        } else {
            return defaultTo
        }
    }
    
    public func access(at: Int) -> Element? {
        return self.contains(at: at) ? self[at] : nil
    }
    
    public func accessFilled(at: Int) -> Element? {
        return at < self.count ? self[at] : nil
    }
}
