//
//  GlobesMetaDocument.swift
//  Globes Meta
//
//  Created by Bernhard Jenny on 12/3/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct GlobesMetaDocument: FileDocument {
    var globes: [Globe]
    
    static var readableContentTypes: [UTType] { [.json] }
    
    init() {
        globes = []
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        globes = try JSONDecoder().decode([Globe].self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try jsonEncoder.encode(globes)
        return .init(regularFileWithContents: data)
    }
}
