/*
* VarnamApp is companion application for VarnamIME.
* Copyright (C) 2020 Ranganath Atreya - LipikaIME
* Copyright (C) 2021 Subin Siby - VarnamIME
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

import SwiftUI

class SettingsModel: Config, ObservableObject, PersistenceModel {
    @Published var logLevelString: String { didSet { self.reeval() } }
    @Published var learnWords: Bool { didSet { self.reeval() } }
    
    @Published var isDirty = false
    @Published var isFactory = false
    @Published var isValid = true

    override var logLevel: Logger.Level { get { Logger.Level(rawValue: logLevelString)! } }
    
    var languages: [LanguageConfig] { get {
        config.languageConfig.filter({ $0.isEnabled })
    }}
    
    func transliterate(_ input: String) -> String {
        return ""
    }

    let config = VarnamConfig()
    
    override init() {
        logLevelString = config.logLevel.rawValue
        learnWords = config.learnWords
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(self.reeval), name: UserDefaults.didChangeNotification, object: nil)
        reeval()
    }
    
    func reset() {
        config.resetSettings()
        self.reload()
    }
    
    func reload() {
        logLevelString = config.logLevel.rawValue
        learnWords = config.learnWords
        reeval()
    }
    
    func save() {
        config.logLevel = logLevel
        config.learnWords = learnWords
        reeval()
    }
    
    @objc func reeval() {
        isDirty =
            config.logLevel != logLevel ||
            config.learnWords != learnWords
        isFactory = config.isFactorySettings()
        isValid = true
    }
}
