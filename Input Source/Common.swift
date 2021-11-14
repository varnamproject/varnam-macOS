/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

func synchronize<T>(_ lockObject: AnyObject, _ closure: () -> T) -> T {
    objc_sync_enter(lockObject)
    defer { objc_sync_exit(lockObject) }
    return closure()
}

func synchronize<T>(_ lockObject: AnyObject, _ closure: () throws -> T) throws -> T {
    objc_sync_enter(lockObject)
    defer { objc_sync_exit(lockObject) }
    return try closure()
}

let keyBase = Bundle.main.bundleIdentifier ?? "LipikaEngine"

func getThreadLocalData(key: String) -> Any? {
    let fullKey: NSString = "\(keyBase).\(key)" as NSString
    return Thread.current.threadDictionary.object(forKey: fullKey)
}

func setThreadLocalData(key: String, value: Any) {
    let fullKey: NSString = "\(keyBase).\(key)" as NSString
    Thread.current.threadDictionary.setObject(value, forKey: fullKey)
}

func removeThreadLocalData(key: String) {
    let fullKey: NSString = "\(keyBase).\(key)" as NSString
    Thread.current.threadDictionary.removeObject(forKey: fullKey)
}

func filesInDirectory(directory: URL, withExtension ext: String) throws -> [String] {
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [], options: [])
    return files.filter({$0.pathExtension == ext}).compactMap { $0.deletingPathExtension().lastPathComponent }
}

extension String {
    func unicodeScalars() -> [UnicodeScalar] {
        return Array(self.unicodeScalars)
    }
    
    func unicodeScalarReversed() -> String {
        var result = ""
        result.unicodeScalars.append(contentsOf: self.unicodeScalars.reversed())
        return result
    }

    static func + (lhs: String, rhs: [UnicodeScalar]) -> String {
        var stringRHS = ""
        stringRHS.unicodeScalars.append(contentsOf: rhs)
        return lhs + stringRHS
    }
}

// Copyright mxcl, CC-BY-SA 4.0
// https://stackoverflow.com/a/46354989/1372424
public extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter{ seen.insert($0).inserted }
    }
}
