/*
* VarnamApp is companion application for VarnamIME.
* Copyright (C) 2021 Subin Siby - VarnamIME
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

import Foundation

import SwiftUI

class RLWModel: ObservableObject {
    @Published public var words: [Suggestion] = [Suggestion]();

    let config = VarnamConfig()
    
    private (set) var varnam: Varnam! = nil;
    
    private func closeVarnam() {
        varnam.close()
        varnam = nil
    }
    
    private func initVarnam() -> Bool {
        if (varnam != nil) {
            closeVarnam()
        }
        do {
            varnam = try Varnam(config.schemeID)
        } catch let error {
            Logger.log.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    init() {
        Varnam.setVSTLookupDir(config.vstDir)
        if initVarnam() {
            refreshWords()
        }
    }
    
    func refreshWords() {
        do {
            words = try varnam.getRecentlyLearnedWords()
        } catch let error {
            Logger.log.error(error.localizedDescription)
        }
    }
    
    func unlearn(_ word: String) {
        do {
            try varnam.unlearn(word)
        } catch let error {
            Logger.log.error(error.localizedDescription)
        }
        refreshWords()
    }
}

struct RecentlyLearnedWordsView: View {
    // Changes in model will automatically reload the table view
    @ObservedObject var model = RLWModel()

    var body: some View {
        VStack {
            RLWTable(
                words: model.words,
                unlearn: model.unlearn
            ).padding(16)
            Spacer(minLength: 10)
        }
    }
}

struct RecentlyLearnedWordsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyLearnedWordsView()
    }
}
