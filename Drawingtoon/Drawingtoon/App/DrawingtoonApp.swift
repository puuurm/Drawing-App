//
//  DrawingtoonApp.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 9/21/25.
//

import SwiftUI
import SwiftData

// MARK: - App Entry
@main
struct DrawingToonApp: App {
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
        }
    }
}
