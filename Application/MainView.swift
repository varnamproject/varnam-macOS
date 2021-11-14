/*
* VarnamApp is companion application for VarnamIME.
* Copyright (C) 2020 Ranganath Atreya
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

import SwiftUI

struct MainView: View {
    @State private var currentTab = 0
    
    var body: some View {
        TabView(selection: $currentTab) {
            SettingsView().tabItem {
                Text("Settings")
            }.tag(2)
            .onAppear() {
                self.currentTab = 2
            }
            LanguageView().tabItem {
                Text("Languages")
            }.tag(3)
            .onAppear() {
                self.currentTab = 3
            }
            }.padding(20)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
