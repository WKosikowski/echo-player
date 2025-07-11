//
//  MenuBarPlayerView 2.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 11/07/2025.
//


import SwiftUI


struct PlaybackControlsView: View {
    @Bindable var vm: PlayerViewModel
    
    var body: some View {
        VStack() {
            HStack {
                Button(action: { vm.playPrev() }) {
                    Image(systemName: "backward.fill")
                        .font(.largeTitle)
                        
                }
                Button(action: { vm.togglePlay() }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 48))
                        
                }
                Button(action: { vm.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                        
                }
            }
            .padding()
            HStack {
                Text(formatTime(vm.playbackTime))
                    .font(.system(.caption, design: .monospaced))
                    .padding()
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
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
