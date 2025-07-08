//
//  PlayerView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI

struct AudioKitPlayerView: View {
    @State var vm = PlayerViewModel()
    @State var someval = 0.0
    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.largeTitle)
                    }
                    Button(action: { vm.play() }) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 64))
                    }
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.largeTitle)
                    }
                }

                Slider(value: $someval, in: 0 ... 1)
                    .accentColor(.blue)
                    .padding()
                    .frame(width: 200, height: 50)
                    .offset(x: 250)

                Button(action: vm.openFile) {
                    Label("Open", systemImage: "folder")
                }
                .offset(x: -250)
            }
            .padding()

            HStack {
                Text(formatTime(vm.playbackTime))
                    .font(.system(.caption, design: .monospaced))
                Slider(value: Binding(
                    get: { vm.playbackProgress },
                    set: { vm.playbackProgress = $0 }
                ), in: 0 ... 1, onEditingChanged: { editing in
                    if !editing { vm.seek(to: vm.playbackProgress) }
                })
                .frame(minWidth: 120)
                Text(formatTime(vm.duration))
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(.horizontal)
            .disabled(vm.duration <= 0)
            Spacer()
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    AudioKitPlayerView()
}
