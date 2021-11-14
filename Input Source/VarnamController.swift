/*
 * VarnamIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2018 Ranganath Atreya - LipikaIME
 * https://github.com/ratreya/lipika-ime
 * Copyright (C) 2021 Subin Siby - VarnamIME
 * https://github.com/varnamproject/varnam-macOS
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import InputMethodKit
import Carbon.HIToolbox

class Log {
    // TODO implement setting from app to enable log levels
    public static func warning(_ text: Any) {
        print(text)
    }
    public static func debug(_ text: Any) {
        print(text)
    }
}

@objc(VarnamController)
public class VarnamController: IMKInputController {
    static let validInputs = CharacterSet.alphanumerics.union(CharacterSet.whitespaces).union(CharacterSet.punctuationCharacters).union(.symbols)

    let config = VarnamConfig()
    let dispatch = AsyncDispatcher()
    private let clientManager: ClientManager
    private var currentScriptName = ""
    
    private var cursorPos = 0
    private var preedit = ""
    private (set) var candidates = autoreleasepool { return [String]() }
    private (set) var varnam: Varnam!
    
    private func initVarnam() {
        currentScriptName = config.scriptName
        varnam = try! Varnam("ml")
    }
    
    public override init!(server: IMKServer, delegate: Any!, client inputClient: Any) {
        guard let client = inputClient as? IMKTextInput & NSObjectProtocol else {
            Log.warning("Client does not conform to the necessary protocols - refusing to initiate VarnamController!")
            return nil
        }
        guard let clientManager = ClientManager(client: client) else {
            Log.warning("Client manager failed to initialize - refusing to initiate VarnamController!")
            return nil
        }
        self.clientManager = clientManager
        super.init(server: server, delegate: delegate, client: inputClient)

        initVarnam()
        Log.debug("Initialized Controller for Client: \(clientManager)")
    }
    
    func clearState() {
        preedit = ""
        cursorPos = 0
        clientManager.clear()
    }
    
    func commitText(_ text: String) {
        clientManager.finalize(text)
        clearState()
    }
    
    // Commits the first candidate if available
    func commit() {
        if let text = clientManager.getCandidate() {
            commitText(text)
        }
    }
    
    private func insertAtIndex(_ source: inout String, _ location: String.IndexDistance, _ char: String!) {
        let index = source.index(source.startIndex, offsetBy: location)
        source.insert(Character(char), at: index)
    }
    
    private func removeAtIndex(_ source: inout String, _ position: String.IndexDistance) {
        if let index = source.index(source.startIndex, offsetBy: position, limitedBy: source.endIndex) {
            source.remove(at: index)
        } else {
            // out of range
        }
    }
    
    // Handle events
    public override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        if event.type != NSEvent.EventType.keyDown {
            return false
        }
        
        let keyCode = Int(event.keyCode)
        
        switch keyCode {
        case kVK_Space:
            let text = clientManager.getCandidate()
            if text == nil {
                commitText(preedit + " ")
            } else {
                commitText(text! + " ")
            }
            return true
        case kVK_Return:
            let text = clientManager.getCandidate()
            if text == nil {
                commitText(preedit)
                return false
            } else {
                commitText(text!)
            }
            return true
        case kVK_Escape:
            if preedit.isEmpty {
               return false
            }
            commitText(preedit)
            return true
        case kVK_LeftArrow:
            if preedit.isEmpty {
                return false
            }
            if cursorPos > 0 {
                cursorPos -= 1
                updatePreedit()
            }
            return true
        case kVK_RightArrow:
            if preedit.isEmpty {
                return false
            }
            if cursorPos < preedit.count {
                cursorPos += 1
                updatePreedit()
            }
            return true
        case kVK_UpArrow, kVK_DownArrow:
            if preedit.isEmpty {
                return false
            }
            clientManager.tableMoveEvent(event)
            return true
        case kVK_Delete:
            if preedit.isEmpty {
                return false
            }
            if (cursorPos > 0) {
                cursorPos -= 1
                removeAtIndex(&preedit, cursorPos)
                updatePreedit()
                updateLookupTable()
                if preedit.isEmpty {
                    /* Current backspace has cleared the preedit. Need to reset the engine state */
                    clearState()
                }
            }
            return true
        case kVK_ForwardDelete:
            if preedit.isEmpty {
                return false
            }
            if cursorPos < preedit.count {
                removeAtIndex(&preedit, cursorPos)
                updatePreedit()
                updateLookupTable()
                if preedit.isEmpty {
                    /* Current delete has cleared the preedit. Need to reset the engine state */
                    clearState()
                }
            }
            return true
        default:
            if let chars = event.characters, chars.unicodeScalars.count == 1, event.modifierFlags.isSubset(of: [.capsLock, .shift]), VarnamController.validInputs.contains(chars.unicodeScalars.first!) {
                NSLog("character event: \(chars)")
                return processInput(chars)
            }
        }
        return false
    }
    
    public func processInput(_ input: String!) -> Bool {
        insertAtIndex(&preedit, cursorPos, input)
        cursorPos += 1
        updatePreedit()
        
        // Naming to be consistent with govarnam-ibus
        updateLookupTable()
        
        return true
    }
    
    private func updatePreedit() {
        let attributes = mark(forStyle: kTSMHiliteSelectedRawText, at: client().selectedRange()) as! [NSAttributedString.Key : Any]
        let clientText = NSMutableAttributedString(string: preedit)
        clientText.addAttributes(attributes, range: NSMakeRange(0, clientText.length))
        clientManager.updatePreedit(clientText, cursorPos)
    }
    
    private func updateLookupTable() {
        let sugs = varnam.transliterate(preedit)
        clientManager.updateCandidates(sugs)
    }
    
    /// This message is sent when our client looses focus
    public override func deactivateServer(_ sender: Any!) {
        Log.debug("Client: \(clientManager) loosing focus by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // Do this in case the application is quitting, otherwise we will end up with a SIGSEGV
        dispatch.cancelAll()
        clearState()
    }
    
    /// This message is sent when our client gains focus
    public override func activateServer(_ sender: Any!) {
        Log.debug("Client: \(clientManager) gained focus by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // There are three sources for current script selection - (a) self.currentScriptName, (b) config.scriptName and (c) selectedMenuItem.title
        // (b) could have changed while we were in background - converge (a) -> (b) if global script selection is configured
        if config.globalScriptSelection, currentScriptName != config.scriptName {
            Log.debug("Refreshing Literators from: \(currentScriptName) to: \(config.scriptName)")
//            refreshLiterators() aka initVarnam() be called again ?
        }
    }
    
    public override func menu() -> NSMenu! {
        Log.debug("Returning menu")
        // Set the system trey menu selection to reflect our literators; converge (c) -> (a)
        let systemTrayMenu = (NSApp.delegate as! AppDelegate).systemTrayMenu!
        systemTrayMenu.items.forEach() { $0.state = .off }
        systemTrayMenu.items.first(where: { ($0.representedObject as! String) == currentScriptName } )?.state = .on
        return systemTrayMenu
    }
    
    public override func candidates(_ sender: Any!) -> [Any]! {
        Log.debug("Returning Candidates for sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        return clientManager.candidates
    }
    
    public override func candidateSelected(_ candidateString: NSAttributedString!) {
        Log.debug("Candidate selected: \(candidateString!)")
        commitText(candidateString.string)
    }
    
    public override func commitComposition(_ sender: Any!) {
        Log.debug("Commit Composition called by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        commit()
    }
    
    @objc public func menuItemSelected(sender: NSDictionary) {
        let item = sender.value(forKey: kIMKCommandMenuItemName) as! NSMenuItem
        Log.debug("Menu Item Selected: \(item.title)")
        // Converge (b) -> (c)
        config.scriptName = item.representedObject as! String
        // Converge (a) -> (b)
        initVarnam()
    }
}
