//
//  String.swift
//  Lib
//
//  Created by Nullcaller on 05/08/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

public extension String {
    func beginsWith(string: String) -> Bool {
        return self.range(of: string) != nil
    }
}
