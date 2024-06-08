//
//  SearchView.swift
//  Globes
//
//  Created by Bernhard Jenny on 3/5/2024.
//

import SwiftUI

struct SearchView: View {
    @Environment(ViewModel.self) var model
    
    @State private var searchText = ""
    @State private var searchScope = SearchScope.all
    @State private var selectedAuthor: String?
    
    enum SearchScope: String, CaseIterable {
        case all, globe, author, year
    }
    
    @MainActor
    private var searchResults: [Globe] {
        let searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchText.isEmpty {
            return model.globes
        } else {
            return model.globes.filter {
                switch searchScope {
                case .all:
                    return $0.name.localizedStandardContains(searchText)
                    || $0.author.localizedStandardContains(searchText)
                    || ($0.date ?? "").localizedStandardContains(searchText)
                    || ($0.description ?? "").localizedStandardContains(searchText)
                case .globe:
                    return $0.name.localizedStandardContains(searchText)
                case .author:
                    return $0.author.localizedStandardContains(searchText)
                case .year:
                    guard let date = $0.date else { return false }
                    return date.localizedStandardContains(searchText)
                }
            }
        }
    }
    
    @MainActor
    /// An array of tuples consisting of unique author surnames and first names sorted alphabetically,
    /// and the number of globes created by the author.
    private var authors: [(String, Int)] {
        var uniqueAuthors: [String: Int] = [:]
        model.globes.forEach {
            let surnameFirstName = author(of: $0)
            uniqueAuthors[surnameFirstName, default: 0] += 1
        }
        return uniqueAuthors.sorted(by: { $0.0 < $1.0 })
    }
    
    @MainActor
    /// "Surname, first name" of the author
    /// - Parameter globe: The globe
    /// - Returns: String with surname and first name, separated by ", "
    private func author(of globe: Globe) -> String {
        let surname = globe.authorSurname ?? "Unknown Author"
        if let firstName = globe.authorFirstName {
            return surname + ", " + firstName
        } else {
            return surname
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(authors, id: \.0, selection: $selectedAuthor) { authorAndNumberOfGlobes in
                LabeledContent(
                    content: { Text("\(authorAndNumberOfGlobes.1)") },
                    label: { Text(authorAndNumberOfGlobes.0) }
                )
            }
            .onChange(of: selectedAuthor) {
                Task { @MainActor in
                    try await Task.sleep(for: .seconds(0.05))
                    if let authorSurname = selectedAuthor?.components(separatedBy: ", ").first {
                        searchText = authorSurname
                        searchScope = .author
                    }
                }
            }
            .navigationTitle("Search")
        } detail: {
            Group {
                if searchResults.isEmpty {
                    ContentUnavailableView("No Globes Found", systemImage: "magnifyingglass")
                } else {
                    GlobesGridView(globes: searchResults)
                        .animation(.default, value: searchResults)
                }
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: Text("Globe, Author, Description, Year"))
            .searchScopes($searchScope, activation: .onSearchPresentation) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue.localizedCapitalized)
                }
            }
            .onChange(of: searchText) {
                Task { @MainActor in
                    // deselect the author in the list if the text in the search field is changed
                    if let selectedAuthorSurname = selectedAuthor?.components(separatedBy: ", ").first,
                       selectedAuthorSurname != searchText {
                        self.selectedAuthor = nil
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    SearchView()
        .environment(ViewModel.preview)
}
#endif
