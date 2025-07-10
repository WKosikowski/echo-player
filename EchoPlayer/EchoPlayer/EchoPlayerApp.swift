//
//  EchoPlayerApp.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI

@main
struct EchoPlayerApp: App {
    @State var vm = PlayerViewModel()
    @State var fileModel = FileListModel()
    @State private var mainWindowIsOpen = true
    @State private var playlistWindowIsOpen = true

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            PlayerView(vm: vm)
                .onDisappear {
                    mainWindowIsOpen = false
                    playlistWindowIsOpen = false
                }
        }
        WindowGroup("Playlist", id: "playlist") {
            FileListView(model: fileModel, playerVM: vm)
                .onDisappear {
                    mainWindowIsOpen = false
                    playlistWindowIsOpen = false
                }
        }

        MenuBarExtra {
            FileListView(model: fileModel, playerVM: vm)
        } label: {
            MiniPlayerView(vm: vm)
                .frame(minWidth: 80, maxWidth: 100)
                .background(.blue)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MiniPlayerView: View {
    @Bindable var vm: PlayerViewModel

    var body: some View {
        ZStack(alignment: .leading) {
            Text(vm.menuBarText)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
