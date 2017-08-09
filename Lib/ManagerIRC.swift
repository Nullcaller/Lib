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
        case none = 0, initialized = 1, opened = 2, sentPassword = 3, sentNickname = 4, sentJoin = 5
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
                if query("PASS \(password)") == 0 {
                    changeConnectionState(state: .sentPassword)
                }
                return
            case .sentPassword:
                if query("NICK \(username)") == 0 {
                    changeConnectionState(state: .sentNickname)
                }
                return
            case .sentNickname:
                if query("JOIN #\(channel)") == 0 {
                    changeConnectionState(state: .sentJoin)
                }
                return
            default:
                return
        }
    }
    
    open func message(_ message: String, ignoreLimit: Bool = false) -> Int32 {
        return query("PRIVMSG #\(channel) :\(message)", ignoreLimit: ignoreLimit)
    }
    
    open func query(_ query: String, ignoreLimit: Bool = false) -> Int32 {
        let fixedQuery = query + "\r\n"
        let length = fixedQuery.lengthOfBytes(using: String.Encoding.utf8)
        let data = [UInt8](fixedQuery.utf8)
        
        if (delegate != nil && delegate!.canSend()) || ignoreLimit {
            let successful = outputStream.write(data, maxLength: length) == data.count
            if successful {
                delegate?.messageDates.append(Date())
                return 0
            } else {
                return 1
            }
        } else {
            return 2
        }
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
                if aStream == outputStream {
                    self.process()
                }
            default:
                delegate?.streamEventHappened?(event: eventCode.rawValue)
        }
    }
}

open class ManagerIRCCollection {
    open var ircManagers: [ManagerIRC] = []
    
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

public protocol ManagerIRCDelegate: ManagerIRCEventHandler {
    var messageLimit: (amount: Int, time: Int) { get set }
    var messageDates: [Date] { get set }
    
    func processInput(host: CFString, port: UInt32, username: String, channel: String, line: String, irc: ManagerIRC)
}

@objc public protocol ManagerIRCEventHandler {
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
    
    public func updateDates() {
        var newDates: [Date] = []
        let currentDate = Date()
        for date in messageDates {
            if let seconds = NSCalendar.current.dateComponents([ .second ], from: date, to: currentDate).second {
                if seconds < messageLimit.time {
                    newDates.append(date)
                }
            }
        }
        messageDates = newDates
    }
    
    public func canSend(_ messageLimit: (amount: Int, time: Int)? = nil) -> Bool {
        updateDates()
        return messageDates.count < (messageLimit ?? self.messageLimit).amount
    }
}
