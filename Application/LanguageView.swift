/*
* VarnamApp is companion application for VarnamIME.
* Copyright (C) 2020 Ranganath Atreya
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

import SwiftUI
import LipikaEngine_OSX
import Carbon.HIToolbox.Events

class LanguageModel: ObservableObject, PersistenceModel {
    @Published var mappings: [LanguageConfig] {
        didSet {
            self.reeval()
        }
    }
    @Published var isDirty = false
    @Published var isFactory = false
    @Published var isValid = true
    let config = VarnamConfig()

    init() {
        mappings = config.languageConfig
        reeval()
    }
    
    private func reeval() {
        isDirty = mappings != config.languageConfig
        isFactory = config.languageConfig == config.factoryLanguageConfig
        isValid = !mappings.filter({ $0.isEnabled }).isEmpty
    }
    
    func save() {
        config.languageConfig = mappings
        let validScripts = config.languageConfig.filter({ $0.isEnabled }).map({ $0.identifier })
        if !validScripts.contains(config.schemeID) {
            config.schemeID = validScripts.first!
        }
        reeval()
    }
    
    func reload() {
        mappings = config.languageConfig
    }
    
    func reset() {
        config.resetLanguageConfig()
        reload()
    }
}

struct LanguageView: View {
    @ObservedObject var model = LanguageModel()
    @State var confirmDiscard = false
    @State var confirmReset = false

    var body: some View {
        VStack {
            LanguageTable(mappings: $model.mappings)
                .padding(16)
            Spacer(minLength: 10)
            PersistenceView(model: model, context: "language configuration")
            Spacer(minLength: 25)
        }
    }
}

struct LanguageView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageView()
    }
}
