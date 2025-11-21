//
//  DaylightApp.swift
//  Daylight
//
//  Created by 张小森 on 2025/11/21.
//

import SwiftUI
import CoreData

@main
struct DaylightApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
