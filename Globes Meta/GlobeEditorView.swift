//
//  GlobeEditorView.swift
//  Globes Metainfo
//
//  Created by Bernhard Jenny on 12/3/2024.
//

import SwiftUI

func ??<T>(lhs: Binding<Optional<T>>, rhs: T) -> Binding<T> where T: Equatable {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: {
            if lhs.wrappedValue != $0 {
                lhs.wrappedValue = $0
            }
        }
    )
}

struct GlobeEditorView: View {
    
    @Binding var globe: Globe
    
    private var infoURLBinding: Binding<String> {
        Binding(
            get: { globe.infoURL?.absoluteString ?? "" },
            set: { 
                if globe.infoURL != URL(string: $0) {
                    globe.infoURL = URL(string: $0)
                }
            }
        )
    }
    
    var body: some View {
        VStack {
            Form {
                Section("Name") {
                    TextField("Original", text: $globe.name)
                    TextField("Translated", text: $globe.nameTranslated ?? "")
                }
                Spacer()
                Section("Publication") {
                    TextField("Date", text: $globe.date ?? "")
                    Text("The date can include \"ca.\" or similar.")
                        .font(.caption)
                }
                Spacer()
                Section("Authors") {
                    TextField("Surname", text: $globe.authorSurname ?? "")
                    TextField("First Name", text: $globe.authorFirstName ?? "")
                    Text("Separate multiple names with a semicolon.")
                        .font(.caption)
                }
                Spacer()
                Section("Geometry") {
                    TextField("Radius", value: $globe.radius, format: .number)
                    Text("Radius in meter")
                        .font(.caption)
                }
                Spacer()
                Section("Information") {
                    TextField("Description", text: $globe.description ?? "", axis: .vertical)
                        .lineLimit(4...20)
                    HStack {
                        TextField("Web URL", text: infoURLBinding)
                        if let url = globe.infoURL {
                            Link("Open", destination: url)
                        }
                    }
                }
                Spacer()
                Section("Texture") {
                    TextField("Detailed", text: $globe.texture)
                    TextField("Preview", text: $globe.previewTexture)
                    Text("Enter texture and preview texture image names without file extensions.")
                        .font(.caption)
                }
                Spacer()
            }
            .frame(minWidth: 450, minHeight: 630)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    let globe = Globe(name: "", radius: 1.23, texture: "Texture_file_name", previewTexture: "texture preview")
    return GlobeEditorView(globe: .constant(globe))
}
