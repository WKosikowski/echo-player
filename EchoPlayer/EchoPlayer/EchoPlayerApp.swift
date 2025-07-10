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
//    @State var fileModel = FileListModel()
    @State private var mainWindowIsOpen = true
    @State private var playlistWindowIsOpen = true

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            HStack {
                PlayerView(vm: vm)
                    .onDisappear {
                        mainWindowIsOpen = false
                        playlistWindowIsOpen = false
                    }
                    .frame(minWidth: 800, minHeight: 800)
                if vm.joinWindows {
                    FileListView(model: vm)
                    
                        .onDisappear {
                            mainWindowIsOpen = false
                            playlistWindowIsOpen = false
                        }
                        .frame(maxWidth: 400)
                }
            }
        }
        
        
            WindowGroup("Playlist", id: "playlist") {
                //            FileListView(model: fileModel, playerVM: vm)
                FileListView(model: vm)
                
                    .onDisappear {
                        mainWindowIsOpen = false
                        playlistWindowIsOpen = false
                    }
                    .onDisappear {
                        vm.joinWindows = true
                    }
            }
            

        MenuBarExtra {
//            FileListView(model: fileModel, playerVM: vm)
            FileListView(model: vm)

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
