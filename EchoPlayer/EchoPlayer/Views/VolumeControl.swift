//
//  VolumeControl.swift
//  EchoPlayer
//
//  Created by Mateusz Kosikowski on 10/07/2025.
//

import SwiftUI

struct VolumeControl: View {
    @Binding var volume: Float // 0…1
    @State var lastVolume: Float
    var body: some View {
        HStack {
            // choose the right icon based on volume level
            Image(systemName: iconName(for: volume))
                .font(.system(size: 20))
                .onTapGesture {
                    toggleMute()
                }

            Slider(value: $volume)
                .frame(width: 100)
        }
    }

    private func iconName(for v: Float) -> String {
        switch v {
        case 0:
            return "speaker.slash.fill"
        case 0 ..< 0.33:
            return "speaker.wave.1.fill"
        case 0.33 ..< 0.66:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    private func toggleMute() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if volume > 0 {
                lastVolume = volume
                volume = 0
            } else {
                volume = lastVolume
            }
        }
    }
}

// Muted
// speaker.slash.fill
// Speaker with a slash for “off”
// Low volume
// speaker.wave.1.fill
// One wave line
// Medium volume
// speaker.wave.2.fill
// Two wave lines
// High volume
// speaker.wave.3.fill
// Three wave lines
// Speaker only
// speaker.fill
// Solid speaker glyph, no waves
