//
//  FileListView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 09/07/2025.
//

import Combine
import SwiftUI

struct FileListView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(model.files) { entry in
                    Text(entry.name)
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 2)
                        .onTapGesture(count: 2) {
                            model.play(id: entry.id)
                        }
                }
                .onMove { indices, newOffset in
                    model.files.move(fromOffsets: indices, toOffset: newOffset)
                    print(indices)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .frame(minHeight: 300)
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                Task {
                    await model.acceptDrop(from: providers)
                }
                return true
            }

            HStack {
                Spacer()
                Button {
                    model.clear()
                } label: {
                    Image(systemName: "clear")
                }
                Button {
                    Task { await model.loadPlaylist() }
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
                Button {
                    Task { await model.saveToJSON() }
                } label: {
                    Image(systemName: "tray.and.arrow.up")
                }
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(minWidth: 400, idealWidth: 440, minHeight: 320)
    }
}
