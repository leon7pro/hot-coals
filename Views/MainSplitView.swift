//
//  MainSplitView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/23/26.
//

import SwiftUI
import SwiftData

struct MainSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeProject: MovieProject? = nil
    @State private var showingEditProjectSheet = false
    
    // Edit sheet local states
    @State private var editTitle = ""
    @State private var editProductionCompany = ""
    @State private var editStartingCapital = ""
    @State private var editStatus: ProjectStatus = .development

    var body: some View {
        NavigationSplitView {
            SidebarView(
                activeProject: $activeProject,
                showingEditProjectSheet: $showingEditProjectSheet
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let project = activeProject {
                ProjectDashboardView(
                    project: project,
                    showingEditProjectSheet: $showingEditProjectSheet
                )
            } else {
                WelcomeWindowView(
                    activeProject: $activeProject,
                    onOpenProject: { proj in
                        activeProject = proj
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditProjectSheet) {
            if let project = activeProject {
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
