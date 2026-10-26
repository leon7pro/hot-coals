//
//  SidebarView.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/23/26.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovieProject.lastModified, order: .reverse) private var projects: [MovieProject]
    
    @Binding var activeProject: MovieProject?
    @Binding var showingEditProjectSheet: Bool
    
    @State private var projectToDelete: MovieProject? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List(selection: $activeProject) {
            Section("Projects") {
                ForEach(projects) { project in
                    NavigationLink(value: project) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(project.status.color)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(.headline)
                                Text(project.productionCompany.isEmpty ? project.status.rawValue : project.productionCompany)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
        }
        .listStyle(.sidebar)
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
        .safeAreaInset(edge: .bottom) {
            if let _ = activeProject {
                VStack(spacing: 8) {
                    Divider()
                    Button(action: { showingEditProjectSheet = true }) {
                        Label("Edit Project Settings", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    private func deleteProjects(offsets: IndexSet) {
        for index in offsets {
            let project = projects[index]
            if activeProject?.persistentModelID == project.persistentModelID {
                activeProject = nil
            }
            modelContext.delete(project)
        }
        try? modelContext.save()
    }
}
