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

        WindowGroup("Visualiser", id: "visualiser fullscreen") {
            if vm.visualiserMode == .spectrum {
                VisualiserView(vm: vm)
                    .onDisappear { vm.visualiserFullScreen = false }
            } else if vm.visualiserMode == .sine {
                SineVisualiserView(vm: vm)
                    .onDisappear { vm.visualiserFullScreen = false }
            } else if vm.visualiserMode == .metalSum {
                MetalEnvelopeVisualiserView(vm: vm)
                    .onDisappear { vm.visualiserFullScreen = false }
            }
        }
        .handlesExternalEvents(matching: ["fullscreen"])

        WindowGroup("Playlist", id: "playlist") {
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
            PlaybackControlsView(vm: vm)
            FileListView(model: vm)
                .padding(.vertical)

        } label: {
            MenuBarPlayerView(vm: vm)
                .frame(minWidth: 80, maxWidth: 100)
                .background(.blue)
        }
        .menuBarExtraStyle(.window)
    }
}
