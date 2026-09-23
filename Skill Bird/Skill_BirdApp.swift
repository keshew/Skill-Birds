//
//  Skill_BirdApp.swift
//  Skill Bird
//
//  Created by Артём Коротков on 17.09.2026.
//

import SwiftUI

@main
struct Skill_BirdApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
