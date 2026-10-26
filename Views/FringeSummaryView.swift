//
//  FringeSummaryView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/20/26.
//

import SwiftUI

public struct FringeSummaryView: View {
    public var lineItems: [BudgetLineItem]
    
    private var calculationResult: FringeCalculationResult {
        BudgetFringeCalculator.calculateFringes(for: lineItems)
    }
    
    public init(lineItems: [BudgetLineItem]) {
        self.lineItems = lineItems
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Fringe Totals Summary")) {
                HStack {
                    Text("Above-The-Line (ATL) Fringes")
                    Spacer()
                    Text(calculationResult.atlFringesTotal, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Below-The-Line (BTL) Fringes")
                    Spacer()
                    Text(calculationResult.btlFringesTotal, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                HStack {
                    Text("Grand Total Fringes")
                        .fontWeight(.bold)
                    Spacer()
                    Text(calculationResult.grandTotalFringes, format: .currency(code: "USD"))
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            }
            
            Section(header: Text("Fringe Breakdown by Type")) {
                ForEach(calculationResult.categoryBreakdown.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                        Spacer()
                        Text(value, format: .currency(code: "USD"))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 400)
        .navigationTitle("Payroll Fringes")
    }
}
