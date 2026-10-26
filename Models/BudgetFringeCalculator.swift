//
//  BudgetFringeCalculator.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/22/26.
//

import Foundation

// MARK: - Models

public struct BudgetLineItem: Identifiable, Codable {
    public let id: UUID
    public var accountNumber: String
    public var description: String
    public var department: String
    public var subTotal: Double
    public var amount: Double // Added amount for per-unit/per-person flat fringe scaling
    public var isEligibleForFringes: Bool
    public var globalsUsed: [String]
    public var fringesUsed: [String] // Directly from XML
    
    public init(id: UUID = UUID(), accountNumber: String, description: String, department: String, subTotal: Double, amount: Double = 1.0, isEligibleForFringes: Bool = true, globalsUsed: [String] = [], fringesUsed: [String] = []) {
        self.id = id
        self.accountNumber = accountNumber
        self.description = description
        self.department = department
        self.subTotal = subTotal
        self.amount = amount
        self.isEligibleForFringes = isEligibleForFringes
        self.globalsUsed = globalsUsed
        self.fringesUsed = fringesUsed
    }
}

public struct FringeRate: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var globalKey: String? // Maps to EP XML global ID (e.g., "FICA", "SUI", "SLBAD", "DGA")
    public var percentage: Double
    public var capPerPerson: Double?
    public var isUnionOnly: Bool
    public var isFlat: Bool
    public var flatAmount: Double
    
    public init(id: UUID = UUID(), name: String, globalKey: String? = nil, percentage: Double, capPerPerson: Double? = nil, isUnionOnly: Bool = false, isFlat: Bool = false, flatAmount: Double = 0.0) {
        self.id = id
        self.name = name
        self.globalKey = globalKey
        self.percentage = percentage
        self.capPerPerson = capPerPerson
        self.isUnionOnly = isUnionOnly
        self.isFlat = isFlat
        self.flatAmount = flatAmount
    }
}

public struct FringeCalculationResult: Codable {
    public var atlFringesTotal: Double
    public var btlFringesTotal: Double
    public var grandTotalFringes: Double
    public var categoryBreakdown: [String: Double]
}

// MARK: - Fringe Calculator Engine

public final class BudgetFringeCalculator {
    
    public static let standardFringeRates: [FringeRate] = [
        FringeRate(name: "ATLPAYR", globalKey: "ATLPAYR", percentage: 0.0, isUnionOnly: false, isFlat: true, flatAmount: 16.0),
        FringeRate(name: "Additional Payroll", globalKey: "ADPAYR", percentage: 0.0025, capPerPerson: nil, isUnionOnly: false),
        FringeRate(name: "Payroll", globalKey: "PAYR", percentage: 0.0125, capPerPerson: nil, isUnionOnly: false),
        FringeRate(name: "DGA Fringes", globalKey: "DGA", percentage: 0.205, capPerPerson: nil, isUnionOnly: true),
        FringeRate(name: "FICA (Social Security & Medicare)", globalKey: "FICA", percentage: 0.0765, capPerPerson: nil, isUnionOnly: false),
        FringeRate(name: "SUTA (State Unemployment - TX)", globalKey: "SUI", percentage: 0.064, capPerPerson: nil, isUnionOnly: false),
        FringeRate(name: "Workers' Compensation", globalKey: "WC", percentage: 0.04479, capPerPerson: nil, isUnionOnly: false),
        FringeRate(name: "SAG Fringes", globalKey: "SLBAD", percentage: 0.215, capPerPerson: nil, isUnionOnly: true),
        FringeRate(name: "SAG Fringes Alt", globalKey: "SAG", percentage: 0.215, capPerPerson: nil, isUnionOnly: true)
    ]
    
    public static func calculateFringes(
        for lineItems: [BudgetLineItem],
        rates: [FringeRate] = standardFringeRates,
        parsedGlobals: [String: ParsedGlobal] = [:]
    ) -> FringeCalculationResult {
        var atlTotal: Double = 0.0
        var btlTotal: Double = 0.0
        var rawBreakdown: [String: Double] = [:]
         
        for item in lineItems where item.isEligibleForFringes {
            let acctNumVal = Int(item.accountNumber) ?? 0
             
            // Exclude footer/summary accounts (9000+) and Contingency (10000)
            if acctNumVal >= 9000 { continue }
            guard acctNumVal >= 1000 && acctNumVal < 9000 else { continue }
             
            // NO ASSUMPTIONS: If the XML provided explicit fringes for this line item, calculate ONLY those.
            if item.fringesUsed.isEmpty { continue }
             
            let dept = item.department.lowercased()
            let isATL = (acctNumVal >= 1000 && acctNumVal < 2000) ||
                        dept.contains("above-the-line") ||
                        dept.contains("atl") ||
                        dept.contains("producer") ||
                        dept.contains("director") ||
                        dept.contains("writer")
             
            var itemTotalFringe: Double = 0.0
             
            for rate in rates {
                let matchesExplicitXMLFringe = item.fringesUsed.contains { usedKey in
                    let target = usedKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    return target.caseInsensitiveCompare(rate.name) == .orderedSame ||
                          (rate.globalKey != nil && target.caseInsensitiveCompare(rate.globalKey!) == .orderedSame)
                }
                 
                if !matchesExplicitXMLFringe { continue }
                 
                let fringeAmount: Double
                if rate.isFlat {
                    // Scale flat rates by quantity (amount) to match MMB unit calculations
                    fringeAmount = (item.amount > 0 ? item.amount : 1.0) * rate.flatAmount
                } else {
                    // Calculate directly against the line subtotal to match MMB's unmasked line calculation
                    fringeAmount = item.subTotal * rate.percentage
                }
                 
                itemTotalFringe += fringeAmount
                rawBreakdown[rate.name, default: 0.0] += fringeAmount
            }
             
            if isATL {
                atlTotal += itemTotalFringe
            } else {
                btlTotal += itemTotalFringe
            }
        }
         
        var roundedBreakdown: [String: Double] = [:]
        for (key, val) in rawBreakdown {
            roundedBreakdown[key] = (val * 100).rounded() / 100
        }
         
        let finalATL = (atlTotal * 100).rounded() / 100
        let finalBTL = (btlTotal * 100).rounded() / 100
         
        return FringeCalculationResult(
            atlFringesTotal: finalATL,
            btlFringesTotal: finalBTL,
            grandTotalFringes: finalATL + finalBTL,
            categoryBreakdown: roundedBreakdown
        )
    }
}
