//
//  MenuBarPlayerView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 11/07/2025.
//

import SwiftUI

struct MenuBarPlayerView: View {
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
