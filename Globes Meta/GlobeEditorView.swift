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
        let topPadding: CGFloat = 20
        
        VStack {
            Form() {
                Picker("Globe Type", selection: $globe.type) {
                    ForEach(GlobeType.allCases, id: \.self) { type in
                        Text(type.label)
                    }
                }
                .frame(maxWidth: 350)
                
                Section {
                    TextField("Original", text: $globe.name)
                    TextField("Translated", text: $globe.nameTranslated ?? "")
                } header: {
                    Text("Name")
                        .padding(.top, topPadding)
                }
                
                Section {
                    TextField("Date", text: $globe.date ?? "")
                    Text("The date can include \"ca.\" or similar.")
                        .font(.caption)
                } header: {
                    Text("Publication")
                        .padding(.top, topPadding)
                }
                Section {
                    TextField("Surname", text: $globe.authorSurname ?? "")
                    TextField("First Name", text: $globe.authorFirstName ?? "")
                    Text("Separate multiple names with a semicolon.")
                        .font(.caption)
                } header: {
                    Text("Authors")
                        .padding(.top, topPadding)
                }
                Section {
                    TextField("Radius", value: $globe.radius, format: .number)
                    Text("Radius in meter")
                        .font(.caption)
                } header: {
                    Text("Geometry")
                        .padding(.top, topPadding)
                }
                Section {
                    TextField("Description", text: $globe.description ?? "", axis: .vertical)
                        .lineLimit(4...20)
                    HStack {
                        TextField("Web URL", text: infoURLBinding)
                        if let url = globe.infoURL {
                            Link("Open", destination: url)
                        }
                    }
                } header: {
                    Text("Information")
                        .padding(.top, topPadding)
                }
                Section {
                    TextField("File Name", text: $globe.texture)
                    Text("Texture image name without \".jpg\" file extension.")
                        .font(.caption)
                } header: {
                    Text("Texture")
                        .padding(.top, topPadding)
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
    GlobeEditorView(globe: .constant(Globe.preview))
        .frame(height: 1000)
}
