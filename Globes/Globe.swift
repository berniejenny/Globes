//
//  Globe.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import Foundation

struct Globe: Identifiable, Equatable, Hashable, Codable {
    
    private(set) var id: UUID
    
    /// Name of the globe in original language
    var name: String
    
    var nameTranslated: String?
    
    /// Family name(s) of the author(s) of the globe. If multiple authors, names are separated by a semicolon.
    var authorSurname: String?
    
    /// Given name(s) of author(s) of the globe. If multiple authors, names are separated by a semicolon.
    var authorFirstName: String?
    
    /// Date of publication of the globe (a string instead of a date to accomodate cases like "ca. 1598" or "between 1852 and 1856"
    var date: String?
    
    /// Short description of the globe
    var description: String?
    
    /// URL of web page with information about the globe
    var infoURL: URL?
   
    /// Radius of globe in meter
    var radius: Float
    
    /// Full resolution texture image without file extension
    var texture: String
    
    /// Low resolution texture image without file extension
    var previewTexture: String
        
    init(
        name: String = "Unnamed Globe",
        nameTranslated: String? = nil,
        authorSurname: String? = nil,
        authorFirstName: String? = nil,
        date: String? = nil,
        description: String? = nil,
        infoURL: URL? = nil,
        radius: Float = 0.3,
        texture: String = "",
        previewTexture: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.nameTranslated = nameTranslated
        self.authorSurname = authorSurname
        self.authorFirstName = authorFirstName
        self.date = date
        self.description = description
        self.infoURL = infoURL
        self.radius = radius
        self.texture = texture
        self.previewTexture = previewTexture
    }
    
    /// A string with all authors separated by commas.
    var author: String {
        let firstNames = (authorFirstName ?? "").components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let surnames = (authorSurname ?? "").components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let names = zip(firstNames, surnames).map { $0.0 + " " + $0.1 }.joined(separator: ", ")
        return names
    }
    
    /// A string with all authors and a date separated by commas.
    var authorAndDate: String {
        var info = author
        if !info.isEmpty && date != nil {
            info += ", "
        }
        info += date ?? ""
        return info
    }
}
