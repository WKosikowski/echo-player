//
//  SineVisualiserView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 09/07/2025.
//


import SwiftUI
import MetalKit
import AppKit

// MARK: - SineVisualiserView

/// A SwiftUI view that visualizes a set of sine waves using spectrum (amplitude) and phase data from the PlayerViewModel.
/// Each spectrum bin is rendered as an overlaid colored sine wave, with frequency increasing per bin and color mapped to bin index.
struct SineVisualiserView: View {
    @ObservedObject private var vm: PlayerViewModel // View model providing spectrum and phase data
    init(vm: PlayerViewModel){
        self.vm = vm
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Draw one sine wave path for each spectrum/phase bin
                ForEach(vm.spectrum.indices, id: \.self) { i in
                    // Amplitude for this bin (scaled to half view height)
                    let amplitude = Double(vm.spectrum[i]) * geo.size.height * 0.5
                    // Frequency (periods) increases with bin index
                    let minPeriods = 2.1
                    let maxPeriods = 16.0
                    let freq = minPeriods + (maxPeriods - minPeriods) * (Double(i) / Double(max(vm.spectrum.count - 1, 1)))
                    // Phase offset for this bin
                    let phase = Double(vm.spectrumPhase[i])
                    // Color: hue based on bin index, fully saturated/bright, semi-transparent
                    let hue = Double(i) / Double(vm.spectrum.count)
                    let color = Color(hue: hue, saturation: 1, brightness: 1, opacity: 0.5)
                    Path { path in
                        let width = geo.size.width
                        let midY = geo.size.height / 2
                        path.move(to: CGPoint(x: 0, y: midY))
                        let steps = Int(width) // Sample points across the width
                        // Plot the sine wave by connecting points across the width
                        for x in 0...steps {
                            let fx = Double(x) / Double(steps) * 2 * .pi
                            let y = midY + amplitude * sin(freq * fx + phase)
                            path.addLine(to: CGPoint(x: Double(x), y: y))
                        }
                    }
                    .stroke(color, lineWidth: 1)
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            // Animate spectrum changes with springy effect
            .animation(.interpolatingSpring(stiffness: 120, damping: 15), value: vm.spectrum)
        }
    }
}
