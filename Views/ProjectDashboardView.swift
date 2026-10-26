//
//  ProjectDashboardView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/23/26.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WeeklyBurnSummary: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
    var plannedBurn: Double
    var projectedInflow: Double
}

struct ProjectDashboardView: View {
    @Bindable var project: MovieProject
    @Environment(\.modelContext) private var modelContext
    @Binding var showingEditProjectSheet: Bool
    
    @State private var showingFileImporter = false
    @State private var importErrorMessage: String?
    @State private var showSaveNotification = false
    @State private var showStickyHeaderSection = true
    
    // Financing / Funding Tranche States
    @State private var showingAddFundingSheet = false
    @State private var fundingSourceToEdit: FundingSource? = nil
    @State private var fundingSourceToDelete: FundingSource? = nil
    @State private var showingDeleteFundingConfirmation = false
    @State private var isFinancingSectionExpanded = true
    
    @State private var newFundingName = ""
    @State private var newFundingType: FundingType = .equity
    @State private var newFundingCommitted = ""
    @State private var newFundingReceived = ""
    @State private var newFundingDate = Date()
    @State private var newFundingNotes = ""
    
    // Schedule / Production Week States
    @State private var showingAddWeekSheet = false
    @State private var weekToEdit: ProductionWeek? = nil
    @State private var weekToDelete: ProductionWeek? = nil
    @State private var showingDeleteWeekConfirmation = false
    
    @State private var newWeekTitle = ""
    @State private var newWeekStartDate = Date()
    @State private var newWeekEndDate = Date().addingTimeInterval(86400 * 7)
    
    // Action sheets state for Detail Items
    @State private var detailItemToEditBudget: BudgetDetailItem? = nil
    @State private var budgetAmountInput: String = ""
    
    @State private var detailItemToAddSpend: BudgetDetailItem? = nil
    @State private var spendAmountInput: String = ""
    @State private var spendDescInput: String = ""
    @State private var expectedSpendDate: Date = Date()
    @State private var actualSpendCalendarDate: Date = Date()
    @State private var isActualExpense: Bool = true
    
    // Zero-Budget Visibility Toggle State
    @State private var showZeroBudgetItems: Bool = true

    // Collapsed Category & Account Expansion State
    @State private var expandedCategoryIDs: Set<String> = []
    @State private var expandedAccountIDs: Set<String> = []
    
    // Sheet state for viewing full fringe breakdown
    @State private var showingFringeSheet: Bool = false

    private func categoryBudgetTotal(for cat: BudgetCategory) -> Double {
        let catNum = cat.number
         
        if catNum == "9001" || catNum == "9002" {
            return 0.0
        } else if catNum == "10000" || cat.desc.lowercased().contains("contingency") {
            let directSum = cat.accounts.reduce(0.0) { acctSum, acct in
                let detailsSum = acct.detailItems.reduce(0.0) { $0 + $1.subtotal }
                return acctSum + (acct.totalAmount > 0 ? acct.totalAmount : detailsSum)
            }
            if directSum > 0 { return directSum }
            return calculatedContingencyAmount
        }

        let accountsSum = cat.accounts.reduce(0.0) { acctSum, acct in
            let detailsSum = acct.detailItems.reduce(0.0) { $0 + $1.subtotal }
            return acctSum + (acct.totalAmount > 0 ? acct.totalAmount : detailsSum)
        }
         
        if accountsSum > 0 { return accountsSum }
         
        let flatDetailsSum = cat.accounts.flatMap { $0.detailItems }.reduce(0.0) { $0 + $1.subtotal }
        if flatDetailsSum > 0 { return flatDetailsSum }
         
        return cat.totalAmount > 0 ? cat.totalAmount : 0.0
    }

    var subtotalBudget: Double {
        project.categories
            .filter { cat in
                let catNum = cat.number
                let desc = cat.desc.lowercased()
                let isContingency = catNum == "10000" || desc.contains("contingency")
                let isFringeCat = catNum == "9001" || catNum == "9002"
                return !isContingency && !isFringeCat
            }
            .reduce(0) { catSum, cat in
                catSum + categoryBudgetTotal(for: cat)
            }
    }

    var calculatedContingencyAmount: Double {
        if let contingencyCat = project.categories.first(where: { $0.number == "10000" || $0.desc.lowercased().contains("contingency") }) {
            let catTotal = contingencyCat.accounts.reduce(0.0) { aSum, acct in
                let dSum = acct.detailItems.reduce(0.0) { $0 + $1.subtotal }
                return aSum + (acct.totalAmount > 0 ? acct.totalAmount : dSum)
            }
            if catTotal > 0 { return catTotal }
        }

        var eligibleSubtotal = 0.0
        for cat in project.categories {
            let catNum = Int(cat.number) ?? 0
            let isProductionAccountRange = (catNum >= 1000 && catNum < 9000)
            guard isProductionAccountRange else { continue }
             
            for acct in cat.accounts {
                let acctTotal = acct.totalAmount > 0 ? acct.totalAmount : acct.detailItems.reduce(0.0) { $0 + $1.subtotal }
                if acctTotal > 0 {
                    eligibleSubtotal += acctTotal
                } else {
                    for detail in acct.detailItems {
                        eligibleSubtotal += detail.subtotal
                    }
                }
            }
        }

        let declaredPercentage = 1.1
        return eligibleSubtotal * (declaredPercentage / 100.0)
    }

    var fringeLineItems: [BudgetLineItem] {
        var items: [BudgetLineItem] = []
        for cat in project.categories {
            let catNumVal = Int(cat.number) ?? 0
            let isContingency = cat.number == "10000" || cat.desc.lowercased().contains("contingency") || catNumVal >= 10000
            let isFringeCategory = cat.number == "9001" || cat.number == "9002" || catNumVal >= 9000
             
            if isContingency || isFringeCategory { continue }
             
            for acct in cat.accounts {
                let acctNumVal = Int(acct.number) ?? 0
                guard acctNumVal >= 1000 && acctNumVal < 9000 else { continue }
                 
                for detail in acct.detailItems {
                    let lineItem = BudgetLineItem(
                        accountNumber: acct.number,
                        description: detail.itemDescription,
                        department: cat.desc,
                        subTotal: detail.subtotal,
                        amount: detail.amount,
                        isEligibleForFringes: true,
                        globalsUsed: detail.globalsUsed,
                        fringesUsed: detail.fringesUsed
                    )
                    items.append(lineItem)
                }
            }
        }
        return items
    }

    private var fringeCalculationResult: FringeCalculationResult {
        BudgetFringeCalculator.calculateFringes(for: fringeLineItems)
    }

    var totalBudget: Double {
        subtotalBudget + calculatedContingencyAmount + fringeCalculationResult.grandTotalFringes
    }

    var totalActualSpend: Double {
        var sum = 0.0
        for cat in project.categories {
            for acct in cat.accounts {
                for item in acct.detailItems {
                    for tx in item.transactions where tx.isActual {
                        sum += tx.amount
                    }
                }
            }
        }
        return sum
    }
    
    var totalExpectedCommitted: Double {
        var sum = 0.0
        for cat in project.categories {
            for acct in cat.accounts {
                for item in acct.detailItems {
                    for tx in item.transactions {
                        sum += tx.amount
                    }
                }
            }
        }
        return sum
    }

    var calculatedFringesPaid: Double {
        var paid: Double = 0.0
        for item in fringeLineItems {
            if let detail = findDetailItem(for: item) {
                let ratio = detail.subtotal > 0 ? min(1.0, detail.totalSpent / detail.subtotal) : 0.0
                let singleList = [item]
                let itemFringes = BudgetFringeCalculator.calculateFringes(for: singleList).grandTotalFringes
                paid += itemFringes * ratio
            }
        }
        return paid
    }

    var calculatedFringesOwed: Double {
        max(0.0, fringeCalculationResult.grandTotalFringes - calculatedFringesPaid)
    }

    private func findDetailItem(for lineItem: BudgetLineItem) -> BudgetDetailItem? {
        for cat in project.categories {
            for acct in cat.accounts {
                if acct.number == lineItem.accountNumber {
                    if let detail = acct.detailItems.first(where: { $0.itemDescription == lineItem.description }) {
                        return detail
                    }
                }
            }
        }
        return nil
    }

    var remainingCash: Double {
        project.totalReceivedFunding - totalActualSpend
    }

    var weeklyBurnSchedules: [WeeklyBurnSummary] {
        let sortedWeeks = project.scheduleWeeks.sorted { $0.startDate < $1.startDate }
        var summaries = sortedWeeks.map { week in
            WeeklyBurnSummary(
                title: week.title,
                startDate: week.startDate,
                endDate: week.endDate,
                plannedBurn: 0.0,
                projectedInflow: 0.0
            )
        }
         
        if summaries.isEmpty { return [] }
         
        for cat in project.categories {
            for acct in cat.accounts {
                for detail in acct.detailItems {
                    for tx in detail.transactions {
                        if let index = summaries.firstIndex(where: { tx.expectedDate >= $0.startDate && tx.expectedDate <= $0.endDate }) {
                            summaries[index].plannedBurn += tx.amount
                        } else if let firstWeek = summaries.first, tx.expectedDate < firstWeek.startDate {
                            summaries[0].plannedBurn += tx.amount
                        } else if let lastWeek = summaries.last, tx.expectedDate > lastWeek.endDate {
                            summaries[summaries.count - 1].plannedBurn += tx.amount
                        }
                    }
                }
            }
        }
         
        for source in project.fundingSources {
            if let index = summaries.firstIndex(where: { source.expectedDate >= $0.startDate && source.expectedDate <= $0.endDate }) {
                summaries[index].projectedInflow += source.committedAmount
            }
        }
         
        return summaries
    }

    // MARK: - Extracted Subviews
    
    var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.largeTitle)
                    .bold()
                 
                HStack(spacing: 8) {
                    Text(project.productionCompany.isEmpty ? "Denton Film LLC" : project.productionCompany)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                     
                    Circle()
                        .fill(project.status.color)
                        .frame(width: 8, height: 8)
                    Text(project.status.rawValue)
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(project.status.color.opacity(0.15))
                        .foregroundStyle(project.status.color)
                        .clipShape(Capsule())
                }
            }
            Spacer()
             
            HStack(spacing: 12) {
                Button(action: { showingEditProjectSheet = true }) {
                    Label("Edit Project", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .font(.subheadline)

                Button(action: {
                    withAnimation {
                        showStickyHeaderSection.toggle()
                    }
                }) {
                    Label(showStickyHeaderSection ? "Hide Header Section" : "Show Header Section", systemImage: showStickyHeaderSection ? "eye.slash" : "eye")
                }
                .buttonStyle(.bordered)
                .font(.subheadline)

                Toggle("Show Zero Items", isOn: $showZeroBudgetItems)
                    .toggleStyle(.checkbox)
                    .font(.subheadline)

                Button(action: { showingFileImporter = true }) {
                    Label("Import Budget File", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    var metricsCardsView: some View {
        HStack(spacing: 16) {
            MetricCard(title: "Total Budget", amount: totalBudget, color: .blue)
            MetricCard(title: "Committed Funding", amount: project.totalCommittedFunding, color: .green)
            MetricCard(title: "Actual Spend", amount: totalActualSpend, color: .orange)
            MetricCard(title: "Projected Burn", amount: totalExpectedCommitted, color: .indigo)
            MetricCard(title: "Remaining Cash", amount: remainingCash, color: remainingCash >= 0 ? .purple : .red)
        }
    }
    
    @ViewBuilder
    private func scheduleWeekCardView(for week: ProductionWeek, index: Int, schedules: [WeeklyBurnSummary], runningCashBalance: Double, today: Date) -> some View {
        let summary = schedules.indices.contains(index) ? schedules[index] : WeeklyBurnSummary(title: week.title, startDate: week.startDate, endDate: week.endDate, plannedBurn: 0.0, projectedInflow: 0.0)
        let netCashFlow = summary.projectedInflow - summary.plannedBurn
        let isDeficit = runningCashBalance + netCashFlow < 0
        let isCurrentWeek = today >= week.startDate && today <= week.endDate
         
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isCurrentWeek {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Text(week.title)
                    .font(.caption)
                    .bold()
                Spacer()
                 
                Button(action: {
                    weekToEdit = week
                    newWeekTitle = week.title
                    newWeekStartDate = week.startDate
                    newWeekEndDate = week.endDate
                    showingAddWeekSheet = true
                }) {
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                 
                Button(role: .destructive, action: {
                    weekToDelete = week
                    showingDeleteWeekConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
             
            Text("\(week.startDate, format: .dateTime.month(.abbreviated).day()) - \(week.endDate, format: .dateTime.month(.abbreviated).day())")
                .font(.caption2)
                .foregroundStyle(.secondary)
             
            Divider()
                .padding(.vertical, 1)
             
            VStack(alignment: .leading, spacing: 2) {
                Text("Burn: $\(summary.plannedBurn, specifier: "%.2f")")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                 
                Text("Inflow: $\(summary.projectedInflow, specifier: "%.2f")")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
             
            if isDeficit {
                Label("Crunch", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.red)
                    .cornerRadius(3)
            }
        }
        .frame(width: 155, height: 110)
        .padding(10)
        .background(isCurrentWeek ? Color.yellow.opacity(0.12) : (isDeficit ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1)))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentWeek ? Color.yellow : (isDeficit ? Color.red : Color.clear), lineWidth: isCurrentWeek ? 2.0 : 1.5)
        )
    }

    var scheduleRunwayView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Production Schedule & Weekly Burn Runway")
                        .font(.headline)
                    Text("Individually edit schedule weeks, track burn, and view projected funding inflows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    weekToEdit = nil
                    newWeekTitle = "Shoot Week \(project.scheduleWeeks.count + 1)"
                    newWeekStartDate = Date()
                    newWeekEndDate = Date().addingTimeInterval(86400 * 7)
                    showingAddWeekSheet = true
                }) {
                    Label("Add Week", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
             
            if project.scheduleWeeks.isEmpty {
                HStack {
                    Text("No schedule weeks added yet. Add custom weeks to track weekly burn.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Generate Default 8-Week Schedule") {
                        Task {
                            await MainActor.run {
                                let calendar = Calendar.current
                                let baseDate = Date()
                                for i in 0..<4 {
                                    let sDate = calendar.date(byAdding: .weekOfYear, value: i, to: baseDate)!
                                    let eDate = calendar.date(byAdding: .day, value: 7, to: sDate)!
                                    let wk = ProductionWeek(title: "Prep Week \(i + 1)", startDate: sDate, endDate: eDate, project: project)
                                    modelContext.insert(wk)
                                    project.scheduleWeeks.append(wk)
                                }
                                for i in 0..<4 {
                                    let sDate = calendar.date(byAdding: .weekOfYear, value: i + 4, to: baseDate)!
                                    let eDate = calendar.date(byAdding: .day, value: 7, to: sDate)!
                                    let wk = ProductionWeek(title: "Shoot Week \(i + 1)", startDate: sDate, endDate: eDate, project: project)
                                    modelContext.insert(wk)
                                    project.scheduleWeeks.append(wk)
                                }
                                project.lastModified = Date()
                                try? modelContext.save()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding()
                .background(.background.secondary)
                .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        let schedules = weeklyBurnSchedules
                        let runningCashBalance = project.totalReceivedFunding
                        let today = Date()
                         
                        ForEach(Array(project.scheduleWeeks.sorted { $0.startDate < $1.startDate }.enumerated()), id: \.element.id) { index, week in
                            scheduleWeekCardView(for: week, index: index, schedules: schedules, runningCashBalance: runningCashBalance, today: today)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(10)
        .confirmationDialog("Are you sure you want to delete this schedule week?", isPresented: $showingDeleteWeekConfirmation, titleVisibility: .visible) {
            Button("Delete Week", role: .destructive) {
                if let wk = weekToDelete {
                    modelContext.delete(wk)
                    project.lastModified = Date()
                    try? modelContext.save()
                    weekToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { weekToDelete = nil }
        }
    }
    
    var payrollFringesSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Payroll Fringes Summary")
                Spacer()
                Button("View Breakdown") {
                    showingFringeSheet = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
             
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("ATL Fringes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fringeCalculationResult.atlFringesTotal, format: .currency(code: "USD"))
                        .font(.headline)
                }
                Divider()
                VStack(alignment: .leading) {
                    Text("BTL Fringes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fringeCalculationResult.btlFringesTotal, format: .currency(code: "USD"))
                        .font(.headline)
                }
                Divider()
                VStack(alignment: .leading) {
                    Text("Fringes Paid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(calculatedFringesPaid, format: .currency(code: "USD"))
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                Divider()
                VStack(alignment: .leading) {
                    Text("Fringes Owed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(calculatedFringesOwed, format: .currency(code: "USD"))
                        .font(.headline)
                        .foregroundStyle(.purple)
                }
                Divider()
                VStack(alignment: .leading) {
                    Text("Total Fringes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fringeCalculationResult.grandTotalFringes, format: .currency(code: "USD"))
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func fundingSourceRowView(for source: FundingSource) -> some View {
        let now = Date()
        let isFunded = source.receivedAmount >= source.committedAmount && source.committedAmount > 0
        let isOverdue = source.expectedDate <= now && source.receivedAmount < source.committedAmount
         
        let borderColor: Color = isFunded ? .green : (isOverdue ? .red : .blue)
        let badgeText: String = isFunded ? "Funded" : (isOverdue ? "Overdue / Unfunded" : "Pending")
         
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(source.name)
                        .bold()
                    Text(badgeText)
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(borderColor.opacity(0.15))
                        .foregroundStyle(borderColor)
                        .cornerRadius(4)
                }
                Text(source.sourceType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
             
            Spacer()
             
            VStack(alignment: .trailing, spacing: 2) {
                Text("Committed: $\(source.committedAmount, specifier: "%.2f")")
                    .font(.subheadline)
                    .bold()
                Text("Received (Cash): $\(source.receivedAmount, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Expected: \(source.expectedDate, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
             
            Button(action: {
                fundingSourceToEdit = source
                newFundingName = source.name
                newFundingType = source.sourceType
                newFundingCommitted = String(source.committedAmount)
                newFundingReceived = String(source.receivedAmount)
                newFundingDate = source.expectedDate
                newFundingNotes = source.notes
                showingAddFundingSheet = true
            }) {
                Image(systemName: "pencil")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
             
            Button(role: .destructive, action: {
                fundingSourceToDelete = source
                showingDeleteFundingConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1.5)
        )
    }

    var financingStackView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isFinancingSectionExpanded.toggle() }) {
                HStack {
                    Image(systemName: isFinancingSectionExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Financing & Capital Stack")
                            .font(.headline)
                        Text("Track equity, tax incentives, soft money, and cash-in-bank status.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        fundingSourceToEdit = nil
                        newFundingName = ""
                        newFundingType = .equity
                        newFundingCommitted = ""
                        newFundingReceived = ""
                        newFundingDate = Date()
                        newFundingNotes = ""
                        showingAddFundingSheet = true
                    }) {
                        Label("Add Funding Source", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .buttonStyle(.plain)
             
            if isFinancingSectionExpanded {
                if project.fundingSources.isEmpty {
                    HStack {
                        Text("No dedicated funding sources added yet. Total operating capital is currently pegged at: $\(project.totalFunding, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Migrate to Tranches") {
                            Task {
                                await MainActor.run {
                                    let initial = FundingSource(
                                        name: "Initial Capital / Bridge",
                                        sourceType: .equity,
                                        committedAmount: project.totalFunding,
                                        receivedAmount: project.totalFunding,
                                        project: project
                                    )
                                    modelContext.insert(initial)
                                    project.fundingSources.append(initial)
                                    try? modelContext.save()
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding()
                    .background(.background.secondary)
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        let sortedSources = project.fundingSources.sorted { $0.expectedDate > $1.expectedDate }
                         
                        ForEach(sortedSources) { source in
                            fundingSourceRowView(for: source)
                        }
                         
                        HStack {
                            Text("Total Capital Stack:")
                                .bold()
                            Spacer()
                            Text("Committed: $\(project.totalCommittedFunding, specifier: "%.2f")")
                                .bold()
                            Text("• Cash Received: $\(project.totalReceivedFunding, specifier: "%.2f")")
                                .bold()
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(10)
        .confirmationDialog("Are you sure you want to delete this funding source?", isPresented: $showingDeleteFundingConfirmation, titleVisibility: .visible) {
            Button("Delete Source", role: .destructive) {
                if let source = fundingSourceToDelete {
                    modelContext.delete(source)
                    project.lastModified = Date()
                    try? modelContext.save()
                    fundingSourceToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { fundingSourceToDelete = nil }
        }
    }
    
    @ViewBuilder
    private func transactionRowView(for tx: ExpenseTransaction) -> some View {
        HStack {
            Text("• \(tx.vendorName) (\(tx.isActual ? "Actual Paid" : "Expected / Pending"))")
                .font(.caption)
            Spacer()
            Text("Exp: \(tx.expectedDate, style: .date)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if tx.isActual {
                Text("Paid: \(tx.transactionDate, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Button("Mark Paid") {
                    Task {
                        await MainActor.run {
                            tx.isActual = true
                            tx.transactionDate = Date()
                            project.lastModified = Date()
                            try? modelContext.save()
                        }
                    }
                }
                .font(.caption2)
                .buttonStyle(.borderedProminent)
            }
            Text("$\(tx.amount, specifier: "%.2f")")
                .font(.caption)
                .bold()
        }
        .padding(.leading, 40)
    }

    @ViewBuilder
    private func detailItemRowView(for detail: BudgetDetailItem) -> some View {
        let remainingDetail = detail.subtotal - detail.totalSpent
        
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(detail.itemDescription)
                    .font(.caption)
                Spacer()
                 
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Qty: \(detail.amount, specifier: "%.1f") \(detail.unit) @ $\(detail.rate, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Subtotal: $\(detail.subtotal, specifier: "%.2f") | Spent: $\(detail.totalSpent, specifier: "%.2f")")
                        .font(.caption)
                        .bold()
                    Text("Remaining: $\(remainingDetail, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundStyle(remainingDetail >= 0 ? .green : .red)
                }
                 
                Button(action: {
                    detailItemToEditBudget = detail
                    budgetAmountInput = String(detail.subtotal)
                }) {
                    Label("Edit Budget", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                 
                Button(action: {
                    detailItemToAddSpend = detail
                    spendAmountInput = ""
                    spendDescInput = ""
                    expectedSpendDate = Date()
                    actualSpendCalendarDate = Date()
                    isActualExpense = true
                }) {
                    Label("Add Expense", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.leading, 32)
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            if !detail.transactions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scheduled / Recorded Expenses:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(detail.transactions) { tx in
                        transactionRowView(for: tx)
                    }
                }
                .padding(.leading, 32)
            }
        }
        Divider()
    }

    @ViewBuilder
    private func accountRowsView(for account: BudgetAccount) -> some View {
        let acctId = account.persistentModelID.hashValue.description
        let isAccountExpanded = expandedAccountIDs.contains(acctId)
         
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                if isAccountExpanded {
                    expandedAccountIDs.remove(acctId)
                } else {
                    expandedAccountIDs.insert(acctId)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: isAccountExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(account.number)
                        .bold()
                        .frame(width: 50, alignment: .leading)
                    Text(account.desc)
                        .bold()
                    Spacer()
                    let acctTotal = account.totalAmount > 0 ? account.totalAmount : account.detailItems.reduce(0.0) { $0 + $1.subtotal }
                    let acctSpend = account.totalSpent
                    Text("Acct Budget: $\(acctTotal, specifier: "%.2f") | Spent: $\(acctSpend, specifier: "%.2f")")
                        .font(.caption)
                        .bold()
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.vertical, 4)
             
            if isAccountExpanded {
                ForEach(account.detailItems) { detail in
                    detailItemRowView(for: detail)
                }
            }
        }
    }

    var granularBudgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Granular Budget Categories & Line Items")
                .font(.headline)
             
            if project.categories.isEmpty {
                ContentUnavailableView(
                    "No Budget Data",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Import a Movie Magic Budget (.mmb), XML, or CSV file to populate categories and line items for this project.")
                )
                .frame(height: 200)
            } else {
                let filteredCategories = project.categories.filter { cat in
                    let catNum = cat.number
                    if catNum == "9001" || catNum == "9002" { return false }
                     
                    let isContingency = catNum == "10000" || cat.desc.lowercased().contains("contingency")
                    let catTotal: Double = isContingency ? calculatedContingencyAmount : categoryBudgetTotal(for: cat)
                     
                    if showZeroBudgetItems { return true }
                    let catSpend = cat.totalSpent
                    return catTotal > 0.0 || catSpend > 0.0
                }
                 
                ForEach(filteredCategories.sorted { cat1, cat2 in
                    let num1 = Int(cat1.number) ?? 99999
                    let num2 = Int(cat2.number) ?? 99999
                    return num1 < num2
                }) { cat in
                    let isContingencyCategory = cat.number == "10000" || cat.desc.lowercased().contains("contingency")
                    let catId = cat.persistentModelID.hashValue.description
                    let isExpanded = expandedCategoryIDs.contains(catId)
                     
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            if isExpanded {
                                expandedCategoryIDs.remove(catId)
                            } else {
                                expandedCategoryIDs.insert(catId)
                            }
                        }) {
                            HStack {
                                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .foregroundStyle(.secondary)
                                 
                                let headerText = cat.number.isEmpty
                                    ? "Category: \(cat.desc.uppercased())"
                                    : "Category: \(cat.number) — \(cat.desc.uppercased())"
                                 
                                Text(headerText)
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(.primary)
                                Spacer()
                                 
                                let catTotal: Double = isContingencyCategory ? calculatedContingencyAmount : categoryBudgetTotal(for: cat)
                                let catSpend = cat.totalSpent
                                let catRemaining = catTotal - catSpend
                                 
                                HStack(spacing: 16) {
                                    Text("Budget: $\(catTotal, specifier: "%.2f")")
                                        .font(.subheadline)
                                    Text("Spend: $\(catSpend, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                    Text("Remaining: $\(catRemaining, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(catRemaining >= 0 ? .green : .red)
                                }
                                .bold()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.secondary.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                         
                        if isExpanded {
                            let displayAccounts: [BudgetAccount] = {
                                if isContingencyCategory && cat.accounts.isEmpty {
                                    let defaultAcct = BudgetAccount(number: "10000", desc: "Contingency Reserve", totalAmount: calculatedContingencyAmount, originalAmount: calculatedContingencyAmount, variance: 0.0, category: cat)
                                    let defaultDetail = BudgetDetailItem(itemDescription: "General Contingency", amount: 1.0, unit: "LS", rate: calculatedContingencyAmount, subtotal: calculatedContingencyAmount, account: defaultAcct)
                                    defaultAcct.detailItems = [defaultDetail]
                                    return [defaultAcct]
                                }
                                return cat.accounts
                            }()
                             
                            ForEach(displayAccounts.sorted { Int($0.number) ?? 0 < Int($1.number) ?? 0 }) { account in
                                accountRowsView(for: account)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Main Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                    // Pinned Sticky Header View
                    Section {
                        if showStickyHeaderSection {
                            VStack(alignment: .leading, spacing: 20) {
                                metricsCardsView
                                scheduleRunwayView
                            }
                        }
                    } header: {
                        VStack(spacing: 0) {
                            headerView
                                .padding(.vertical, 12)
                                .background(.background)
                            Divider()
                        }
                    }
                     
                    VStack(alignment: .leading, spacing: 20) {
                        payrollFringesSummaryView
                        financingStackView
                        granularBudgetView
                    }
                }
                .padding()
            }
             
            if showSaveNotification {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Project Saved Successfully")
                        .font(.subheadline)
                        .bold()
                }
                .padding(12)
                .background(.background)
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(16)
                .transition(.opacity)
            }
        }
        .id(project.persistentModelID)
        .navigationTitle(project.name)
        .onChange(of: project.name) { _, _ in
            project.lastModified = Date()
            try? modelContext.save()
        }
        .onChange(of: project.status) { _, _ in
            project.lastModified = Date()
            try? modelContext.save()
        }
        .onAppear {
            for cat in project.categories {
                let catNum = cat.number
                let isContingency = catNum == "10000" || cat.desc.lowercased().contains("contingency")
                if isContingency && cat.accounts.isEmpty {
                    let defaultAcct = BudgetAccount(number: "10000", desc: "Contingency Reserve", totalAmount: calculatedContingencyAmount, originalAmount: calculatedContingencyAmount, variance: 0.0, category: cat)
                    modelContext.insert(defaultAcct)
                    let defaultDetail = BudgetDetailItem(itemDescription: "General Contingency", amount: 1.0, unit: "LS", rate: calculatedContingencyAmount, subtotal: calculatedContingencyAmount, account: defaultAcct)
                    modelContext.insert(defaultDetail)
                    defaultAcct.detailItems = [defaultDetail]
                    cat.accounts = [defaultAcct]
                    try? modelContext.save()
                }
            }
        }
        .background(
            Button("") {
                project.lastModified = Date()
                try? modelContext.save()
                withAnimation {
                    showSaveNotification = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showSaveNotification = false
                    }
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .hidden()
        )
        .sheet(isPresented: $showingFringeSheet) {
            NavigationView {
                FringeSummaryView(lineItems: fringeLineItems)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingFringeSheet = false }
                        }
                    }
            }
            .frame(minWidth: 500, idealWidth: 550, minHeight: 450, idealHeight: 500)
        }
        .sheet(isPresented: $showingAddFundingSheet) {
            VStack(spacing: 16) {
                Text(fundingSourceToEdit == nil ? "Add Financing Tranche" : "Edit Financing Tranche")
                    .font(.headline)
                 
                TextField("Source Name (e.g., Texas Film Incentive)", text: $newFundingName)
                    .textFieldStyle(.roundedBorder)
                 
                Picker("Funding Type", selection: $newFundingType) {
                    ForEach(FundingType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                 
                TextField("Committed Amount ($)", text: $newFundingCommitted)
                    .textFieldStyle(.roundedBorder)
                 
                TextField("Received / Banked Amount ($)", text: $newFundingReceived)
                    .textFieldStyle(.roundedBorder)
                 
                DatePicker("Expected Funds Date", selection: $newFundingDate, displayedComponents: .date)
                 
                TextField("Notes / Terms", text: $newFundingNotes)
                    .textFieldStyle(.roundedBorder)
                 
                HStack {
                    Button("Cancel") {
                        showingAddFundingSheet = false
                        fundingSourceToEdit = nil
                    }
                    .buttonStyle(.bordered)
                     
                    Button("Save Source") {
                        let committed = parseCurrency(newFundingCommitted)
                        let received = parseCurrency(newFundingReceived)
                         
                        if committed > 0 || received > 0 {
                            Task {
                                await MainActor.run {
                                    if let source = fundingSourceToEdit {
                                        source.name = newFundingName.isEmpty ? newFundingType.rawValue : newFundingName
                                        source.sourceType = newFundingType
                                        source.committedAmount = committed
                                        source.receivedAmount = received
                                        source.expectedDate = newFundingDate
                                        source.notes = newFundingNotes
                                    } else {
                                        let source = FundingSource(
                                            name: newFundingName.isEmpty ? newFundingType.rawValue : newFundingName,
                                            sourceType: newFundingType,
                                            committedAmount: committed,
                                            receivedAmount: received,
                                            expectedDate: newFundingDate,
                                            notes: newFundingNotes,
                                            project: project
                                        )
                                        modelContext.insert(source)
                                        project.fundingSources.append(source)
                                    }
                                    project.lastModified = Date()
                                    try? modelContext.save()
                                     
                                    showingAddFundingSheet = false
                                    fundingSourceToEdit = nil
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 420, height: 420)
        }
        .sheet(isPresented: $showingAddWeekSheet) {
            VStack(spacing: 16) {
                Text(weekToEdit == nil ? "Add Schedule Week" : "Edit Schedule Week")
                    .font(.headline)
                 
                TextField("Week Label (e.g., Pickup Shoot, Weather Hold)", text: $newWeekTitle)
                    .textFieldStyle(.roundedBorder)
                 
                DatePicker("Start Date", selection: $newWeekStartDate, displayedComponents: .date)
                DatePicker("End Date", selection: $newWeekEndDate, displayedComponents: .date)
                 
                HStack {
                    Button("Cancel") {
                        showingAddWeekSheet = false
                        weekToEdit = nil
                    }
                    .buttonStyle(.bordered)
                     
                    Button("Save Week") {
                        if !newWeekTitle.isEmpty {
                            Task {
                                await MainActor.run {
                                    if let wk = weekToEdit {
                                        wk.title = newWeekTitle
                                        wk.startDate = newWeekStartDate
                                        wk.endDate = newWeekEndDate
                                    } else {
                                        let wk = ProductionWeek(
                                            title: newWeekTitle,
                                            startDate: newWeekStartDate,
                                            endDate: newWeekEndDate,
                                            project: project
                                        )
                                        modelContext.insert(wk)
                                        project.scheduleWeeks.append(wk)
                                    }
                                    project.lastModified = Date()
                                    try? modelContext.save()
                                     
                                    showingAddWeekSheet = false
                                    weekToEdit = nil
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 380, height: 280)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.xml, .commaSeparatedText, .plainText, UTType(filenameExtension: "mmb") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile = try result.get().first else { return }
                if selectedFile.startAccessingSecurityScopedResource() {
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: selectedFile)
                    let filename = selectedFile.lastPathComponent.lowercased()
                    Task {
                        await MainActor.run {
                            do {
                                if filename.hasSuffix(".csv") {
                                    try parseCSVBudget(data: data, into: project)
                                } else {
                                    try parseXMLBudget(data: data, into: project)
                                }
                            } catch {
                                importErrorMessage = "Could not parse file: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            } catch {
                importErrorMessage = "Could not read file.\n\nDetails: \(error.localizedDescription)"
            }
        }
        .sheet(item: $detailItemToEditBudget) { item in
            VStack(spacing: 16) {
                Text("Edit Subtotal for \(item.itemDescription)")
                    .font(.headline)
                TextField("Subtotal Amount ($)", text: $budgetAmountInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { detailItemToEditBudget = nil; budgetAmountInput = "" }
                        .buttonStyle(.bordered)
                    Button("Save Budget") {
                        let amt = parseCurrency(budgetAmountInput)
                        if amt >= 0 {
                            Task {
                                await MainActor.run {
                                    item.subtotal = amt
                                    project.lastModified = Date()
                                    try? modelContext.save()
                                    detailItemToEditBudget = nil
                                    budgetAmountInput = ""
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 350, height: 180)
        }
        .sheet(item: $detailItemToAddSpend) { item in
            VStack(spacing: 16) {
                Text("Record Expense / Expected Burn for \(item.itemDescription)")
                    .font(.headline)
                TextField("Vendor/Expense Title", text: $spendDescInput)
                    .textFieldStyle(.roundedBorder)
                TextField("Amount ($)", text: $spendAmountInput)
                    .textFieldStyle(.roundedBorder)
                Toggle("Is Actual (Paid)", isOn: $isActualExpense)
                    .font(.subheadline)
                DatePicker("Expected Payment Date", selection: $expectedSpendDate, displayedComponents: .date)
                if isActualExpense {
                    DatePicker("Actual Paid Date", selection: $actualSpendCalendarDate, displayedComponents: .date)
                }
                HStack {
                    Button("Cancel") { detailItemToAddSpend = nil; spendAmountInput = ""; spendDescInput = "" }
                        .buttonStyle(.bordered)
                    Button("Save Expense") {
                        let amt = parseCurrency(spendAmountInput)
                        if amt > 0 {
                            Task {
                                await MainActor.run {
                                    let tx = ExpenseTransaction(
                                        amount: amt,
                                        transactionDate: isActualExpense ? actualSpendCalendarDate : expectedSpendDate,
                                        expectedDate: expectedSpendDate,
                                        vendorName: spendDescInput.isEmpty ? "Direct Expense" : spendDescInput,
                                        note: "",
                                        isActual: isActualExpense,
                                        detailItem: item
                                    )
                                    modelContext.insert(tx)
                                    item.transactions.append(tx)
                                    project.lastModified = Date()
                                    try? modelContext.save()
                                    detailItemToAddSpend = nil
                                    spendAmountInput = ""
                                    spendDescInput = ""
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 420, height: 350)
        }
    }
      
    private func parseCurrency(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0.0
    }
      
    @MainActor
    private func parseXMLBudget(data: Data, into project: MovieProject) throws {
        for oldCat in project.categories { modelContext.delete(oldCat) }
        project.categories.removeAll()
        let parser = XMLParser(data: data)
        let delegate = MMBXMLDOMParserDelegate(currencyParser: parseCurrency)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "XMLParseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown XML parsing failure."])
        }
        for catData in delegate.categories {
            let category = BudgetCategory(number: catData.number, desc: catData.desc, project: project)
            modelContext.insert(category)
            var accountsList: [BudgetAccount] = []
            for acctData in catData.accounts {
                let account = BudgetAccount(
                    number: acctData.number,
                    desc: acctData.desc,
                    totalAmount: acctData.total,
                    originalAmount: acctData.original == 0 ? acctData.total : acctData.original,
                    variance: acctData.variance,
                    category: category
                )
                modelContext.insert(account)
                var detailsList: [BudgetDetailItem] = []
                for detData in acctData.details {
                    let detail = BudgetDetailItem(
                        itemDescription: detData.description.isEmpty ? acctData.desc : detData.description,
                        amount: detData.amount,
                        unit: detData.unit,
                        rate: detData.rate,
                        subtotal: detData.subtotal,
                        globalsUsed: detData.globalsUsed,
                        fringesUsed: detData.fringesUsed,
                        account: account
                    )
                    modelContext.insert(detail)
                    detailsList.append(detail)
                }
                account.detailItems = detailsList
                accountsList.append(account)
            }
            category.accounts = accountsList
            project.categories.append(category)
        }
        project.categories.sort { (Int($0.number) ?? 99999) < (Int($1.number) ?? 99999) }
        project.lastModified = Date()
        try modelContext.save()
    }
      
    @MainActor
    private func parseCSVRows(content: String, into project: MovieProject) {
        var categoryMap: [String: (desc: String, accounts: [BudgetAccount])] = [:]
        let rows = content.components(separatedBy: .newlines)
        var activeCatNumber = "1000"
        var activeCatDesc = "Development"
        
        for row in rows.dropFirst() {
            let cols = row.components(separatedBy: ",")
            if cols.count >= 3 {
                let num = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let desc = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let total = parseCurrency(cols[2])
                if !desc.isEmpty {
                    if num.hasSuffix("00") || num.count <= 2 || total == 0.0 {
                        activeCatNumber = num.isEmpty ? "1000" : num
                        activeCatDesc = desc
                        if categoryMap[activeCatNumber] == nil {
                            categoryMap[activeCatNumber] = (desc: activeCatDesc, accounts: [])
                        }
                    } else {
                        let account = BudgetAccount(number: num, desc: desc, totalAmount: total, originalAmount: total, variance: 0.0)
                        modelContext.insert(account)
                        let detail = BudgetDetailItem(itemDescription: desc, amount: 1.0, unit: "LS", rate: total, subtotal: total, account: account)
                        modelContext.insert(detail)
                        account.detailItems = [detail]
                        if categoryMap[activeCatNumber] == nil {
                            categoryMap[activeCatNumber] = (desc: activeCatDesc, accounts: [])
                        }
                        categoryMap[activeCatNumber]?.accounts.append(account)
                    }
                }
            }
        }
         
        let sortedKeys = categoryMap.keys.sorted()
        var newCategories: [BudgetCategory] = []
        for catNum in sortedKeys {
            if let data = categoryMap[catNum] {
                let category = BudgetCategory(number: catNum, desc: data.desc, project: project)
                modelContext.insert(category)
                 
                let sortedAccounts = data.accounts.sorted { (acct1, acct2) in
                    let n1 = Int(acct1.number) ?? 99999
                    let n2 = Int(acct2.number) ?? 99999
                    return n1 < n2
                }
                category.accounts = sortedAccounts
                for acct in category.accounts {
                    acct.category = category
                }
                newCategories.append(category)
            }
        }
         
        project.categories = newCategories
        project.lastModified = Date()
        try? modelContext.save()
    }

    @MainActor
    private func parseCSVBudget(data: Data, into project: MovieProject) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to decode CSV file using UTF-8."])
        }
        for oldCat in project.categories { modelContext.delete(oldCat) }
        project.categories.removeAll()
        parseCSVRows(content: content, into: project)
    }
}
