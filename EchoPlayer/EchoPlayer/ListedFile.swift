//
//  ListedFile.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 09/07/2025.
//

import Combine
import SwiftUI

// Model for representing a file entry
struct ListedFile: Identifiable, Codable {
    let id: String
    let fullPath: String
    let name: String
    let ext: String

    var displayName: String { "\(name).\(ext)" }

    init(url: URL) {
        id = UUID().uuidString
        fullPath = url.path
        name = url.deletingPathExtension().lastPathComponent
        ext = url.pathExtension
    }
}
