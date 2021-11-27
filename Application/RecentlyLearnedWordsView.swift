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
    
    @Published var languages: [LanguageConfig];
    @Published var schemeID: String = "ml";
    @Published var schemeLangName: String = "Malayalam";
    
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
            varnam = try Varnam(schemeID)
        } catch let error {
            Logger.log.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    init() {
        Varnam.setVSTLookupDir(config.vstDir)
        
        // One language = One dictionary
        // Same language can have multiple schemes
        schemeID = config.schemeID
        languages = config.languageConfig
        
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
    
    func changeScheme(_ id: String) {
        schemeID = id
        schemeLangName = languages.first(where: { $0.identifier == schemeID })?.DisplayName ?? ""
        initVarnam()
        refreshWords()
    }
}

struct RecentlyLearnedWordsView: View {
    // Changes in model will automatically reload the table view
    @ObservedObject var model = RLWModel()

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Language: ")
                MenuButton(model.schemeLangName) {
                    ForEach(model.languages, id: \.self) { (lang) in
                        Button(lang.DisplayName) {
                            self.model.changeScheme(lang.identifier)
                        }
                    }
                }
                .fixedSize()
                .padding(0)
            }
            Spacer(minLength: 5)
            RLWTable(
                words: model.words,
                unlearn: model.unlearn
            )
        }.padding(16)
    }
}

struct RecentlyLearnedWordsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyLearnedWordsView()
    }
}
