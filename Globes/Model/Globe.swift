//
//  Globe.swift
//  Globes
//
//  Created by Bernhard Jenny on 8/3/2024.
//

import Foundation

struct Globe: Identifiable, Hashable, Codable {
    
    private(set) var id: UUID
    
    /// Type of globe.
    var type = GlobeType.earth
    
    /// Name of the globe in original language
    var name: String
    
    /// Name of the globe translated to English if `name` is in another language.
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
    
    /// Low resolution texture image without file extension is the texture file name + `_preview`
    var previewTexture: String { texture + "_preview" }
    
    var textureURL: URL?
    
    var isCustomGlobe: Bool {
        textureURL != nil
    }
    
    /// Custom coding keys to avoid
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case nameTranslated
        case authorSurname
        case authorFirstName
        case date
        case description
        case infoURL
        case radius
        case texture
    }
    
    init(from decoder:Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? values.decode(Globe.ID.self, forKey: .id)) ?? UUID()
        self.type = try values.decode(GlobeType.self, forKey: .type)
        self.name = try values.decode(String.self, forKey: .name)
        self.nameTranslated = try? values.decode(String.self, forKey: .nameTranslated)
        self.authorSurname = try? values.decode(String.self, forKey: .authorSurname)
        self.authorFirstName = try? values.decode(String.self, forKey: .authorFirstName)
        self.date = try? values.decode(String.self, forKey: .date)
        self.description = try? values.decode(String.self, forKey: .description)
        self.infoURL = try? values.decode(URL.self, forKey: .infoURL)
        self.radius = try values.decode(Float.self, forKey: .radius)
        self.texture = try values.decode(String.self, forKey: .texture)
    }
    
    init(
        type: GlobeType = .earth,
        name: String = "Unnamed Globe",
        nameTranslated: String? = nil,
        authorSurname: String? = nil,
        authorFirstName: String? = nil,
        date: String? = nil,
        description: String? = nil,
        infoURL: URL? = nil,
        radius: Float = 0.3,
        texture: String = "",
        textureURL: URL? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.nameTranslated = nameTranslated
        self.authorSurname = authorSurname
        self.authorFirstName = authorFirstName
        self.date = date
        self.description = description
        self.infoURL = infoURL
        self.radius = radius
        self.texture = texture
        self.textureURL = textureURL
    }
    
    /// A string with all authors separated by commas.
    var author: String {
        let firstNames = (authorFirstName ?? "").components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let surnames = (authorSurname ?? "").components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let names = zip(firstNames, surnames).map {
            let separator = $0.0.isEmpty || $0.1.isEmpty ? "" : " "
            return $0.0 + separator + $0.1
        }.joined(separator: ", ")
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
