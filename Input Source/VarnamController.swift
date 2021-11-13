/*
 * VarnamIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import InputMethodKit
import Carbon.HIToolbox
import LipikaEngine_OSX

struct VarnamLiterated {
    var candidates: [String]
    var inputText: String
    
    init(_ i: String, _ c: [String]) {
        candidates = c
        inputText = i
    }
}

@objc(VarnamController)
public class VarnamController: IMKInputController {
    static let validInputs = CharacterSet.alphanumerics.union(CharacterSet.whitespaces).union(CharacterSet.punctuationCharacters).union(.symbols)
    let config = VarnamConfig()
    let dispatch = AsyncDispatcher()
    private let clientManager: ClientManager
    private var currentScriptName = ""
    private (set) var transliterator: Transliterator!
    private (set) var anteliterator: Anteliterator!
    
    private var cursorPos = 0
    private var preedit = ""
    private (set) var candidates = autoreleasepool { return [String]() }
    private (set) var varnam: Varnam!
    
    private func refreshLiterators() {
//        let factory = try! LiteratorFactory(config: config)
//        let override: [String: MappingValue]? = MappingStore.read(schemeName: config.schemeName, scriptName: config.scriptName)
//        transliterator = try! factory.transliterator(schemeName: config.schemeName, scriptName: config.scriptName, mappings: override)
//        anteliterator = try! factory.anteliterator(schemeName: config.schemeName, scriptName: config.scriptName, mappings: override)
        currentScriptName = config.scriptName

        varnam = try! Varnam("ml")
    }
    
    @discardableResult private func commit() -> Bool {
        if candidates.count > 0 {
            let text = candidates[0]
            print("Committing with text: \(text)")
            clientManager.finalize(text)
            return true
        }
        else {
            print("Nothing to commit")
            clientManager.clear()
            return false
        }
    }

    private func showActive(_ literated: Literated, replacementRange: NSRange? = nil) {
        if config.outputInClient {
            let attributes = mark(forStyle: kTSMHiliteConvertedText, at: replacementRange ?? client().selectedRange()) as! [NSAttributedString.Key : Any]
            let clientText = NSMutableAttributedString(string: literated.finalaizedOutput + literated.unfinalaizedOutput)
            clientText.addAttributes(attributes, range: NSMakeRange(0, clientText.length))
            clientManager.showActive(clientText: clientText, candidateText: literated.finalaizedInput + literated.unfinalaizedInput, replacementRange: replacementRange)
        }
        else {
            let attributes = mark(forStyle: kTSMHiliteSelectedRawText, at: replacementRange ?? client().selectedRange()) as! [NSAttributedString.Key : Any]
            let clientText = NSMutableAttributedString(string: literated.finalaizedInput + literated.unfinalaizedInput)
            clientText.addAttributes(attributes, range: NSMakeRange(0, clientText.length))
            clientManager.showActive(clientText: clientText, candidateText: literated.finalaizedOutput + literated.unfinalaizedOutput, replacementRange: replacementRange)
        }
    }
    
    private func moveCursorWithinMarkedText(delta: Int) -> Bool {
        if transliterator.isEmpty() {
            print("Transliterator is empty, not handling cursor move")
        }
        else if !config.outputInClient, clientManager.updateMarkedCursorLocation(delta) {
            showActive(transliterator.transliterate())
            return true
        }
        else {
            commit()
        }
        return false
    }
    
    private func convertWord(at location: Int) {
        if let wordRange = self.clientManager.findWord(at: location), wordRange.length > 0 {
            var actual = NSRange()
            guard let word = self.client().string(from: wordRange, actualRange: &actual), !word.isEmpty else {
                return
            }
            print("Found word: \(word) at: \(location) with actual: \(actual)")
            let inputs = self.anteliterator.anteliterate(word)
            print("Anteliterated inputs: \(inputs)")
            let literated = self.transliterator.transliterate(inputs)
            if word != literated.finalaizedOutput + literated.unfinalaizedOutput {
                Logger.log.error("Original: \(word) != Ante + Transliterated: \(literated.finalaizedOutput + literated.unfinalaizedOutput) - aborting conversion!")
                return
            }
            // Calculate the location of cursor within Marked Text
            self.clientManager.markedCursorLocation = config.outputInClient ? location - actual.location : transliterator.convertPosition(position: location - actual.location, fromUnits: .outputScalar, toUnits: .input)
            print("Marked Cursor Location: \(self.clientManager.markedCursorLocation!) for Global Location: \(location - actual.location)")
            self.showActive(literated, replacementRange: actual)
        }
        else {
            print("No word found at: \(location)")
        }
    }
    
    private func dispatchConversion() {
        // Don't dispatch if active session or selection is in progress
        if !transliterator.isEmpty() || client().selectedRange().length != 0 { return }
        // Do this asynch after 10ms to give didCommand time to return and for the client to react to the command such as moving the cursor to the new location
        dispatch.schedule(deadline: .now() + .milliseconds(10)) {
            [unowned self] in
            if self.transliterator.isEmpty() {
                self.convertWord(at: self.client().selectedRange().location)
            }
        }
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
        super.init(server: server, delegate: delegate, client: inputClient)
        print("hello")
        // Initialize Literators
        refreshLiterators()
        print("hello1")
        print("Initialized Controller for Client: \(clientManager)")
    }
    
    func getPreedit() -> String {
        return preedit
    }
    
    func commitComposition(client: IMKTextInput) {
        let text = getPreedit()
        if !text.isEmpty {
            NSLog("commit: \(text)")
            client.insertText(text, replacementRange: NSMakeRange(NSNotFound, NSNotFound))
            preedit = ""
        }
    }
    
//    public override func inputText(_ string: String!, key keyCode: Int, modifiers flags: Int, client sender: Any!) -> Bool {
//        NSLog("input: string(%@), keyCode(%X), flags(%X)", string, keyCode, flags)
//
//        guard let client = sender as? IMKTextInput else { return false }
//
//        var candidatesWindow: IMKCandidates { return (NSApp.delegate as! AppDelegate).candidatesWindow }
//        candidates = ["aaa", "bbb"]
//        candidatesWindow.update()
//        candidatesWindow.show()
//
//        return true
//    }
    
    public override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        print("Handling event: \(event!) from sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        if event.type == .keyDown, let chars = event.characters, chars.unicodeScalars.count == 1, event.modifierFlags.isSubset(of: [.capsLock, .shift]), VarnamController.validInputs.contains(chars.unicodeScalars.first!) {
            return processInput(chars, client: sender)
        }
        else {
            return false
//            return processEvent(event, client: sender)
        }
    }
    
    private func insertAtIndex(_ source: inout String, _ location: String.IndexDistance, _ char: String!) {
        let index = source.index(source.startIndex, offsetBy: location)
        source.insert(Character(char), at: index)
        print(source)
    }
    
    public func processInput(_ input: String!, client sender: Any!) -> Bool {
        print("Processing Input: \(input!) from sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        
        insertAtIndex(&preedit, cursorPos, input)
        cursorPos += 1
        updatePreedit()
        
        // Naming to be consistent with govarnam-ibus
        updateLookupTable()
        
        return true
    }
    
    private func resetVarnamInputState() {
        preedit = ""
        cursorPos = 0
    }
    
    private func updatePreedit() {
        clientManager.updatePreedit(preedit)
    }
    
    private func updateLookupTable() {
        let sugs = varnam.transliterate(preedit)
        clientManager.updateCandidates(sugs)
    }
    
    public func processInputLipika(_ input: String!, client sender: Any!) -> Bool {
        print("Processing Input: \(input!) from sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        if input.unicodeScalars.count != 1 || CharacterSet.whitespaces.contains(input.unicodeScalars.first!) {
            // Handle inputting of whitespace inbetween Marked Text
            if let markedLocation = clientManager.markedCursorLocation {
                print("Handling whitespace being inserted inbetween Marked Text at: \(markedLocation)")
                let literated = transliterator.transliterate()
                let aggregateInputs = literated.finalaizedInput + literated.unfinalaizedInput
                let committedIndex = aggregateInputs.index(aggregateInputs.startIndex, offsetBy: markedLocation)
                _ = transliterator.reset()
                _ = transliterator.transliterate(String(aggregateInputs.prefix(upTo: committedIndex)))
                commit()
                clientManager.finalize(input)
                clientManager.markedCursorLocation = 0
                showActive(transliterator.transliterate(String(aggregateInputs.suffix(from: committedIndex))))
                return true
            }
            else {
                print("Input triggered a commit; not handling the input")
                commit()
                return false
            }
        }
        if config.activeSessionOnInsert, transliterator.isEmpty() {
            convertWord(at: client().selectedRange().location)
        }
        let literated = transliterator.transliterate(input, position: clientManager.markedCursorLocation)
        if clientManager.markedCursorLocation != nil {
            _ = clientManager.updateMarkedCursorLocation(1)
        }
        showActive(literated)
        return true
    }
    
    public func processEvent(_ event: NSEvent, client sender: Any!) -> Bool {
        print("Processing event: \(event) from sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // Perform shortcut actions on the system trey menu if any
        if (NSApp.delegate as! AppDelegate).systemTrayMenu!.performKeyEquivalent(with: event) { return true }
        // Move the cursor back to the oldLocation because commit() will move it to the end of the committed string
        let oldLocation = client().selectedRange().location
        print("Switching \(event) at location: \(oldLocation)")
        if event.modifierFlags.isEmpty && event.keyCode == kVK_Delete { // backspace
            if let result = transliterator.delete(position: clientManager.markedCursorLocation) {
                print("Resulted in an actual delete")
                if clientManager.markedCursorLocation != nil {
                    _ = clientManager.updateMarkedCursorLocation(-1)
                }
                showActive(result)
                return true
            }
            print("Nothing to delete")
            if commit() {
                clientManager.setGlobalCursorLocation(oldLocation)
            }
            if config.activeSessionOnDelete {
                dispatchConversion()
            }
            return false
        }
        if event.modifierFlags.isEmpty && event.keyCode == kVK_Escape { // escape
            let result = transliterator.reset()
            clientManager.clear()
            print("Handled the cancel: \(result != nil)")
            return result != nil
        }
        if event.modifierFlags.isEmpty && event.keyCode == kVK_Return { // return
            return commit()    // Don't dispatchConversion
        }
        if event.modifierFlags == [.numericPad, .function] && (event.keyCode == kVK_LeftArrow || event.keyCode == kVK_RightArrow) { // left or right arrow
            if moveCursorWithinMarkedText(delta: event.keyCode == kVK_LeftArrow ? -1 : 1) {
                return true
            }
            commit()
            if event.keyCode == kVK_LeftArrow {
                clientManager.setGlobalCursorLocation(oldLocation)
            }
        }
        print("Not processing event: \(event)")
        commit()
        if config.activeSessionOnCursorMove {
            dispatchConversion()
        }
        return false
    }
    
    /// This message is sent when our client looses focus
    public override func deactivateServer(_ sender: Any!) {
        print("Client: \(clientManager) loosing focus by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // Do this in case the application is quitting, otherwise we will end up with a SIGSEGV
        dispatch.cancelAll()
        commit()
    }
    
    /// This message is sent when our client gains focus
    public override func activateServer(_ sender: Any!) {
        print("Client: \(clientManager) gained focus by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        // There are three sources for current script selection - (a) self.currentScriptName, (b) config.scriptName and (c) selectedMenuItem.title
        // (b) could have changed while we were in background - converge (a) -> (b) if global script selection is configured
        if config.globalScriptSelection, currentScriptName != config.scriptName {
            print("Refreshing Literators from: \(currentScriptName) to: \(config.scriptName)")
            refreshLiterators()
        }
    }
    
    public override func menu() -> NSMenu! {
        print("Returning menu")
        // Set the system trey menu selection to reflect our literators; converge (c) -> (a)
        let systemTrayMenu = (NSApp.delegate as! AppDelegate).systemTrayMenu!
        systemTrayMenu.items.forEach() { $0.state = .off }
        systemTrayMenu.items.first(where: { ($0.representedObject as! String) == currentScriptName } )?.state = .on
        return systemTrayMenu
    }
    
    public override func candidates(_ sender: Any!) -> [Any]! {
        print("Returning Candidates for sender: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        return clientManager.candidates
    }
    
    public override func candidateSelected(_ candidateString: NSAttributedString!) {
        print("Candidate selected: \(candidateString!)")
        commit()
    }
    
    public override func commitComposition(_ sender: Any!) {
        print("Commit Composition called by: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "unknown")")
        commit()
    }
    
    @objc public func menuItemSelected(sender: NSDictionary) {
        let item = sender.value(forKey: kIMKCommandMenuItemName) as! NSMenuItem
        print("Menu Item Selected: \(item.title)")
        // Converge (b) -> (c)
        config.scriptName = item.representedObject as! String
        // Converge (a) -> (b)
        refreshLiterators()
    }
}
