//
//  hot_coalsApp.swift
//  hot-coals
//
//  Created by Andrew Lewis on 9/30/26.
//

import SwiftUI
import SwiftData

@main
struct hot_coalsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MovieProject.self,
            BudgetCategory.self,
            BudgetAccount.self,
            BudgetDetailItem.self,
            ExpenseTransaction.self,
            FundingSource.self,
            ProductionWeek.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ SWIFTDATA ERROR CAUGHT: \(error)")
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Unrecoverable ModelContainer error: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
