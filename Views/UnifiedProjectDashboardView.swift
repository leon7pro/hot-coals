//
//  UnifiedProjectDashboardView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/2/26.
//

import Foundation
import SwiftUI
import SwiftData

struct UnifiedProjectDashboardView: View {
    @Bindable var project: MovieProject
    @Environment(\.modelContext) private var modelContext
    
    @State private var newFundingAmount = ""
    @State private var selectedDetailItemForExpense: BudgetDetailItem?
    
    var totalBudget: Double {
        project.categories.reduce(0) { catSum, cat in
            catSum + cat.accounts.reduce(0) { acctSum, acct in
                acctSum + acct.totalAmount
            }
        }
    }
    
    var totalSpent: Double {
        project.categories.reduce(0) { catSum, cat in
            catSum + cat.accounts.reduce(0) { acctSum, acct in
                acctSum + acct.detailItems.reduce(0) { itemSum, item in
                    itemSum + item.totalSpent
                }
            }
        }
    }
    
    var remainingFunding: Double {
        project.totalFunding - totalSpent
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.largeTitle)
                        .bold()
                    Text("Produced by: \(project.productionCompany) | Status: \(project.status.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Financial Summary KPIs
                HStack(spacing: 15) {
                    UnifiedMetricCard(title: "Total Budget", amount: totalBudget, color: .blue)
                    UnifiedMetricCard(title: "Total Funding", amount: project.totalFunding, color: .green)
                    UnifiedMetricCard(title: "Total Spent", amount: totalSpent, color: .orange)
                    UnifiedMetricCard(title: "Remaining Cash", amount: remainingFunding, color: remainingFunding >= 0 ? .purple : .red)
                }
                
                // Funding Management Section
                GroupBox("Funding Management") {
                    HStack {
                        TextField("Add Funding Amount ($)", text: $newFundingAmount)
                            .textFieldStyle(.roundedBorder)
                        Button("Add Funds") {
                            if let val = Double(newFundingAmount) {
                                project.totalFunding += val
                                project.lastModified = Date()
                                try? modelContext.save()
                                newFundingAmount = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // Granular Budget Categories & Accounts Section
                GroupBox("Granular Budget Categories & Accounts") {
                    if project.categories.isEmpty {
                        ContentUnavailableView(
                            "No Budget Uploaded",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Go back to the project list and click the 'Upload' button to import your budget file.")
                        )
                        .frame(height: 150)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(project.categories.sorted(by: { $0.number < $1.number })) { category in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Category Header
                                    HStack {
                                        Text("Category: \(category.number) — \(category.desc)")
                                            .font(.headline)
                                            .bold()
                                        Spacer()
                                        Text("Total: $\(category.totalAmount, specifier: "%.2f")")
                                            .bold()
                                    }
                                    .padding(.vertical, 4)
                                    
                                    // Accounts List
                                    ForEach(category.accounts.sorted(by: { $0.number < $1.number })) { account in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(account.number)
                                                    .bold()
                                                    .frame(width: 50, alignment: .leading)
                                                Text(account.desc)
                                                    .bold()
                                                Spacer()
                                                Text("$\(account.totalAmount, specifier: "%.2f")")
                                                    .font(.subheadline)
                                                    .bold()
                                            }
                                            .padding(.leading, 12)
                                            
                                            // Detail Items under Account
                                            ForEach(account.detailItems) { detail in
                                                DetailItemRowView(
                                                    detailItem: detail,
                                                    onAddExpense: {
                                                        selectedDetailItemForExpense = detail
                                                    }
                                                )
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(project.name)
        .sheet(item: $selectedDetailItemForExpense) { detail in
            AddExpenseSheet(detailItem: detail, project: project)
        }
    }
}

// Individual Detail Item Row with Exact Code, Description, and Add Expense Button
struct DetailItemRowView: View {
    @Bindable var detailItem: BudgetDetailItem
    var onAddExpense: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(detailItem.itemDescription)
                    .font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Budget: $\(detailItem.subtotal, specifier: "%.2f")")
                        .font(.subheadline)
                    Text("Spent: $\(detailItem.totalSpent, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Remaining: $\(detailItem.remainingBalance, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(detailItem.remainingBalance >= 0 ? .green : .red)
                }
                
                Button(action: onAddExpense) {
                    Label("Add Expense", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .padding(.leading, 8)
            }
            
            // List transactions recorded for this detail item
            if !detailItem.transactions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expenses:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(detailItem.transactions) { tx in
                        HStack {
                            Text("• \(tx.vendorName)")
                                .font(.caption)
                            Spacer()
                            Text(tx.transactionDate, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("$\(tx.amount, specifier: "%.2f")")
                                .font(.caption)
                                .bold()
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 4)
    }
}

// Sheet popup to record an expense against a detail item
struct AddExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let detailItem: BudgetDetailItem
    let project: MovieProject
    
    @State private var vendorName = ""
    @State private var amount = ""
    @State private var note = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detail Item: \(detailItem.itemDescription)") {
                    TextField("Vendor/Expense Title (e.g., Equipment Rental)", text: $vendorName)
                    TextField("Amount ($)", text: $amount)
                    TextField("Note (Optional)", text: $note)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Record Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amt = Double(amount), !vendorName.isEmpty {
                            let tx = ExpenseTransaction(amount: amt, vendorName: vendorName, note: note, detailItem: detailItem)
                            modelContext.insert(tx)
                            detailItem.transactions.append(tx)
                            project.lastModified = Date()
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                    .disabled(vendorName.trimmingCharacters(in: .whitespaces).isEmpty || Double(amount) == nil)
                }
            }
            .frame(width: 450, height: 280)
        }
    }
}

struct UnifiedMetricCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("$\(amount, specifier: "%.2f")")
                .font(.title2)
                .bold()
                .foregroundStyle(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
        .cornerRadius(8)
    }
}
