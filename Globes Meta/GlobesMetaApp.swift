//
//  Globes_MetaApp.swift
//  Globes Meta
//
//  Created by Bernhard Jenny on 12/3/2024.
//

import SwiftUI

@main
struct GlobesMetaApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: GlobesMetaDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
