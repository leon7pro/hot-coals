//
//  MovieProjectDocument.swift
//  hot-coals
//
//  Created by Andrew Lewis on 10/23/26.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let hotCoalsProject = UTType(exportedAs: "com.dentonfilm.hotcoals.project")
}

struct ProjectPayload: Codable, Sendable {
    var projectName: String
    var productionCompany: String
    var statusRaw: String
    var totalFunding: Double
    var startingCapital: Double

    init(projectName: String, productionCompany: String, statusRaw: String, totalFunding: Double, startingCapital: Double) {
        self.projectName = projectName
        self.productionCompany = productionCompany
        self.statusRaw = statusRaw
        self.totalFunding = totalFunding
        self.startingCapital = startingCapital
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.projectName = try container.decode(String.self, forKey: .projectName)
        self.productionCompany = try container.decode(String.self, forKey: .productionCompany)
        self.statusRaw = try container.decode(String.self, forKey: .statusRaw)
        self.totalFunding = try container.decode(Double.self, forKey: .totalFunding)
        self.startingCapital = try container.decode(Double.self, forKey: .startingCapital)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projectName, forKey: .projectName)
        try container.encode(productionCompany, forKey: .productionCompany)
        try container.encode(statusRaw, forKey: .statusRaw)
        try container.encode(totalFunding, forKey: .totalFunding)
        try container.encode(startingCapital, forKey: .startingCapital)
    }

    private enum CodingKeys: String, CodingKey {
        case projectName, productionCompany, statusRaw, totalFunding, startingCapital
    }
}

struct MovieProjectDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.hotCoalsProject, .json] }

    var projectName: String
    var productionCompany: String
    var statusRaw: String
    var totalFunding: Double
    var startingCapital: Double

    @MainActor
    init(project: MovieProject) {
        self.projectName = project.name
        self.productionCompany = project.productionCompany
        self.statusRaw = project.status.rawValue
        self.totalFunding = project.totalFunding
        self.startingCapital = project.startingCapital
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let decoded = try? JSONDecoder().decode(ProjectPayload.self, from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.projectName = decoded.projectName
        self.productionCompany = decoded.productionCompany
        self.statusRaw = decoded.statusRaw
        self.totalFunding = decoded.totalFunding
        self.startingCapital = decoded.startingCapital
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let payload = ProjectPayload(
            projectName: projectName,
            productionCompany: productionCompany,
            statusRaw: statusRaw,
            totalFunding: totalFunding,
            startingCapital: startingCapital
        )
        let data = try JSONEncoder().encode(payload)
        return FileWrapper(regularFileWithContents: data)
    }
}
