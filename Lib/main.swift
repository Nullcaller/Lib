//
//  SystemWrapper.swift
//  Lib
//
//  Created by Nullcaller on 22/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

public func Managed(_ action: @escaping () -> (Int32) ) {
    exit(action())
}
