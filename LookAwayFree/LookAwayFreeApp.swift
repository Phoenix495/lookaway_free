//
//  LookAwayFreeApp.swift
//  LookAwayFree
//
//  Created by Vitalii Serheiev on 30.04.2026.
//

import SwiftUI

@main
struct LookAwayFreeApp: App {
    var body: some Scene {
        MenuBarExtra("LookAwayFree", systemImage: "eye") {
            Text("Hello, menu bar")
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
