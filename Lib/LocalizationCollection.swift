//
//  LocalizationManager.swift
//  Lib
//
//  Created by Nullcaller on 21/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

open class LocalizationCollection {
    public var locales: [String: [String: String]] = [:]
    public var active: String = "en"
    
    public init(locales: String...) {
        for locale in locales {
            self.locales[locale] = [:]
        }
    }
    
    public func getLocalization(for: String) -> String? {
        return locales[active]?[`for`]
    }
}
