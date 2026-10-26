//
//  ProjectManagerView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/23/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension ProjectStatus {
    var outlineColor: Color {
        switch self {
        case .development: return .blue
        case .preProduction: return .purple
        case .production: return .orange
        case .postProduction: return .yellow
        case .distribution: return .teal
        case .completed: return .green
        }
    }
}

struct ProjectManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovieProject.lastModified, order: .reverse) private var projects: [MovieProject]
    
    @State private var selectedProject: MovieProject? = nil
    @State private var showWelcomeScreen = true
    @State private var showingNewProjectSheet = false
    @State private var showingEditProjectSheet = false
    @State private var showingExportDialog = false
    @State private var documentToExport: MovieProjectDocument? = nil
    
    @State private var newProjectTitle = ""
    @State private var newProductionCompany = ""
    @State private var newProjectBudget = ""
    
    // Edit sheet local binding states
    @State private var editTitle = ""
    @State private var editProductionCompany = ""
    @State private var editStartingCapital = ""
    @State private var editStatus: ProjectStatus = .development

    var body: some View {
        Group {
            if showWelcomeScreen || selectedProject == nil {
                WelcomeWindowView(
                    activeProject: $selectedProject,
                    onOpenProject: { project in
                        selectedProject = project
                        showWelcomeScreen = false
                    }
                )
            } else {
                NavigationSplitView {
                    List(selection: $selectedProject) {
                        ForEach(projects) { project in
                            NavigationLink(value: project) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.name)
                                            .font(.headline)
                                        Text(project.status.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(project.status.outlineColor)
                                            .bold()
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(project.status.outlineColor)
                                        .frame(width: 8, height: 8)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(project.status.outlineColor, lineWidth: selectedProject?.id == project.id ? 2 : 0)
                                    .padding(2)
                            )
                        }
                    }
                    .navigationTitle("Projects")
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 350)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button(action: { showingNewProjectSheet = true }) {
                                    Label("New Project", systemImage: "plus.circle")
                                }
                                if let activeProj = selectedProject {
                                    Button(action: {
                                        showingEditProjectSheet = true
                                    }) {
                                        Label("Edit Project Settings", systemImage: "slider.horizontal.3")
                                    }
                                    Button(action: {
                                        documentToExport = MovieProjectDocument(project: activeProj)
                                        showingExportDialog = true
                                    }) {
                                        Label("Export Project As...", systemImage: "square.and.arrow.up")
                                    }
                                }
                                Button(action: { showWelcomeScreen = true }) {
                                    Label("Return to Startup Window", systemImage: "house")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                } detail: {
                    if let project = selectedProject {
                        ProjectDashboardView(
                            project: project,
                            showingEditProjectSheet: $showingEditProjectSheet
                        )
                    } else {
                        ContentUnavailableView(
                            "Select a Project",
                            systemImage: "film",
                            description: Text("Choose a project from the sidebar or click '+' to create a new one.")
                        )
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: documentToExport,
            contentType: .hotCoalsProject,
            defaultFilename: "\(selectedProject?.name ?? "Project")"
        ) { result in
            switch result {
            case .success(let url):
                print("Project successfully exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
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
                 
                TextField("Initial Total Budget ($)", text: $newProjectBudget, prompt: Text("Initial Total Budget (e.g., 1200000)"))
                    .textFieldStyle(.roundedBorder)
                 
                HStack {
                    Button("Cancel") {
                        showingNewProjectSheet = false
                    }
                    .buttonStyle(.bordered)
                     
                    Button("Create Project") {
                        if !newProjectTitle.isEmpty {
                            let budgetVal = Double(newProjectBudget) ?? 1200000.0
                            let newProj = MovieProject(
                                name: newProjectTitle,
                                productionCompany: newProductionCompany,
                                status: .development,
                                totalFunding: budgetVal
                            )
                            modelContext.insert(newProj)
                            try? modelContext.save()
                             
                            selectedProject = newProj
                            showWelcomeScreen = false
                            showingNewProjectSheet = false
                            newProjectTitle = ""
                            newProductionCompany = ""
                            newProjectBudget = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 380, height: 260)
        }
        .sheet(isPresented: $showingEditProjectSheet) {
            if let project = selectedProject {
                VStack(spacing: 16) {
                    Text("Edit Project Settings")
                        .font(.headline)
                     
                    TextField("Project Title", text: $editTitle)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { editTitle = project.name }
                     
                    TextField("Production Company", text: $editProductionCompany)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { editProductionCompany = project.productionCompany }
                     
                    TextField("Starting Capital ($)", text: $editStartingCapital)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { editStartingCapital = String(project.startingCapital) }
                     
                    HStack {
                        Text("Project Status:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            ForEach(ProjectStatus.allCases, id: \.self) { status in
                                Button(status.rawValue) {
                                    editStatus = status
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(editStatus.color)
                                    .frame(width: 8, height: 8)
                                Text(editStatus.rawValue)
                                    .font(.subheadline)
                                    .bold()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(editStatus.color.opacity(0.15))
                            .foregroundStyle(editStatus.color)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .onAppear { editStatus = project.status }
                    }
                    .padding(.horizontal, 4)
                     
                    HStack {
                        Button("Cancel") {
                            showingEditProjectSheet = false
                        }
                        .buttonStyle(.bordered)
                         
                        Button("Save Changes") {
                            Task {
                                await MainActor.run {
                                    project.name = editTitle.isEmpty ? project.name : editTitle
                                    project.productionCompany = editProductionCompany
                                    project.startingCapital = Double(editStartingCapital) ?? project.startingCapital
                                    project.status = editStatus
                                    project.lastModified = Date()
                                    try? modelContext.save()
                                    showingEditProjectSheet = false
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 400, height: 300)
            }
        }
    }
}
