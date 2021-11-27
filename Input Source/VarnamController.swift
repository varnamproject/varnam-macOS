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

@objc(VarnamController)
public class VarnamController: IMKInputController {
    let config = VarnamConfig()
    let dispatch = AsyncDispatcher()
    private let clientManager: ClientManager
    
    private var cursorPos = 0
    private var preedit = ""
    private (set) var candidates = autoreleasepool { return [String]() }
    
    private var schemeID = "ml"
    private (set) var varnam: Varnam! = nil
    
    private (set) var validInputs: CharacterSet;
    private (set) var wordBreakChars: CharacterSet;
    
    private func initVarnam() -> Bool {
        if (varnam != nil) {
            closeVarnam()
        }
        schemeID = config.schemeID
        do {
            varnam = try Varnam(schemeID)
        } catch let error {
            Logger.log.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    private func closeVarnam() {
        varnam.close()
        varnam = nil
    }
    
    public override init!(server: IMKServer, delegate: Any!, client inputClient: Any) {
        guard let client = inputClient as? IMKTextInput & NSObjectProtocol else {
            Logger.log.warning("Client does not conform to the necessary protocols - refusing to initiate VarnamController!")
            return nil
        }
        guard let clientManager = ClientManager(client: client) else {
            Logger.log.warning("Client manager failed to initialize - refusing to initiate VarnamController!")
            return nil
        }
        self.clientManager = clientManager
        
        validInputs = CharacterSet.letters
        wordBreakChars = CharacterSet.punctuationCharacters
        
        // TODO get special characters from varnam via SearchSymbolTable
        let validSpecialInputs = [
            "_", // Used for ZWJ
            "~" // Used usually for virama
        ]
        for char in validSpecialInputs {
            let charScalar = char.unicodeScalars.first!
            validInputs.insert(charScalar)
            wordBreakChars.remove(charScalar)
        }
        
        super.init(server: server, delegate: delegate, client: inputClient)
        
        _ = initVarnam()
        Logger.log.debug("Initialized Controller for Client: \(clientManager)")
    }
    
    func clearState() {
        preedit = ""
        cursorPos = 0
        clientManager.clear()
    }
    
    func commitText(_ text: String) {
        clientManager.commitText(text)
        clearState()
        
        if config.learnWords {
            Logger.log.debug("Learning \(text)")
            do {
                try varnam.learn(text)
            } catch let error {
                Logger.log.warning(error.localizedDescription)
            }
        }
    }
    
    func commitCandidateAt(_ position: Int) {
        if position == 0 {
            commitText(preedit)
        } else if let text = clientManager.getCandidateAt(position-1) {
            commitText(text)
        }
    }
    
    func commitPreedit() -> Bool {
        if preedit.isEmpty {
           return false
        }
        commitText(preedit)
        return true
    }
    
    // Commits the first candidate if available
    func commit() -> Bool {
        if let text = clientManager.getCandidate() {
            commitText(text)
            return true
        }
        return false
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
        
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            if preedit.count == 0 {
                return false
            }
            if keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
                Logger.log.debug("CMD + DEL = Unlearn word")
                if let text = clientManager.getCandidate() {
                    try! varnam.unlearn(text)
                    updateLookupTable()
                }
            }
        }
        
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
                return commitPreedit()
            } else {
                commitText(text!)
            }
            return true
        case kVK_Escape:
            return commitPreedit()
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
            if let chars = event.characters, chars.unicodeScalars.count == 1 {
                let numericKey: Int = Int(chars) ?? 10
                
                if numericKey >= 0 && numericKey <= 9 {
                    // Numeric key press
                    commitCandidateAt(numericKey)
                    return true
                }
                
                let charScalar = chars.unicodeScalars.first!
                
                if wordBreakChars.contains(charScalar) {
                    if let text = clientManager.getCandidate() {
                        commitText(text + chars)
                        return true
                    }
                    return false
                }
                
                if event.modifierFlags.isSubset(of: [.capsLock, .shift]), validInputs.contains(charScalar) {
                    Logger.log.debug("character event: \(chars)")
                    return processInput(chars)
                }
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
        Logger.log.debug("Client: \(clientManager) loosing focus by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // Do this in case the application is quitting, otherwise we will end up with a SIGSEGV
        dispatch.cancelAll()
        clearState()
        closeVarnam()
    }
    
    /// This message is sent when our client gains focus
    public override func activateServer(_ sender: Any!) {
        Logger.log.debug("Client: \(clientManager) gained focus by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // There are three sources for current script selection - (a) self.schemeID, (b) config.schemeID and (c) selectedMenuItem.title
        // (b) could have changed while we were in background - converge (a) -> (b) if global script selection is configured
        if schemeID != config.schemeID {
            Logger.log.debug("Initializing varnam: \(schemeID) to: \(config.schemeID)")
            _ = initVarnam()
        }
        if (varnam == nil) {
            _ = initVarnam()
        }
    }
    
    public override func menu() -> NSMenu! {
        Logger.log.debug("Returning menu")
        // Set the system trey menu selection to reflect our literators; converge (c) -> (a)
        let systemTrayMenu = (NSApp.delegate as! AppDelegate).systemTrayMenu!
        systemTrayMenu.items.forEach() { $0.state = .off }
        systemTrayMenu.items.first(where: { ($0.representedObject as! String) == schemeID } )?.state = .on
        return systemTrayMenu
    }
    
    public override func candidates(_ sender: Any!) -> [Any]! {
        Logger.log.debug("Returning Candidates for sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        return clientManager.candidates
    }
    
    public override func candidateSelected(_ candidateString: NSAttributedString!) {
        Logger.log.debug("Candidate selected: \(candidateString!)")
        commitText(candidateString.string)
    }
    
    public override func commitComposition(_ sender: Any!) {
        Logger.log.debug("Commit Composition called by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // This is usually called when current input method is changed.
        // Some apps also call to commit
        _ = commitPreedit()
    }
    
    @objc public func menuItemSelected(sender: NSDictionary) {
        let item = sender.value(forKey: kIMKCommandMenuItemName) as! NSMenuItem
        Logger.log.debug("Menu Item Selected: \(item.title)")
        // Converge (b) -> (c)
        config.schemeID = item.representedObject as! String
        // Converge (a) -> (b)
        _ = initVarnam()
    }
}
