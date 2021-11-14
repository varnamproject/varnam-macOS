/*
 * VarnamIME is a user-configurable phonetic Input Method Engine for Mac OS X.
 * Copyright (C) 2018 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import InputMethodKit

class ClientManager: CustomStringConvertible {
    private let notFoundRange = NSMakeRange(NSNotFound, NSNotFound)
    private let config = VarnamConfig()
    private let client: IMKTextInput

    private var candidatesWindow: IMKCandidates { return (NSApp.delegate as! AppDelegate).candidatesWindow }
    private (set) var candidates = autoreleasepool { return [String]() }
    // Cache, otherwise clients quitting can sometimes SEGFAULT us
    private var _description: String
    var description: String {
        return _description
    }

    private var attributes: [NSAttributedString.Key: Any]! {
        var rect = NSMakeRect(0, 0, 0, 0)
        return client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect) as? [NSAttributedString.Key : Any]
    }
    
    init?(client: IMKTextInput) {
        guard let bundleId = client.bundleIdentifier(), let clientId = client.uniqueClientIdentifierString() else {
            Log.warning("bundleIdentifier: \(client.bundleIdentifier() ?? "nil") or uniqueClientIdentifierString: \(client.uniqueClientIdentifierString() ?? "nil") - failing ClientManager.init()")
            return nil
        }
        Log.debug("Initializing client: \(bundleId) with Id: \(clientId)")
        self.client = client
        if !client.supportsUnicode() {
            Log.warning("Client: \(bundleId) does not support Unicode!")
        }
        if !client.supportsProperty(TSMDocumentPropertyTag(kTSMDocumentSupportDocumentAccessPropertyTag)) {
            Log.warning("Client: \(bundleId) does not support Document Access!")
        }
        _description = "\(bundleId) with Id: \(clientId)"
    }
    
    func setGlobalCursorLocation(_ location: Int) {
        Log.debug("Setting global cursor location to: \(location)")
        client.setMarkedText("|", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(location, 0))
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(location, 0))
    }
    
    func updatePreedit(_ text: NSAttributedString, _ cursorPos: Int? = nil) {
        client.setMarkedText(text, selectionRange: NSMakeRange(cursorPos ?? text.length, 0), replacementRange: notFoundRange)
    }
    
    func updateCandidates(_ sugs: [String]) {
        Log.debug(sugs)
        // Remove duplicates
        // For some weird reason, when there are duplicates,
        // candidate window makes them hidden
        candidates = NSOrderedSet(array: sugs).array as! [String]
        updateLookupTable()
    }
    
    func updateLookupTable() {
        candidatesWindow.update()
        candidatesWindow.show()
    }
    
    func getCurrentLine() -> Int {
        return candidatesWindow.lineNumberForCandidate(withIdentifier: candidatesWindow.selectedCandidate())
    }
    
    func tableMoveCursor(_ position: Int) {
        candidatesWindow.selectCandidate(withIdentifier: candidatesWindow.candidateIdentifier(atLineNumber: position)
        )
    }
    
    // For moving between items of candidate table
    func tableMoveCursorUp(_ sender: Any?) {
        tableMoveCursor(getCurrentLine() - 1)
        updateLookupTable()
    }
    func tableMoveCursorDown(_ sender: Any?) {
        tableMoveCursor(getCurrentLine() + 1)
        candidatesWindow.clearSelection()
//        updateLookupTable()
    }
    
    func getCandidate() -> String? {
        if candidates.count == 0 {
            return nil
        } else {
            // TODO get text from current highlighted candidate instead of first one
            return candidates[0]
        }
    }
    
    func finalize(_ output: String) {
        Log.debug("Finalizing with: \(output)")
        client.insertText(output, replacementRange: notFoundRange)
        candidatesWindow.hide()
    }
    
    func clear() {
        Log.debug("Clearing MarkedText and Candidate window")
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: notFoundRange)
        candidates = []
        candidatesWindow.hide()
    }
}
