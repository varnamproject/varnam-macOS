/*
 * VarnamIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import InputMethodKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private (set) var server: IMKServer!
    private (set) var candidatesWindow: IMKCandidates!
    
    private var _languageConfig: [LanguageConfig]?
    private var _systemTrayMenu: NSMenu?
    var systemTrayMenu: NSMenu! { get {
        let config = VarnamConfig()
        if config.languageConfig == _languageConfig, let menu = _systemTrayMenu {
            return menu
        }
        _languageConfig = config.languageConfig
        let systemTrayMenu = NSMenu(title: "VarnamIME")
        Logger.log.debug("Adding Installed Scripts to Menu")
        for entry in _languageConfig!.filter({ $0.isEnabled }) {
            let item = NSMenuItem(title: entry.language, action: #selector(VarnamController.menuItemSelected), keyEquivalent: "")
            if let flags = entry.shortcutModifiers, let key = entry.shortcutKey {
                item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: flags)
                item.keyEquivalent = item.keyEquivalentModifierMask.contains(.shift) ? key : key.lowercased()
            }
            if entry.identifier == config.schemeID {
                item.state = .on
            }
            item.representedObject = entry.identifier
            systemTrayMenu.addItem(item)
        }
        _systemTrayMenu = autoreleasepool { systemTrayMenu }
        return _systemTrayMenu
    }}
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for arg in CommandLine.arguments {
            if arg == "-import" {
                importVLF()
                exit(0)
            }
        }
        print("Initing...")
        
        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            fatalError("Unable to get Connection Name from Info dictionary!")
        }
        guard let bundleId = Bundle.main.bundleIdentifier else {
            fatalError("Unable to obtain bundle identifier!")
        }
        guard let server = IMKServer(name: connectionName, bundleIdentifier: bundleId) else {
            fatalError("Unable to init IMKServer for connection name: \(connectionName) and bundle id: \(bundleId)")
        }
        Logger.log.debug("Initialized IMK Server: \(server.bundle().bundleIdentifier ?? "nil")")
        self.server = server
        
        // Panel type is the orientation. Default: Vertical
        // Use kIMKSingleRowSteppingCandidatePanel for horizontal
        candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        candidatesWindow.setAttributes([IMKCandidatesSendServerKeyEventFirst: NSNumber(booleanLiteral: true)])
        
        print("Inited")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        Logger.log.debug("Comitting all editing before terminating")
        server.commitComposition(self)
    }
    
    func importVLF() {
        Varnam.importAllVLFInAssets()
    }
}
