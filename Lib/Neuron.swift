//
//  Neuron.swift
//  Lib
//
//  Created by Nullcaller on 02/08/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

class NeuronRegistry {
    var collection: [Neuron] = []
    
    
}

class Neuron {
    var identifier: Int?
    
    var weighs: [Double] = []
    var values: [Double] = []
    
    func setWeight(id: Int, weight: Double) {
        weighs.insert(weight, at: id)
    }
    
    func acceptValue(id: Int, value: Double) {
        values.insert(value, at: id)
    }
    
    func getValue() -> Double {
        var sum: Double = 0.0
        for (valueIndex, value) in values.enumerated() {
            sum += (value) * weighs.access(at: valueIndex, defaultTo: 0.0)
        }
        return sum
    }
}
