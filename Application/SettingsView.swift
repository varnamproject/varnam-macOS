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

struct SettingsView: View {
    @ObservedObject var model = SettingsModel()

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    VStack(alignment: .leading, spacing: 18) {
                        Toggle(isOn: $model.learnWords) {
                            Text("Learn Words")
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Output logs to the console at")
                        MenuButton(model.logLevelString) {
                            ForEach(Logger.Level.allCases, id: \.self) { (level) in
                                Button(level.rawValue) { self.model.logLevelString = level.rawValue }
                            }
                        }
                        .fixedSize()
                        .padding(0)
                        Text("- Debug is most verbose and Fatal is least verbose")
                    }
                }
            }
            Spacer(minLength: 50)
            PersistenceView(model: model, context: "settings")
        }.padding(20)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
