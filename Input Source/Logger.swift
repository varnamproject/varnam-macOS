/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

/**
 If clients want to use the same log formatting and logger features of LipikaEngine, they are free to use this class.
 Logger exposes a thread-local instance called `Logger.log` that needs to be used. Logger itself cannot be instantiated.
 
 - Important: `logLevel` is thread-local specific and not global.
 - Note: message strings passed into Logger are @autoclosure and hence are not *evaluated* unless they are logged.
 
 __Usage__
 ```
 Logger.logLevel = .warning
 Logger.log.debug("you don't need to know")
 Logger.log.warning("you may want to know")
 ```
 */
public final class Logger {

    /// Enumeration of errors thrown from `Logger`
    public enum LoggerError: Error {
        /// Indicates that `startCapture` was invoked again without calling `endCapture` in between.
        case alreadyCapturing
    }
    
    /// Enumeration of logging levels in the decreasing order of verbosity and increasing order of importance: `Level.debug`, `Level.warning`, `Level.error`, `Level.fatal`.
    public enum Level: String, CaseIterable {
        /// Lots of informative messages only useful for developers while debugging
        case debug = "Debug"
        /// Some unexpected execution paths that may be useful for power-users
        case warning = "Warning"
        /// Only those errors that are real and cause visible issues to the end-users
        case error = "Error"
        /// Completely unexpected events that are usually indicative of fundamental bugs
        case fatal = "Fatal"
        
        private var weight: Int {
            switch self {
            case .debug:
                return 0
            case .warning:
                return 1
            case .error:
                return 2
            case .fatal:
                return 3
            }
        }
        
        static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.weight < rhs.weight
        }
        static func > (lhs: Level, rhs: Level) -> Bool {
            return lhs.weight > rhs.weight
        }
        static func >= (lhs: Level, rhs: Level) -> Bool {
            return lhs.weight >= rhs.weight
        }
        static func <= (lhs: Level, rhs: Level) -> Bool {
            return lhs.weight <= rhs.weight
        }
    }

    private static let logLevelKey = "logLevel"
    private static let loggerInstanceKey = "logger"
    
    private var capture: [String]?
    private let minLevel = Logger.logLevel
    private init() { }
    
    deinit {
        if let capture = self.capture {
            log(level: .warning, message: "Log capture started but not ended with \(capture.count) log entries!")
        }
    }

    /// Thread-local singleton instance of Logger that clients must use. `Logger` itself cannot be instantiated.
    public static var log: Logger {
        var instance = getThreadLocalData(key: loggerInstanceKey) as? Logger
        if instance == nil {
            instance = Logger()
            setThreadLocalData(key: loggerInstanceKey, value: instance!)
        }
        return instance!
    }

    /**
     Get or set the level at and after which logs will be recorded.
     Levels with decreasing verbosity and increasing importance are `Level.debug`, `Level.warning`, `Level.error` and `Level.fatal`.
     When a level of certain level of verbosity is set, all levels at and with lower verbosity are recorded.
     
     - Returns: Level or defaults to `Level.warning` if a log level has not been set on this thread
    */
    public static var logLevel: Level {
        get {
            return getThreadLocalData(key: Logger.logLevelKey) as? Level ?? .warning
        }
        set(value) {
            setThreadLocalData(key: Logger.logLevelKey, value: value)
            removeThreadLocalData(key: Logger.loggerInstanceKey)
        }
    }
    
    private func log(level: Level, message: @autoclosure() -> String) {
        if level < minLevel { return }
        let log = "[\(level.rawValue)] \(message())"
        NSLog(log)
        if var capture = self.capture {
            capture.append(log)
        }
    }

    /// Log the given message at `Level.debug` level of importance
    public func debug(_ message: @autoclosure() -> String) {
        log(level: .debug, message: message())
    }
    
    /// Log the given message at `Level.warning` level of importance
    public func warning(_ message: @autoclosure() -> String) {
        log(level: .warning, message: message())
    }

    /// Log the given message at `Level.error` level of importance
    public func error(_ message: @autoclosure() -> String) {
        log(level: .error, message: message())
    }
    
    /// Log the given message at `Level.fatal` level of importance
    public func fatal(_ message: @autoclosure() -> String) {
        log(level: .fatal, message: message())
    }
    
    /**
     Start capturing all messages that is also going to be logged.
     This is useful for programatically inspecting or showing logs to end users.
     
     - Throws: LoggerError.alreadyCapturing if this method is double invoked
    */
    public func startCapture() throws {
        if capture != nil {
            throw LoggerError.alreadyCapturing
        }
        capture = [String]()
    }
    
    /**
     End capturing logs.
     
     - Returns: list of messages that were logged at or above the specified `logLevel`.
    */
    public func endCapture() -> [String]? {
        let result = capture
        capture = nil
        return result
    }
}
