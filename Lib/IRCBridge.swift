//
//  IRC.swift
//  Arlesten GLaDOS
//
//  Created by Nullcaller on 22/07/2017.
//  Copyright © 2017 Arlesten. All rights reserved.
//

import Foundation

open class IRCBridge: NSObject, StreamDelegate {
    enum ConnectionState: Int {
        case none = 0, opened = 1, authenticated = 2, joined = 3
    }
    private var connectionState: ConnectionState = .none
    
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
    private var username, password: String
    
    private var host: CFString
    private var port: UInt32
    
    private var channel: String
    
    open var showPassword: Bool
    open var visiblePassword: String {
        if showPassword {
            return password
        }
        return "<password is hidden>"
    }
    
    open var delegate: IRCDelegate?
    
    public convenience init(username: String, password: String, host: CFString, port: UInt32, channel: String) {
        self.init(username: username, password: password, host: host, port: port, channel: channel, showPassword: false)
    }
    
    public init(username: String, password: String, host: CFString, port: UInt32, channel: String, showPassword: Bool) {
        self.username = username.lowercased()
        self.password = password
        self.host = host
        self.port = port
        self.channel = channel.lowercased()
        self.showPassword = showPassword
    }
    
    open func open() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, host, port, &readStream, &writeStream)
        
        delegate?.onStreamPairCreation?(host: host, port: port, username: username, channel: channel)
        
        inputStream = readStream?.takeUnretainedValue()
        outputStream = writeStream?.takeUnretainedValue()
        
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        delegate?.onStreamsDelegateAssigned?(host: host, port: port, username: username, channel: channel)
        
        inputStream?.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
        outputStream?.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
        
        delegate?.onStreamsScheduled?(host: host, port: port, username: username, channel: channel)
        
        inputStream?.open()
        outputStream?.open()
        
        connectionState = .opened
    }
    
    internal func process() {
        delegate?.onConnectionIsGoingToBeProcessed?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
        switch connectionState {
        case .none:
            return
        case .opened:
            if !query("PASS \(password)") {
                delegate?.onConnectionProccessingFailed?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
            }
            
            delegate?.onAuthenticationPasswordSent?(host: host, port: port, username: username, channel: channel)
            
            if !query("NICK \(username.lowercased())") {
                delegate?.onConnectionProccessingFailed?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
            }
            
            delegate?.onAuthenticationUsernameSent?(host: host, port: port, username: username, channel: channel)
            
            connectionState = .authenticated
            return
        case .authenticated:
            if !query("JOIN #\(channel)") {
                delegate?.onConnectionProccessingFailed?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
            }
            
            delegate?.onChannelJoinSent?(host: host, port: port, username: username, channel: channel)
            
            connectionState = .joined
            return
        case .joined:
            return
        }
    }
    
    open func query(_ query: String) -> Bool {
        let fixedQuery = query + "\r\n"
        let length = fixedQuery.lengthOfBytes(using: String.Encoding.utf8)
        let data = [UInt8](fixedQuery.utf8)
        
        if delegate == nil {
            return false
        } else if delegate!.maySend {
            if outputStream?.write(data, maxLength: length) == data.count {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    open func message(_ message: String) -> Bool {
        return query("PRIVMSG #\(channel) :\(message)")
    }
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        delegate?.onStreamEventHappened?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
        switch eventCode {
        case Stream.Event.openCompleted:
            delegate?.onStreamOpenCompleted?(host: host, port: port, username: username, channel: channel)
        case Stream.Event.errorOccurred:
            delegate?.onStreamErrorOccured?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream {
                delegate?.onInputStreamBytesAvailible?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
                var buffer = [UInt8](repeating: 0, count: 4096)
                var input: String = ""
                while inputStream!.hasBytesAvailable {
                    let length = inputStream!.read(&buffer, maxLength: 4096)
                    if let bufferedString = NSString(bytes: buffer, length: length, encoding: String.Encoding.utf8.rawValue) as String? {
                        input += bufferedString
                    }
                }
                
                let lines: [String] = input.components(separatedBy: "\r\n")
                
                for line in lines {
                    delegate?.processInput(host: host, port: port, username: username, channel: channel, line: line, irc: self)
                }
            } else {
                delegate?.onOutputStreamBytesAvailible?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
            }
        case Stream.Event.hasSpaceAvailable:
            if aStream == outputStream {
                if connectionState != .joined {
                    process()
                }
                delegate?.onOutputStreamSpaceAvailible?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
            } else {
                delegate?.onInputStreamSpaceAvailible?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
            }
        default:
            delegate?.onStreamUnknownEventHappened?(host: host, port: port, username: username, channel: channel, connectionState: connectionState.rawValue)
        }
    }
}

@objc public protocol IRCDelegate {
    var maySend: Bool { get }
    
    func processInput(host: CFString, port: UInt32, username: String, channel: String, line: String, irc: IRCBridge)
    
    @objc optional func onDelegateAssigned(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onConnectionIsGoingToBeProcessed(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onStreamPairCreation(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onStreamsDelegateAssigned(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onStreamsScheduled(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onStreamEventHappened(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onStreamOpenCompleted(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onStreamErrorOccured(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onInputStreamBytesAvailible(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onOutputStreamBytesAvailible(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onOutputStreamSpaceAvailible(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onInputStreamSpaceAvailible(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onStreamUnknownEventHappened(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
    
    @objc optional func onAuthenticationPasswordSent(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onAuthenticationUsernameSent(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onChannelJoinSent(host: CFString, port: UInt32, username: String, channel: String)
    
    @objc optional func onConnectionProccessingFailed(host: CFString, port: UInt32, username: String, channel: String, connectionState: Int)
}
