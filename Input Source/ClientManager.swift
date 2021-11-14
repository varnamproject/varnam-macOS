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
    private var tableCursorPos = 0 // Candidates table cursor position

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
            Logger.log.warning("bundleIdentifier: \(client.bundleIdentifier() ?? "nil") or uniqueClientIdentifierString: \(client.uniqueClientIdentifierString() ?? "nil") - failing ClientManager.init()")
            return nil
        }
        Logger.log.debug("Initializing client: \(bundleId) with Id: \(clientId)")
        self.client = client
        if !client.supportsUnicode() {
            Logger.log.warning("Client: \(bundleId) does not support Unicode!")
        }
        if !client.supportsProperty(TSMDocumentPropertyTag(kTSMDocumentSupportDocumentAccessPropertyTag)) {
            Logger.log.warning("Client: \(bundleId) does not support Document Access!")
        }
        _description = "\(bundleId) with Id: \(clientId)"
    }
    
    func setGlobalCursorLocation(_ location: Int) {
        Logger.log.debug("Setting global cursor location to: \(location)")
        client.setMarkedText("|", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(location, 0))
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(location, 0))
    }
    
    func updatePreedit(_ text: NSAttributedString, _ cursorPos: Int? = nil) {
        client.setMarkedText(text, selectionRange: NSMakeRange(cursorPos ?? text.length, 0), replacementRange: notFoundRange)
    }
    
    func updateCandidates(_ sugs: [String]) {
        // Remove duplicates
        // For some weird reason, when there are duplicates,
        // candidate window makes them hidden
        candidates = NSOrderedSet(array: sugs).array as! [String]
        updateLookupTable()
    }
    
    func updateLookupTable() {
        tableCursorPos = 0
        candidatesWindow.update()
        candidatesWindow.show()
    }
    
    // For moving between items of candidate table
    func tableMoveEvent(_ event: NSEvent) {
        if event.keyCode == kVK_UpArrow && tableCursorPos > 0 {
            // TODO allow moving to the end
            // This would need a custom candidate window
            // https://github.com/lennylxx/google-input-tools-macos/blob/main/GoogleInputTools/CandidatesWindow.swift
            tableCursorPos -= 1
        } else if event.keyCode == kVK_DownArrow && tableCursorPos < candidates.count - 1 {
            tableCursorPos += 1
        }
        candidatesWindow.interpretKeyEvents([event])
    }
    
    func getCandidate() -> String? {
        if candidates.count == 0 {
            return nil
        } else {
            return candidates[tableCursorPos]
        }
    }
    
    func finalize(_ output: String) {
        Logger.log.debug("Finalizing with: \(output)")
        client.insertText(output, replacementRange: notFoundRange)
        candidatesWindow.hide()
    }
    
    func clear() {
        Logger.log.debug("Clearing MarkedText and Candidate window")
        client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: notFoundRange)
        candidates = []
        candidatesWindow.hide()
    }
}
