//
//  PlayerView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI

struct AudioKitPlayerView: View {
    @StateObject var vm = PlayerViewModel()
    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.largeTitle)
                    }
                    Button(action: { vm.togglePlay() }) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 64))
                    }
                    Button(action: {}) {
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

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(0 ..< 12, id: \.self) { idx in
                        VStack {
                            Slider(value: Binding(
                                get: { vm.gains[idx] },
                                set: { vm.updateGain(band: idx, value: $0) }
                            ),
                            in: -24 ... 24, step: 1)
                                .frame(width: 120, alignment: .bottom)
                            Text(label(for: idx))
                                .font(.caption)
                        }
                        .padding(.vertical)
                    }
                }
                .padding(.horizontal)
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

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 420)
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

#Preview {
    AudioKitPlayerView()
}
