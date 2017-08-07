//
//  IRC.swift
//  Arlesten GLaDOS
//
//  Created by Nullcaller on 22/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

open class ManagerIRC: NSObject, StreamDelegate {
    enum ConnectionState: UInt8 {
        case none = 0, initialized = 1, opened = 2, authenticated = 3, joined = 4
    }
    
    var connectionState: ConnectionState = .none
    
    var inputStream: InputStream
    var outputStream: OutputStream
    
    var username, password: String
    
    var host: CFString
    var port: UInt32
    
    var channel: String
    
    open var delegate: ManagerIRCDelegate?
    
    public init(username: String, password: String, host: CFString, port: UInt32, channel: String) {
        self.username = username.lowercased()
        self.password = password
        self.host = host
        self.port = port
        self.channel = channel.lowercased()
        
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, host, port, &readStream, &writeStream)
        
        inputStream = readStream!.takeUnretainedValue()
        outputStream = writeStream!.takeUnretainedValue()
        
        super.init()
        
        inputStream.delegate = self
        outputStream.delegate = self
        
        inputStream.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
        outputStream.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
        
        changeConnectionState(state: .none)
    }
    
    open func open() {
        inputStream.open()
        outputStream.open()
        
        changeConnectionState(state: .opened)
    }
    
    internal func changeConnectionState(state: ConnectionState) {
        connectionState = state
        delegate?.connectionStateChanged?(connectionState: state.rawValue)
    }
    
    internal func process() {
        switch connectionState {
            case .opened:
                query("PASS \(password)")
            
                query("NICK \(username)")
            
                changeConnectionState(state: .authenticated)
                return
            case .authenticated:
                query("JOIN #\(channel)")
            
                changeConnectionState(state: .joined)
                return
            default:
                return
        }
    }
    
    open func message(_ message: String) -> Bool {
        return query("PRIVMSG #\(channel) :\(message)")
    }
    
    open func query(_ query: String) -> Bool {
        let fixedQuery = query + "\r\n"
        let length = fixedQuery.lengthOfBytes(using: String.Encoding.utf8)
        let data = [UInt8](fixedQuery.utf8)
        
        return outputStream.write(data, maxLength: length) == data.count
    }
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
            case Stream.Event.hasBytesAvailable:
                if aStream == inputStream {
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    var input: String = ""
                    while inputStream.hasBytesAvailable {
                        let length = inputStream.read(&buffer, maxLength: 4096)
                        if let bufferedString = NSString(bytes: buffer, length: length, encoding: String.Encoding.utf8.rawValue) as String? {
                            input += bufferedString
                        }
                    }
                
                    let lines: [String] = input.components(separatedBy: "\r\n")
                
                    for line in lines {
                        delegate?.processInput(host: host, port: port, username: username, channel: channel, line: line, irc: self)
                    }
                }
            case Stream.Event.hasSpaceAvailable:
                if aStream == outputStream && connectionState != .joined {
                    process()
                }
            default:
                delegate?.streamEventHappened?(event: eventCode.rawValue)
        }
    }
}

open class ManagerIRCCollection {
    var ircManagers: [ManagerIRC] = []
    
    public init(username: String, password: String, host: CFString, port: UInt32, channels: [String]) {
        for channel in channels {
            ircManagers.append(ManagerIRC(username: username, password: password, host: host, port: port, channel: channel))
        }
    }
    
    open func assignDelegates(delegate: ManagerIRCDelegate) {
        for ircManager in ircManagers {
            ircManager.delegate = delegate
        }
    }
    
    open func openStreams() {
        for ircManager in ircManagers {
            ircManager.open()
        }
    }
}

@objc public protocol ManagerIRCDelegate {
    func processInput(host: CFString, port: UInt32, username: String, channel: String, line: String, irc: ManagerIRC)
    
    @objc optional func connectionStateChanged(connectionState: UInt8)
    
    @objc optional func streamEventHappened(event: UInt)
}

public extension ManagerIRCDelegate {
    public static func parseInput(input: String) -> (from: String?, response: String?, args: [String?]) {
        var output: (from: String?, response: String?, args: [String?])
        
        output.from = nil
        output.args = []
        
        var inputSeparated = input.components(separatedBy: " ")
        
        if inputSeparated.count < 3 {
            output.response = inputSeparated.accessFilled(at: 0)
            output.args.append(inputSeparated.accessFilled(at: 1))
        } else {
            if var from = inputSeparated.accessFilled(at: 0)?.components(separatedBy: "!").accessFilled(at: 0) {
                from.remove(at: from.startIndex)
                output.from = from
            }
            
            output.response = inputSeparated.accessFilled(at: 1)
            
            let parseOffset = 2
            
            let parseArray = inputSeparated[parseOffset..<inputSeparated.endIndex]
            for (parseWordIndex, parseWord) in parseArray.enumerated() {
                if parseWord.beginsWith(string: ":") {
                    var string = ""
                    let stringArray = parseArray[parseWordIndex+parseOffset..<parseArray.endIndex]
                    for (stringWordIndex, stringWord) in stringArray.enumerated() {
                        if stringWordIndex != stringArray.endIndex && stringWordIndex != stringArray.startIndex {
                            string += " "
                        }
                        string += stringWord
                    }
                    output.args.append(string)
                    break
                } else {
                    output.args.append(parseWord)
                }
            }
        }
        
        return output
    }
}
