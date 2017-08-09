//
//  Neuron.swift
//  Lib
//
//  Created by Nullcaller on 02/08/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

//protocol NeuralObject {
//
//}

//class NeuronLayer: NeuralObject {
//    subscript(index: Int) -> Neuron {
//
//    }
//}

/* protocol NeuralConnection {
    func getValue() -> Double
}

class NeuralConnectionBridged: NeuralConnection {
    var neuronTo: Neuron
    var neuronFrom: Neuron
    
    private var weight: Double
    private var value: Double? = nil
    
    init(neuronFrom: Neuron, neuronTo: Neuron, weight: Double) {
        self.neuronFrom = neuronFrom
        self.neuronTo = neuronTo
        self.weight = weight
        neuronFrom.addOutputConnection(connection: self)
        neuronTo.addInputConnection(connection: self)
    }
    
    func getValue() -> Double {
        if value == nil {
            value = neuronFrom.getValue()
        }
        return weight * value!
    }
    
    func resetValue() {
        value = nil
    }
    
    func setWeight(weight: Double) {
        self.weight = weight
    }
    
    func getWeight() -> Double {
        return weight
    }
}

class Neuron: NeuralObject {
    private var inputConnections: [NeuralConnection] = []
    private var outputConnections: [NeuralConnection] = []
    
    subscript(index: Int) -> NeuralConnection {
        return inputConnections[index]
    }
    
    func addInputConnection(connection: NeuralConnection) {
        inputConnections.append(connection)
    }
    
    func addOutputConnection(connection: NeuralConnection) {
        outputConnections.append(connection)
    }
    
    func getValue() -> Double {
        var value: Double = 0
        for dependencyConnection in inputConnections {
            value += dependencyConnection.getValue()
        }
        return value
    }
} */

/* protocol Neuron {
    func getState() -> Double
}

class NeuronRoot: Neuron {
    var state: Double = 0.0
    
    func getState() -> Double {
        return state
    }
} */


// Recursively Updated Neuron
class Neuron {
    var state: Double? = nil
    
    var afterNeurons: [Int : Neuron] = [:]
    var afterIDs: [Int : Int] = [:]
    
    var beforeNeurons: [Int : Neuron] = [:]
    var beforeValues: [Int : Double] = [:]
    var beforeWeights: [Int: Double] = [:]
    
    func addBeforeNeuron(neuron: Neuron) -> Int {
        let index = beforeNeurons.count
        beforeNeurons[index] = neuron
        return index
    }
    
    func addAfterNeuron(neuron: Neuron) {
        let index = afterNeurons.count
        afterIDs[index] = neuron.addBeforeNeuron(neuron: self)
        afterNeurons[index] = neuron
    }
    
    func getState() -> Double {
        if state == nil {
            state = 0
            for (index, neuronStorage) in beforeNeurons.enumerated() {
                if beforeValues[index] == nil {
                    beforeValues[index] = neuronStorage.value.getState()
                }
                state! += (beforeWeights[index] ?? 0) * beforeValues[index]!
            }
        }
        return state!
    }
    
    func update() {
        for (index, neuronStorage) in afterNeurons.enumerated() {
            neuronStorage.value.beforeValues[afterIDs[index]!] = self.getState()
            neuronStorage.value.update()
        }
    }
    
    func updateWeight(id: Int, weight: Double) {
        setWeight(id: id, weight: weight)
        update()
    }
    
    func setWeight(id: Int, weight: Double) {
        beforeWeights[id] = weight
    }
}
