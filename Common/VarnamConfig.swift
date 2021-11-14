/*
 * VarnamIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2018 Ranganath Atreya - LipikaIME
 * Copyright (C) 2021 Subin Siby - VarnamIME
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import Foundation

struct LanguageConfig: Codable, Equatable, Hashable {
    var identifier: String  // Factory default name of the language
    var language: String
    var isEnabled: Bool
    var shortcutKey: String?
    var shortcutModifiers: UInt?
}

class VarnamConfig: Config {
    private static let kGroupDomainName = "group.varnamproject.Varnam"
    private var userDefaults: UserDefaults
    
    override init() {
        guard let groupDefaults = UserDefaults(suiteName: VarnamConfig.kGroupDomainName) else {
            fatalError("Unable to open UserDefaults for suite: \(VarnamConfig.kGroupDomainName)!")
        }
        self.userDefaults = groupDefaults
        super.init()
    }
    
    func resetSettings() {
        guard var domain = UserDefaults.standard.persistentDomain(forName: VarnamConfig.kGroupDomainName) else { return }
        domain.keys.forEach() { key in
            if key != "languageConfig" {
                domain.removeValue(forKey: key)
            }
        }
        UserDefaults.standard.setPersistentDomain(domain, forName: VarnamConfig.kGroupDomainName)
        UserDefaults.standard.synchronize()
    }
    
    func isFactorySettings() -> Bool {
        guard let domain = UserDefaults.standard.persistentDomain(forName: VarnamConfig.kGroupDomainName) else { return true }
        return domain.keys.isEmpty || (domain.keys.count == 1 && domain.keys.first! == "languageConfig")
    }
    
    func resetLanguageConfig() {
        userDefaults.removeObject(forKey: "languageConfig")
    }

    override var stopCharacter: UnicodeScalar {
        get {
            return userDefaults.string(forKey: #function)?.unicodeScalars.first ?? super.stopCharacter
        }
        set(value) {
            userDefaults.set(String(value), forKey: #function)
        }
    }
    
    override var escapeCharacter: UnicodeScalar {
        get {
            return userDefaults.string(forKey: #function)?.unicodeScalars.first ?? super.escapeCharacter
        }
        set(value) {
            userDefaults.set(String(value), forKey: #function)
        }
    }

    override var logLevel: Logger.Level {
        get {
            if let logLevelString = userDefaults.string(forKey: #function) {
                return Logger.Level(rawValue: logLevelString)!
            }
            else {
                return super.logLevel
            }
        }
        set(value) {
            userDefaults.set(value.rawValue, forKey: #function)
        }
    }
    
    // Varnam schemeID to use
    var schemeID: String {
        get {
            return userDefaults.string(forKey: #function) ?? languageConfig.first(where: { $0.isEnabled })?.identifier ?? languageConfig.first!.identifier
        }
        set(value) {
            userDefaults.set(value, forKey: #function)
        }
    }
    
    var learnWords: Bool {
        get {
            return userDefaults.bool(forKey: #function)
        }
        set(value) {
            userDefaults.set(value, forKey: #function)
        }
    }
    
    var languageConfig: [LanguageConfig] {
        get {
            if let encoded = userDefaults.data(forKey: #function) {
                do {
                    return try JSONDecoder().decode(Array<LanguageConfig>.self, from: encoded)
                }
                catch {
                    Logger.log.error("Exception while trying to decode languageConfig: \(error)")
                    resetLanguageConfig()
                }
            }
            return factoryLanguageConfig
        }
        set(value) {
            let encodedData: Data = try! JSONEncoder().encode(value)
            userDefaults.set(encodedData, forKey: #function)
        }
    }
    
    var factoryLanguageConfig: [LanguageConfig] {
        get {
            let schemes = Varnam.getAllSchemeDetails()
            var configs = [LanguageConfig]()
            for scheme in schemes {
                configs.append(LanguageConfig(
                    identifier: scheme.Identifier,
                    language: scheme.DisplayName,
                    isEnabled: true
                ))
            }
            return configs
        }
    }
}
