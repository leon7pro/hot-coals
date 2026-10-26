//
//  BudgetViewModel.swift
//  hot-coals
//
//  Created by Andrew Lewis on 9/30/26.
//

import Foundation
import SwiftData

@Observable
final class BudgetViewModel {
    var sampleCategories: [BudgetCategory] = []
    
    init() {
        loadSampleData()
    }
    
    func loadSampleData() {
        let cat1 = BudgetCategory(number: "1100", desc: "Pre-Production")
        let account1 = BudgetAccount(number: "1101", desc: "Writer & Director", totalAmount: 60000.0, originalAmount: 60000.0, variance: 0.0)
        let detail1 = BudgetDetailItem(itemDescription: "Writer", amount: 1.0, unit: "LS", rate: 25000.0, subtotal: 25000.0, account: account1)
        let detail2 = BudgetDetailItem(itemDescription: "Director", amount: 1.0, unit: "LS", rate: 35000.0, subtotal: 35000.0, account: account1)
        account1.detailItems = [detail1, detail2]
        cat1.accounts = [account1]
        
        let cat2 = BudgetCategory(number: "1300", desc: "Cast")
        let account2 = BudgetAccount(number: "1301", desc: "Principal Cast", totalAmount: 70000.0, originalAmount: 70000.0, variance: 0.0)
        let detail3 = BudgetDetailItem(itemDescription: "Lead Actor", amount: 1.0, unit: "LS", rate: 50000.0, subtotal: 50000.0, account: account2)
        let detail4 = BudgetDetailItem(itemDescription: "Supporting Cast", amount: 1.0, unit: "LS", rate: 20000.0, subtotal: 20000.0, account: account2)
        account2.detailItems = [detail3, detail4]
        cat2.accounts = [account2]
        
        sampleCategories = [cat1, cat2]
    }
    
    func createSampleProject(modelContext: ModelContext) -> MovieProject {
        let project = MovieProject(name: "Bethesda", productionCompany: "Denton Film", status: .preProduction, totalFunding: 150000.0)
        
        let cat = BudgetCategory(number: "1100", desc: "Pre-Production", project: project)
        let account = BudgetAccount(number: "1101", desc: "Director", totalAmount: 35000.0, originalAmount: 35000.0, variance: 0.0, category: cat)
        let detail = BudgetDetailItem(itemDescription: "Director Fee", amount: 1.0, unit: "LS", rate: 35000.0, subtotal: 35000.0, account: account)
        
        account.detailItems = [detail]
        cat.accounts = [account]
        project.categories = [cat]
        
        modelContext.insert(project)
        try? modelContext.save()
        
        return project
    }
}
