//
//  EchoPlayerApp.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI

@main
struct EchoPlayerApp: App {
    @StateObject var vm = PlayerViewModel()
    @StateObject var model = FileListModel()

    var body: some Scene {
        WindowGroup {
            PlayerView(vm: vm)
        }
        WindowGroup("Playlist View", id: "playlist") {
            FileListView(model: model, playerVM: vm)
        }
    }
}
