//
//  FileListView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 09/07/2025.
//

import Combine
import SwiftUI

struct FileListView: View {
    @ObservedObject var model: FileListModel
    @ObservedObject var playerVM: PlayerViewModel

    init(model: FileListModel, playerVM: PlayerViewModel) {
        self.model = model
        self.playerVM = playerVM
    }

    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(model.files) { entry in
                    Text(entry.displayName)
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 2)
                        .onTapGesture(count: 2) {
                            print(entry.fullPath)
                            playerVM.playFile(url: URL(fileURLWithPath: entry.fullPath))
                        }
                }
                .onMove { indices, newOffset in
                    print("move")
                    model.files.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .frame(minHeight: 200, maxHeight: 300)
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async {
                                model.add(urls: [url])
                            }
                        } else if let url = item as? URL {
                            DispatchQueue.main.async {
                                model.add(urls: [url])
                            }
                        }
                    }
                }
                return true
            }

            HStack {
                Button("Clear List") { model.clear() }
                Spacer()
                Button("Load JSON") {
                    Task { await model.loadFromJSON() }
                }
                Spacer()
                Button("Save as JSON") {
                    Task { await model.saveToJSON() }
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(minWidth: 400, idealWidth: 440, minHeight: 320)
    }
}
