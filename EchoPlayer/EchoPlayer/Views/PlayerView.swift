//
//  PlayerView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI

//HStack(spacing: 20) {
//    Button(action: showPlaylist) {
//        Image(systemName: "music.note.list")
//    }
//
//    Button(action: detachPlaylist) {
//        Image(systemName: "square.split.2x1")
//    }
//
//    Button(action: toggleLoopSingle) {
//        Image(systemName: "repeat.1")
//    }
//
//    Button(action: toggleLoopAll) {
//        Image(systemName: "repeat")
//    }
//
//    Button(action: toggleVisualizer) {
//        Image(systemName: "waveform")
//    }
//}
//.font(.system(size: 18))
//.buttonStyle(.plain)

//•    music.note.list is clear for “open/show playlist.”
//•    square.split.2x1 evokes an undocked or split‐out pane.
//•    repeat.1 vs. repeat match single‐track vs. full‐album looping.
//•    waveform (or if you want a badge, waveform.circle) suggests audio visualization.
//                                    
//




struct PlayerView: View {
    @Bindable var vm: PlayerViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button(action: { vm.playPrev() }) {
                        Image(systemName: "backward.fill")
                            .font(.largeTitle)
                    }
                    Button(action: { vm.togglePlay() }) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 64))
                    }
                    Button(action: { vm.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.largeTitle)
                    }
                }
                
                Slider(value: $vm.volume, in: 0 ... 1)
                    .accentColor(.blue)
                    .padding()
                    .frame(width: 200, height: 50)
                    .offset(x: 250)
                
                Button(action: vm.openFile) {
                    Label("Open", systemImage: "folder")
                }
                .offset(x: -200)
                
                Button(action: {
                    if !vm.joinWindows {
                        openWindow(id: "playlist")
                    }
                }) {
                    Label("Open Saved List", systemImage: "document")
                }
                .offset(x: -320)
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
            HStack{
                Spacer()
                    HStack(spacing: 8) {
                        ForEach(0 ..< 12, id: \.self) { idx in
                            VStack {
                                VerticalGradientSlider(value: Binding(get: {
                                    vm.gains[idx] / 24
                                }, set: { vm.updateGain(band: idx, value: $0)
                                }), gradient: Gradient(colors: [.green, .yellow, .red]))
                                Text(label(for: idx))
                                    .font(.caption)
                            }
                            .padding(.vertical)
                        }
                }
                Spacer()
            }
        
            Text("Gain ±24 dB per band")
                .font(.footnote)
                .foregroundColor(.secondary)

            VStack {
                Slider(value: $vm.globalGain, in: -24 ... 24, step: 1)
                    .frame(width: 120, alignment: .bottom)
                Text("Global Gain")
                    .font(.caption)
            }
            .padding(.vertical)

            if vm.visualiserMode == .spectrum {
                VisualiserView(vm: vm)
                    .padding(.horizontal)
            } else if vm.visualiserMode == .sine {
                SineVisualiserView(vm: vm)
                    .padding(.horizontal)
            } else if vm.visualiserMode == .metalSum {
//                MetalSumVisualiserView()
//                    .frame(height: 150)
//                    .padding(.horizontal)
            }
            HStack {
                Button("Spectrum") { vm.visualiserMode = .spectrum; print(vm.visualiserMode) }
                Button("Sine waves") { vm.visualiserMode = .sine }
                Button("Metal Sum") { vm.visualiserMode = .metalSum }
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 4)

            Toggle(isOn: $vm.showDbs) {
                Text("Enable Decibel Scale")
            }
            .toggleStyle(.checkbox) // macOS only; for iOS use a custom style
            .padding()

            Toggle(isOn: $vm.joinWindows) {
                Text("Join Windows")
            }
            .toggleStyle(.checkbox) // macOS only; for iOS use a custom style
            .padding()
            .onChange(of: vm.joinWindows) { _, newValue in
                if newValue {
                    dismissWindow(id: "playlist")
                }
            }
//            .onSubmit {
//                if vm.joinWindows {
//                    openWindow(id: "playlist")
//                } else {
//                    dismissWindow(id: "playlist")
//                }
//            }

            Spacer()
        }
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func label(for i: Int) -> String {
        ["32", "64", "128", "250", "500", "1k", "2k", "4k", "8k", "12k", "14k", "16k"][i]
    }
}

// #Preview {
//    PlayerView()
// }
