//
//  MMBXMLDOMParserDelegate.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/19/26.
//

import Foundation

public struct ParsedGlobal {
    public var id: String
    public var name: String
    public var cap: Double
    
    public init(id: String, name: String, cap: Double) {
        self.id = id
        self.name = name
        self.cap = cap
    }
}

class MMBXMLDOMParserDelegate: NSObject, XMLParserDelegate {
    struct ParsedDetail {
        var accountID: String
        var description: String
        var amount: Double
        var unit: String
        var rate: Double
        var subtotal: Double
        var globalsUsed: [String]
        var fringesUsed: [String]
        var includeInContingency: Bool
    }
    
    struct ParsedAccount {
        var number: String
        var desc: String
        var total: Double
        var original: Double
        var variance: Double
        var details: [ParsedDetail]
    }
    
    struct ParsedCategory {
        var number: String
        var desc: String
        var accounts: [ParsedAccount]
        var summaryTotal: Double? // Added to support EP category-level summary totals (e.g., Contingency)
    }
    
    var categories: [ParsedCategory] = []
    var globalsMap: [String: ParsedGlobal] = [:]
    var declaredContingencyPercentage: Double = 0.0
    let currencyParser: (String) -> Double
    
    private var currentText = ""
    private var categoriesMap: [String: ParsedCategory] = [:]
    
    private var rawCategories: [String: (number: String, desc: String, total: Double)] = [:]
    private var rawAccounts: [String: (catID: String, number: String, desc: String)] = [:]
    
    private var currentCatID = ""
    private var currentCatNum = ""
    private var currentCatDesc = ""
    private var currentCatTotal = 0.0
    
    private var currentAcctCatID = ""
    private var currentAcctID = ""
    private var currentAcctNum = ""
    private var currentAcctDesc = ""
    
    private var currentDetailAcctID = ""
    private var detDesc = ""
    private var detQty = 1.0
    private var detUnit = "LS"
    private var detRate = 0.0
    private var detSubtotal = 0.0
    private var detSubtotalWasExplicitlySet = false
    private var detExclude = false
    private var detIncludeInContingency = true
    private var detGlobalsUsed: [String] = []
    private var detFringesUsed: [String] = []
    
    // Global parsing states
    private var currentGlobalID = ""
    private var currentGlobalName = ""
    private var currentGlobalCap = 0.0
    
    init(currencyParser: @escaping (String) -> Double) {
        self.currencyParser = currencyParser
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        let tag = elementName.lowercased()
        
        if tag == "category" {
            currentCatID = ""
            currentCatNum = ""
            currentCatDesc = ""
            currentCatTotal = 0.0
            
            if let cId = attributeDict["cID"] ?? attributeDict["cid"] { currentCatID = cId }
            if let cNum = attributeDict["cNumber"] ?? attributeDict["cnumber"] { currentCatNum = cNum }
            if let cTot = attributeDict["cTotal"] ?? attributeDict["ctotal"] {
                currentCatTotal = currencyParser(cTot)
            }
        } else if tag == "detail" {
            detSubtotalWasExplicitlySet = false
            detSubtotal = 0.0
            detRate = 0.0
            detQty = 1.0
            detUnit = "LS"
            detDesc = ""
            detExclude = false
            detIncludeInContingency = true
            detGlobalsUsed = []
            detFringesUsed = []
        } else if tag == "global" {
            currentGlobalID = ""
            currentGlobalName = ""
            currentGlobalCap = 0.0
        }
        
        if attributeDict["Excl"] == "true" || attributeDict["excl"] == "true" || attributeDict["Excluded"] == "true" || attributeDict["excluded"] == "true" {
            detExclude = true
        }
        
        if let exclContingency = attributeDict["ExclContingency"] ?? attributeDict["exclcontingency"] ?? attributeDict["excludeFromContingency"] {
            if exclContingency.lowercased() == "true" {
                detIncludeInContingency = false
            }
        }
        if let incContingency = attributeDict["IncludeInContingency"] ?? attributeDict["includeincontingency"] {
            if incContingency.lowercased() == "false" {
                detIncludeInContingency = false
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = elementName.lowercased()
        
        switch tag {
        case "contingencyrate", "contingency_rate", "contingency":
            if declaredContingencyPercentage == 0.0, let val = Double(trimmed) {
                declaredContingencyPercentage = val
            }
        case "gid", "globalid":
            currentGlobalID = trimmed
        case "gname", "globalname":
            currentGlobalName = trimmed
        case "gcap", "cap", "limit":
            currentGlobalCap = currencyParser(trimmed)
        case "global":
            if !currentGlobalID.isEmpty {
                globalsMap[currentGlobalID] = ParsedGlobal(id: currentGlobalID, name: currentGlobalName, cap: currentGlobalCap)
            }
            currentGlobalID = ""
            currentGlobalName = ""
            currentGlobalCap = 0.0

        case "cid":
            if currentCatID.isEmpty { currentCatID = trimmed }
        case "cnumber":
            if currentCatNum.isEmpty { currentCatNum = trimmed }
        case "cdescription":
            currentCatDesc = trimmed
        case "category":
            if !currentCatNum.isEmpty || !currentCatID.isEmpty {
                var catDesc = !currentCatDesc.isEmpty ? currentCatDesc : "Category \(currentCatNum)"
                var catNum = currentCatNum
                
                let descLower = catDesc.lowercased()
                let isFringeCategory = descLower.contains("fring") || descLower.contains("fringe")
                let isContingencyCategory = descLower.contains("contingency") || catNum == "10000"
                
                if isFringeCategory {
                    if descLower.contains("above") || descLower.contains("atl") {
                        catDesc = "ABOVE-THE-LINE (ATL) FRINGES"
                        catNum = "9001"
                    } else {
                        catDesc = "BELOW-THE-LINE (BTL) FRINGES"
                        catNum = "9002"
                    }
                } else if isContingencyCategory {
                    catNum = "10000"
                    catDesc = "CONTINGENCY"
                }
                
                if catNum.isEmpty {
                    catNum = "9000"
                }
                
                rawCategories[currentCatID.isEmpty ? catNum : currentCatID] = (number: catNum, desc: catDesc, total: currentCatTotal)
                if categoriesMap[catNum] == nil {
                    categoriesMap[catNum] = ParsedCategory(number: catNum, desc: catDesc, accounts: [], summaryTotal: currentCatTotal > 0 ? currentCatTotal : nil)
                } else if currentCatTotal > 0 {
                    var existing = categoriesMap[catNum]!
                    existing.summaryTotal = currentCatTotal
                    categoriesMap[catNum] = existing
                }
            }
            currentCatID = ""
            currentCatNum = ""
            currentCatDesc = ""
            currentCatTotal = 0.0
            
        case "categoryid":
            currentAcctCatID = trimmed
        case "aid":
            currentAcctID = trimmed
        case "anumber":
            currentAcctNum = trimmed
        case "adescription":
            currentAcctDesc = trimmed
        case "account":
            if !currentAcctNum.isEmpty || !currentAcctID.isEmpty {
                let acctDesc = !currentAcctDesc.isEmpty ? currentAcctDesc : "Account \(currentAcctNum)"
                let effectiveAcctNum = currentAcctNum.isEmpty ? currentAcctID : currentAcctNum
                rawAccounts[currentAcctID] = (catID: currentAcctCatID, number: effectiveAcctNum, desc: acctDesc)
                
                var parentCatNum = ""
                if let catInfo = rawCategories[currentAcctCatID] {
                    parentCatNum = catInfo.number
                }
                if parentCatNum.isEmpty, let intVal = Int(effectiveAcctNum) {
                    if intVal >= 10000 {
                        parentCatNum = "10000"
                    } else if intVal >= 9000 {
                        parentCatNum = "\(intVal)"
                    } else {
                        parentCatNum = "\((intVal / 1000) * 1000)"
                    }
                }
                if parentCatNum.isEmpty { parentCatNum = "1000" }
                
                let parentCatDesc = rawCategories[currentAcctCatID]?.desc ??
                    (parentCatNum == "10000" ? "CONTINGENCY" :
                     parentCatNum == "9800" ? "BANKING" :
                     parentCatNum == "9500" ? "INSURANCE" :
                     parentCatNum == "9700" ? "LEGAL & ADMIN" : "Category \(parentCatNum)")
                
                if categoriesMap[parentCatNum] == nil {
                    categoriesMap[parentCatNum] = ParsedCategory(number: parentCatNum, desc: parentCatDesc, accounts: [])
                }
                
                var cat = categoriesMap[parentCatNum]!
                if !cat.accounts.contains(where: { $0.number == effectiveAcctNum }) {
                    let newAcct = ParsedAccount(
                        number: effectiveAcctNum,
                        desc: acctDesc,
                        total: 0.0,
                        original: 0.0,
                        variance: 0.0,
                        details: []
                    )
                    cat.accounts.append(newAcct)
                    categoriesMap[parentCatNum] = cat
                }
            }
            currentAcctCatID = ""
            currentAcctID = ""
            currentAcctNum = ""
            currentAcctDesc = ""
            
        case "accountid":
            currentDetailAcctID = trimmed
        case "ddescription":
            if !trimmed.isEmpty { detDesc = trimmed }
        case "damount":
            if let val = Double(trimmed) { detQty = val }
        case "dunit":
            if !trimmed.isEmpty { detUnit = trimmed }
        case "drate":
            detRate = currencyParser(trimmed)
        case "dsubtotal":
            detSubtotal = currencyParser(trimmed)
            detSubtotalWasExplicitlySet = true
        case "dglobalused", "dglobal":
            if !trimmed.isEmpty { detGlobalsUsed.append(trimmed) }
        case "dfringe", "dfringeused":
            if !trimmed.isEmpty { detFringesUsed.append(trimmed) }
        case "detail":
            var targetAcctNum = currentDetailAcctID
            if let acctInfo = rawAccounts[targetAcctNum] {
                targetAcctNum = acctInfo.number.isEmpty ? targetAcctNum : acctInfo.number
            }
            if targetAcctNum.isEmpty {
                targetAcctNum = "1001"
            }
            
            let rate = detRate > 0 ? detRate : 0.0
            let computedSubtotal = detSubtotalWasExplicitlySet ? detSubtotal : (detQty * rate)
            let finalSubtotal = detExclude ? 0.0 : computedSubtotal
            let description = !detDesc.isEmpty ? detDesc : "Line Item"
            
            let intAcct = Int(targetAcctNum) ?? 0
            
            let detail = ParsedDetail(
                accountID: targetAcctNum,
                description: description,
                amount: detQty == 0 ? 1.0 : detQty,
                unit: detUnit,
                rate: rate,
                subtotal: finalSubtotal,
                globalsUsed: detGlobalsUsed,
                fringesUsed: detFringesUsed,
                includeInContingency: detIncludeInContingency && (intAcct < 8000 || intAcct >= 9000)
            )
            
            var found = false
            for (catKey, var cat) in categoriesMap {
                if let idx = cat.accounts.firstIndex(where: { $0.number == targetAcctNum }) {
                    cat.accounts[idx].details.append(detail)
                    cat.accounts[idx].total += finalSubtotal
                    cat.accounts[idx].original += finalSubtotal
                    categoriesMap[catKey] = cat
                    found = true
                    break
                }
            }
            
            if !found {
                var catNum = ""
                if let acctInfo = rawAccounts[currentDetailAcctID], let catInfo = rawCategories[acctInfo.catID] {
                    catNum = catInfo.number
                } else if let intVal = Int(targetAcctNum) {
                    if intVal >= 10000 {
                        catNum = "10000"
                    } else if intVal >= 9000 {
                        catNum = "\(intVal)"
                    } else {
                        catNum = "\((intVal / 1000) * 1000)"
                    }
                }
                if catNum.isEmpty { catNum = "1000" }
                
                let catDesc = rawCategories[rawAccounts[currentDetailAcctID]?.catID ?? ""]?.desc ?? (catNum == "10000" ? "CONTINGENCY" : "Category \(catNum)")
                if categoriesMap[catNum] == nil {
                    categoriesMap[catNum] = ParsedCategory(number: catNum, desc: catDesc, accounts: [])
                }
                
                var cat = categoriesMap[catNum]!
                let acctDesc = rawAccounts[currentDetailAcctID]?.desc ?? "Account \(targetAcctNum)"
                
                if let idx = cat.accounts.firstIndex(where: { $0.number == targetAcctNum }) {
                    cat.accounts[idx].details.append(detail)
                    cat.accounts[idx].total += finalSubtotal
                    cat.accounts[idx].original += finalSubtotal
                } else {
                    let newAcct = ParsedAccount(
                        number: targetAcctNum,
                        desc: acctDesc,
                        total: finalSubtotal,
                        original: finalSubtotal,
                        variance: 0.0,
                        details: [detail]
                    )
                    cat.accounts.append(newAcct)
                }
                categoriesMap[catNum] = cat
            }
            
            currentDetailAcctID = ""
            detDesc = ""
            detQty = 1.0
            detUnit = "LS"
            detRate = 0.0
            detSubtotal = 0.0
            detSubtotalWasExplicitlySet = false
            detExclude = false
            detIncludeInContingency = true
            detGlobalsUsed = []
            detFringesUsed = []
            
        default:
            break
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if categoriesMap["9001"] == nil {
            categoriesMap["9001"] = ParsedCategory(number: "9001", desc: "ABOVE-THE-LINE (ATL) FRINGES", accounts: [])
        }
        if categoriesMap["9002"] == nil {
            categoriesMap["9002"] = ParsedCategory(number: "9002", desc: "BELOW-THE-LINE (BTL) FRINGES", accounts: [])
        }
        
        for (_, catInfo) in rawCategories {
            if categoriesMap[catInfo.number] == nil {
                categoriesMap[catInfo.number] = ParsedCategory(number: catInfo.number, desc: catInfo.desc, accounts: [], summaryTotal: catInfo.total > 0 ? catInfo.total : nil)
            } else if catInfo.total > 0, var existing = categoriesMap[catInfo.number] {
                if existing.summaryTotal == nil {
                    existing.summaryTotal = catInfo.total
                    categoriesMap[catInfo.number] = existing
                }
            }
        }
        
        // Handle Contingency category fallback if summaryTotal was provided at category level
        if let contingencyCat = categoriesMap["10000"], contingencyCat.accounts.isEmpty, let summaryTotal = contingencyCat.summaryTotal, summaryTotal > 0 {
            let contingencyDetail = ParsedDetail(
                accountID: "10000",
                description: "Contingency Summary",
                amount: 1.0,
                unit: "LS",
                rate: summaryTotal,
                subtotal: summaryTotal,
                globalsUsed: [],
                fringesUsed: [],
                includeInContingency: false
            )
            let contingencyAccount = ParsedAccount(
                number: "10000",
                desc: "Contingency",
                total: summaryTotal,
                original: summaryTotal,
                variance: 0.0,
                details: [contingencyDetail]
            )
            var updatedCat = contingencyCat
            updatedCat.accounts = [contingencyAccount]
            categoriesMap["10000"] = updatedCat
        } else if declaredContingencyPercentage > 0, categoriesMap["10000"]?.accounts.isEmpty ?? true {
            var eligibleSubtotal = 0.0
            for cat in categoriesMap.values {
                if cat.number == "10000" || cat.number.hasPrefix("90") { continue }
                for acct in cat.accounts {
                    for det in acct.details {
                        if det.includeInContingency {
                            eligibleSubtotal += det.subtotal
                        }
                    }
                }
            }
            let contingencyTotal = eligibleSubtotal * (declaredContingencyPercentage / 100.0)
            let contingencyDetail = ParsedDetail(
                accountID: "10000",
                description: "Contingency (\(declaredContingencyPercentage)%)",
                amount: 1.0,
                unit: "LS",
                rate: contingencyTotal,
                subtotal: contingencyTotal,
                globalsUsed: [],
                fringesUsed: [],
                includeInContingency: false
            )
            let contingencyAccount = ParsedAccount(
                number: "10000",
                desc: "Contingency",
                total: contingencyTotal,
                original: contingencyTotal,
                variance: 0.0,
                details: [contingencyDetail]
            )
            categoriesMap["10000"] = ParsedCategory(
                number: "10000",
                desc: "CONTINGENCY",
                accounts: [contingencyAccount],
                summaryTotal: contingencyTotal
            )
        }
        
        self.categories = categoriesMap.values.sorted { cat1, cat2 in
            let num1 = Int(cat1.number) ?? 99999
            let num2 = Int(cat2.number) ?? 99999
            
            let isFooter1 = num1 >= 9000 || cat1.desc.lowercased().contains("contingency") || cat1.desc.lowercased().contains("fring") || cat1.desc.lowercased().contains("charge")
            let isFooter2 = num2 >= 9000 || cat2.desc.lowercased().contains("contingency") || cat2.desc.lowercased().contains("fring") || cat2.desc.lowercased().contains("charge")
            
            if isFooter1 != isFooter2 {
                return !isFooter1
            }
            return num1 < num2
        }
    }
}
