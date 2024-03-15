//
//  ContentView.swift
//  Globes Meta
//
//  Created by Bernhard Jenny on 12/3/2024.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: GlobesMetaDocument
    
    @State private var selectedGlobeId: Globe.ID? = nil
    
    private var selectedGlobe: Binding<Globe> {
        Binding(get: {
            document.globes.first(where: { $0.id == selectedGlobeId }) ?? Globe(name: "", radius: 0, texture: "", previewTexture: "")
        }, set: { globe in
            guard let index = document.globes.firstIndex(where: { $0.id == selectedGlobeId }) else { return }
            if document.globes[index] != globe {
                document.globes[index] = globe
            }
        })
    }
    
    var body: some View {
        NavigationSplitView {
            List(
                $document.globes,
                editActions: [.move, .delete],
                selection: $selectedGlobeId
            ) { $globe in
                NavigationLink(value: globe) {
                    VStack(alignment: .leading) {
                        Text(globe.name)
                        Text(globe.authorSurname ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } detail: {
            Group {
                if document.globes.first(where: { $0.id == selectedGlobeId }) != nil {
                    GlobeEditorView(globe: selectedGlobe)
                } else {
                    let message = document.globes.isEmpty ? "No Globes" : "Select a Globe"
                    ContentUnavailableView { Label(message, image: "globe.badge.plus") } description: {
                        if document.globes.isEmpty {
                            Text("Add a globe with the plus button in the toolbar.")
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 500, ideal: 600, max: .infinity)
        }
        .navigationTitle("Globes")
        .onDeleteCommand(perform: deleteSelectedGlobe)
        .toolbar {
            Button("Add Globe", systemImage: "plus.circle", action: addGlobe)
            Button("Remove Globe", systemImage: "trash", role: .destructive, action: deleteSelectedGlobe)
        }
        .onAppear {
            select(globe: document.globes.first?.id)
        }
    }
    
    private func select(globe id: Globe.ID?) {
        Task { @MainActor in
            try await Task.sleep(for: .seconds(0.05))
            selectedGlobeId = id
        }
    }
    
    private func addGlobe() {
        let globe = Globe(name: "Unnamed Globe", radius: 0.3, texture: "", previewTexture: "")
        let index = document.globes.firstIndex(where: { $0.id == selectedGlobeId }) ?? document.globes.endIndex - 1
        document.globes.insert(globe, at: index + 1)
        select(globe: globe.id)
    }
    
    private func deleteSelectedGlobe() {
        guard let index = document.globes.firstIndex(where: { $0.id == selectedGlobeId }) else { return }
        let precedingIndex = max(0, document.globes.index(before: index))
        document.globes.removeAll(where: { $0.id == selectedGlobeId })
        if document.globes.indices.contains(precedingIndex) {
            select(globe: document.globes[precedingIndex].id)
        } else {
            select(globe: nil)
        }
    }
}

#Preview {
    ContentView(document: .constant(GlobesMetaDocument()))
}
