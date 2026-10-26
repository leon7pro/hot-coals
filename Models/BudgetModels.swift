//
//  BudgetModels.swift
//  hot-coals
//
//  Created by Andrew Lewis on 9/30/26.
//

import Foundation
import SwiftUI
import SwiftData

@Model
final class MovieProject {
    var id: UUID
    var name: String
    var productionCompany: String
    var status: ProjectStatus
    var totalFunding: Double
    var startingCapital: Double = 0.0
    var lastModified: Date
    
    @Relationship(deleteRule: .cascade, inverse: \BudgetCategory.project)
    var categories: [BudgetCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \FundingSource.project)
    var fundingSources: [FundingSource] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ProductionWeek.project)
    var scheduleWeeks: [ProductionWeek] = []
    
    var totalCommittedFunding: Double {
        let sourcesSum = fundingSources.reduce(0) { $0 + $1.committedAmount }
        return sourcesSum > 0 ? sourcesSum : totalFunding
    }
    
    var totalReceivedFunding: Double {
        let sourcesSum = fundingSources.reduce(0) { $0 + $1.receivedAmount }
        return sourcesSum > 0 ? sourcesSum : totalFunding
    }
    
    var totalBudgetAmount: Double {
        categories.reduce(0) { $0 + $1.totalAmount }
    }
    
    var totalSpentAmount: Double {
        categories.reduce(0) { $0 + $1.totalSpent }
    }
    
    var remainingBalance: Double {
        totalReceivedFunding - totalSpentAmount
    }
    
    init(name: String, productionCompany: String = "", status: ProjectStatus = .development, totalFunding: Double = 0.0, startingCapital: Double = 0.0, lastModified: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.productionCompany = productionCompany
        self.status = status
        self.totalFunding = totalFunding
        self.startingCapital = startingCapital
        self.lastModified = lastModified
    }
}

@Model
final class ProductionWeek {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    
    var project: MovieProject?
    
    init(title: String, startDate: Date, endDate: Date, project: MovieProject? = nil) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.project = project
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case development = "Development"
    case preProduction = "Pre-Production"
    case production = "Production"
    case postProduction = "Post-Production"
    case distribution = "Distribution"
    case completed = "Completed"
    
    var color: Color {
        switch self {
        case .development: return .blue
        case .preProduction: return .orange
        case .production: return .red
        case .postProduction: return .purple
        case .distribution: return .indigo
        case .completed: return .green
        }
    }
}

@Model
final class FundingSource {
    var id: UUID
    var name: String
    var sourceType: FundingType
    var committedAmount: Double
    var receivedAmount: Double
    var expectedDate: Date
    var notes: String
    
    var project: MovieProject?
    
    init(name: String, sourceType: FundingType = .equity, committedAmount: Double, receivedAmount: Double = 0.0, expectedDate: Date = Date(), notes: String = "", project: MovieProject? = nil) {
        self.id = UUID()
        self.name = name
        self.sourceType = sourceType
        self.committedAmount = committedAmount
        self.receivedAmount = receivedAmount
        self.expectedDate = expectedDate
        self.notes = notes
        self.project = project
    }
}

enum FundingType: String, Codable, CaseIterable {
    case equity = "Equity / Investor"
    case taxIncentive = "Tax Incentive / Rebate"
    case softMoney = "Grant / Soft Money"
    case presale = "Presale / Distribution"
    case deferment = "Crew / Vendor Deferment"
    case debt = "Debt / Bridge Loan"
}

@Model
final class BudgetCategory {
    var id: UUID
    var number: String
    var desc: String
    
    var project: MovieProject?
    @Relationship(deleteRule: .cascade, inverse: \BudgetAccount.category)
    var accounts: [BudgetAccount] = []
    
    var totalAmount: Double {
        accounts.reduce(0) { $0 + $1.totalAmount }
    }
    
    var totalSpent: Double {
        accounts.reduce(0) { $0 + $1.totalSpent }
    }
    
    var remainingBalance: Double {
        totalAmount - totalSpent
    }
    
    init(number: String, desc: String, project: MovieProject? = nil) {
        self.id = UUID()
        self.number = number
        self.desc = desc
        self.project = project
    }
}

@Model
final class BudgetAccount {
    var id: UUID
    var number: String
    var desc: String
    var totalAmount: Double
    var originalAmount: Double
    var variance: Double
    
    var category: BudgetCategory?
    @Relationship(deleteRule: .cascade, inverse: \BudgetDetailItem.account)
    var detailItems: [BudgetDetailItem] = []
    
    var totalSpent: Double {
        detailItems.reduce(0) { $0 + $1.totalSpent }
    }
    
    var remainingBalance: Double {
        totalAmount - totalSpent
    }
    
    init(id: UUID = UUID(), number: String, desc: String, totalAmount: Double, originalAmount: Double, variance: Double, category: BudgetCategory? = nil) {
        self.id = id
        self.number = number
        self.desc = desc
        self.totalAmount = totalAmount
        self.originalAmount = originalAmount
        self.variance = variance
        self.category = category
    }
}

@Model
final class BudgetDetailItem {
    var id: UUID
    var itemDescription: String
    var amount: Double
    var unit: String
    var rate: Double
    var subtotal: Double
    var globalsUsed: [String]
    var fringesUsed: [String]
    
    var account: BudgetAccount?
    @Relationship(deleteRule: .cascade, inverse: \ExpenseTransaction.detailItem)
    var transactions: [ExpenseTransaction] = []
    
    var totalSpent: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var remainingBalance: Double {
        subtotal - totalSpent
    }
    
    init(itemDescription: String, amount: Double, unit: String, rate: Double, subtotal: Double, globalsUsed: [String] = [], fringesUsed: [String] = [], account: BudgetAccount? = nil) {
        self.id = UUID()
        self.itemDescription = itemDescription
        self.amount = amount
        self.unit = unit
        self.rate = rate
        self.subtotal = subtotal
        self.globalsUsed = globalsUsed
        self.fringesUsed = fringesUsed
        self.account = account
    }
}

@Model
final class ExpenseTransaction {
    var id: UUID
    var amount: Double
    var transactionDate: Date
    var expectedDate: Date
    var vendorName: String
    var note: String
    var isActual: Bool
    
    var detailItem: BudgetDetailItem?
    
    init(amount: Double, transactionDate: Date = Date(), expectedDate: Date = Date(), vendorName: String, note: String, isActual: Bool = true, detailItem: BudgetDetailItem? = nil) {
        self.id = UUID()
        self.amount = amount
        self.transactionDate = transactionDate
        self.expectedDate = expectedDate
        self.vendorName = vendorName
        self.note = note
        self.isActual = isActual
        self.detailItem = detailItem
    }
}
