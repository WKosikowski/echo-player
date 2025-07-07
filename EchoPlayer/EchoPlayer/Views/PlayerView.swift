//
//  ContentView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI

struct PlayerView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Playback Controls
            HStack(spacing: 40) {
                Button( action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.largeTitle)
                }
                Button(action: {}) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 64))
                }
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }
            }
            
            // Progress Bar (non-functional seeking due to AVAudioEngine limits)
            VStack {
//                Slider(value: )
                HStack {
                    Text("Current Time")
                    Spacer()
                    Text("Duration")
                }
            }.padding(.horizontal)
            
            // Volume Control
            VStack {
                Text("Volume")
//                Slider(value:
//                , set: { newVal in
//                }), in: 0...1)
            }.padding(.horizontal)
            
            // Playback Speed
            VStack {
                Text("Playback Speed:")
//                Slider(value: Binding(get: {
//                }, set: { newVal in
//                }), in: 0.5...2.0)
            }.padding(.horizontal)
            
            // Equalizer (10 bands)
            VStack(spacing: 10) {
                Text("Equalizer")
                HStack {
                    ForEach(0..<10) { band in
                        VStack {
//                            Slider(value: Binding(get: {
//                            }, set: { newVal in
//                            }), in: -12...12)
//                            .rotationEffect(.degrees(-90))
//                            .frame(height: 150)
                            Text("\(eqBandFrequency(band: band)) Hz")
                                .font(.caption2)
                        }
                    }
                }
            }.padding()
            
            Spacer()
        }
        .padding()
    }
    
    func timeString(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    func eqBandFrequency(band: Int) -> Int {
        // Match frequencies from CrossfadeAudioPlayer
        let freqs = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        return band < freqs.count ? freqs[band] : 0
    }
}

#Preview {
    PlayerView()
}
