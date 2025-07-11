//
//  URL+Extensions.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 11/07/2025.
//


import Foundation

extension URL {
    func isSupported() -> Bool {
        Config.supportedExtensions.contains(pathExtension.lowercased())
    }
}