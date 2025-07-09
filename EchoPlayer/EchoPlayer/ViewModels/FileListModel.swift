//
//  FileListModel.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 09/07/2025.
//
import Combine
import SwiftUI

@Observable
final class FileListModel {
    
    private let decoder: JSONDecoder = JSONDecoder()
    private let store: UserDefaults = UserDefaults.standard
    private let encoder: JSONEncoder = JSONEncoder()
    
    var files: [ListedFile] = []

    init() {
        do {
            if let list = store.value(forKey: "lastPlaybackList") as? Data {
                files = try decoder.decode([ListedFile].self, from: list)
            }
        } catch {
            print(error)
        }
    }

    func saveToStore() {
        do {
            let data = try encoder.encode(files)
           store.set(data, forKey: "lastPlaybackList")
        } catch {
            print(error)
        }
    }

    // Adds supported files from dropped URLs (recursively for folders)
    func add(urls: [URL]) {
        var added: [ListedFile] = []
        for url in urls {
            if url.hasDirectoryPath {
                let fileURLs = filesRecursively(in: url)
                added.append(contentsOf: fileURLs)
            } else if isSupported(url) {
                if url.pathExtension == "eplist" {
                    loadJSON(url: url)
                } else {
                    added.append(ListedFile(url: url))
                }
            }
        }
        // Avoid duplicates
        let existingPaths = Set(files.map { $0.fullPath })
        let deduped = added.filter { !existingPaths.contains($0.fullPath) }
        files.append(contentsOf: deduped)
        saveToStore()
    }

    func clear() {
        files = []
        saveToStore()
    }

    // Save as JSON to chosen file
    @MainActor
    func saveToJSON() async {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["eplist"]
        savePanel.nameFieldStringValue = "file-list.epl"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(files)
                try data.write(to: url)
            } catch {
                print(error)
            }
        }
    }
    
    
    func loadJSON(url: URL) {
        clear()
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedFiles = try decoder.decode([ListedFile].self, from: data)
            // Avoid duplicates
            let existingPaths = Set(files.map { $0.fullPath })
            let deduped = loadedFiles.filter { !existingPaths.contains($0.fullPath) }
            files.append(contentsOf: deduped)
        } catch {
            print("Error loading JSON: \(error)")
        }
    }
    
    // Load files from a JSON file
    @MainActor
    func loadJSONFromPanel() async {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["eplist"]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let loadedFiles = try decoder.decode([ListedFile].self, from: data)
                // Avoid duplicates
                let existingPaths = Set(files.map { $0.fullPath })
                let deduped = loadedFiles.filter { !existingPaths.contains($0.fullPath) }
                files.append(contentsOf: deduped)
            } catch {
                print("Error loading JSON: \(error)")
            }
        }
        saveToStore()
    }
}

private func filesRecursively(in directory: URL) -> [ListedFile] {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil)
    var files: [ListedFile] = []
    while let element = enumerator?.nextObject() as? URL {
        if !element.hasDirectoryPath, isSupported(element) {
            files.append(ListedFile(url: element))
        }
    }
    return files
}

private let supportedExtensions: Set<String> = ["mp3", "wav", "eplist"]

private func isSupported(_ url: URL) -> Bool {
    supportedExtensions.contains(url.pathExtension.lowercased())
}
