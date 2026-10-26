//
//  WelcomeWindowView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/23/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WelcomeWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovieProject.lastModified, order: .reverse) private var recentProjects: [MovieProject]
    
    @Binding var activeProject: MovieProject?
    var onOpenProject: (MovieProject) -> Void
    
    @State private var showingNewProjectSheet = false
    @State private var showingFileImporter = false
    @State private var newProjectTitle = ""
    @State private var newProductionCompany = ""
    @State private var newStartingCapital = ""
    @State private var newProjectStatus: ProjectStatus = .development
    
    // State for handling project deletion confirmation
    @State private var projectToDelete: MovieProject? = nil
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image("HotCoalsLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 5)
                 
                Text("HOT COALS")
                    .font(.custom("American Typewriter", size: 38))
                    .bold()
                    .tracking(2)
                 
                Text("Independent Film Production & Budget Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 24)
             
            Divider()
             
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                     
                    Button(action: { showingNewProjectSheet = true }) {
                        Label("Start New Project", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                     
                    Button(action: { showingFileImporter = true }) {
                        Label("Import Project / Budget (.hotcoals, .xml, .csv)", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                     
                    Spacer()
                }
                .padding(24)
                .frame(width: 280)
                .background(.background.secondary)
                 
                Divider()
                 
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Projects")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                     
                    if recentProjects.isEmpty {
                        ContentUnavailableView(
                            "No Recent Projects",
                            systemImage: "folder.badge.questionmark",
                            description: Text("Create a new project or import an existing file to begin.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(recentProjects) { project in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.name)
                                            .font(.headline)
                                        Text("Status: \(project.status.rawValue) • Modified: \(project.lastModified, style: .date)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Open") {
                                        onOpenProject(project)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        projectToDelete = project
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete Project", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete(perform: deleteProjects)
                        }
                        .listStyle(.plain)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 720, height: 520)
        .confirmationDialog(
            "Are you sure you want to delete '\(projectToDelete?.name ?? "this project")'? This action cannot be undone.",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                if let project = projectToDelete {
                    if activeProject?.persistentModelID == project.persistentModelID {
                        activeProject = nil
                    }
                    modelContext.delete(project)
                    try? modelContext.save()
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            VStack(spacing: 16) {
                Text("Create New Project")
                    .font(.headline)
                 
                TextField("Project Title", text: $newProjectTitle, prompt: Text("Project Title (e.g., Bethesda)"))
                    .textFieldStyle(.roundedBorder)
                 
                TextField("Production Company", text: $newProductionCompany, prompt: Text("Production Company (e.g., Denton Film LLC)"))
                    .textFieldStyle(.roundedBorder)
                 
                TextField("Starting Capital ($)", text: $newStartingCapital, prompt: Text("Starting Capital (e.g., 50000 or leave blank)"))
                    .textFieldStyle(.roundedBorder)
                 
                HStack {
                    Text("Initial Status:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Button(status.rawValue) {
                                newProjectStatus = status
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(newProjectStatus.color)
                                .frame(width: 8, height: 8)
                            Text(newProjectStatus.rawValue)
                                .font(.subheadline)
                                .bold()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(newProjectStatus.color.opacity(0.15))
                        .foregroundStyle(newProjectStatus.color)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                 
                HStack {
                    Button("Cancel") {
                        showingNewProjectSheet = false
                    }
                    .buttonStyle(.bordered)
                     
                    Button("Create Project") {
                        if !newProjectTitle.isEmpty {
                            Task {
                                await MainActor.run {
                                    let capitalVal = Double(newStartingCapital) ?? 0.0
                                    let newProj = MovieProject(
                                        name: newProjectTitle,
                                        productionCompany: newProductionCompany.isEmpty ? "Denton Film LLC" : newProductionCompany,
                                        status: newProjectStatus,
                                        totalFunding: capitalVal > 0 ? capitalVal : 1200000.0,
                                        startingCapital: capitalVal
                                    )
                                    modelContext.insert(newProj)
                                    try? modelContext.save()
                                     
                                    onOpenProject(newProj)
                                    showingNewProjectSheet = false
                                    newProjectTitle = ""
                                    newProductionCompany = ""
                                    newStartingCapital = ""
                                    newProjectStatus = .development
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 400, height: 280)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "hotcoals") ?? .data,
                .commaSeparatedText,
                .xml,
                .plainText,
                UTType(filenameExtension: "mmb") ?? .data
            ],
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
                            let projectName = selectedFile.deletingPathExtension().lastPathComponent
                            let newProj = MovieProject(
                                name: projectName,
                                productionCompany: "Denton Film LLC",
                                status: .development,
                                totalFunding: 1200000.0,
                                startingCapital: 0.0
                            )
                            modelContext.insert(newProj)
                            
                            do {
                                if filename.hasSuffix(".csv") {
                                    let content = String(data: data, encoding: .utf8) ?? ""
                                    parseCSVRows(content: content, into: newProj)
                                } else if !filename.hasSuffix(".hotcoals") {
                                    let delegate = MMBXMLDOMParserDelegate(currencyParser: parseCurrency)
                                    let parser = XMLParser(data: data)
                                    parser.delegate = delegate
                                    if parser.parse() {
                                        for catData in delegate.categories {
                                            let category = BudgetCategory(number: catData.number, desc: catData.desc, project: newProj)
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
                                            newProj.categories.append(category)
                                        }
                                    }
                                }
                                try modelContext.save()
                                onOpenProject(newProj)
                            } catch {
                                print("Import parsing error: \(error.localizedDescription)")
                                onOpenProject(newProj)
                            }
                        }
                    }
                }
            } catch {
                print("Import error: \(error.localizedDescription)")
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = recentProjects[index]
            if activeProject?.persistentModelID == project.persistentModelID {
                activeProject = nil
            }
            modelContext.delete(project)
        }
        try? modelContext.save()
    }

    private func parseCurrency(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0.0
    }

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
    }
}
