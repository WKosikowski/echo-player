//
//  VisualiserView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 08/07/2025.
//

import SwiftUI

// VisualiserView presents a real-time audio spectrum visualization as a colorful bar graph.
// VisualiserView presents a real-time audio spectrum visualization as a colorful bar graph.
struct VisualiserView: View {
    // Access the PlayerViewModel, which provides the spectrum data
    @Bindable var vm: PlayerViewModel

    var body: some View {
        // Use GeometryReader to make the bars responsive to container size
        GeometryReader { geo in
            // Calculate each bar's width based on the total number of spectrum bins
            let barWidth = (geo.size.width - CGFloat(vm.spectrum.count) - 1) / CGFloat(vm.spectrum.count)
            // Arrange bars horizontally, aligned to the bottom with small spacing
            ZStack {
                Canvas { context, size in
                    let spectrum = vm.spectrum
                    let barSpacing: CGFloat = 2
                    let barCount = spectrum.count
                    guard barCount > 0 else { return }
                    let barWidth = (size.width - barSpacing * CGFloat(barCount - 1)) / CGFloat(barCount)
                    let normalLine = CGRect(x: 0, y: size.height * 0.5, width: size.width, height: 1)
                    context.fill(Path(normalLine), with: .color(.white))

                    for i in 0 ..< barCount {
                        let value = spectrum[i]
                        let hue = Double(i) / Double(barCount) * 0.33
                        let color = Color(hue: hue, saturation: 0.9, brightness: 1.0)
                        let x = CGFloat(i) * (barWidth + barSpacing)
                        let barHeight = size.height * CGFloat(value)
                        let barRect = CGRect(x: x, y: size.height * 0.5 - barHeight * 0.5, width: barWidth, height: barHeight)
                        // Make a vertical gradient from transparent at bottom to color at top
                        let gradient = Gradient(stops: [
                            .init(color: color.opacity(0.1), location: 0.0),
                            .init(color: color, location: 1.0),
                        ])
                        context.fill(Path(roundedRect: barRect, cornerRadius: 3), with: .color(color))
                        context.fill(Path(roundedRect: barRect, cornerRadius: 3), with: .conicGradient(gradient, center: CGPoint(x: barRect.midX, y: barRect.midY)))
                        //                    context.fill(Path(roundedRect: barRect, cornerRadius: 3), with: .linearGradient(gradient,
                        //                                                                                                    startPoint: CGPoint(x: barRect.midX, y: barRect.maxY),
                        //                                                                                                    endPoint: CGPoint(x: barRect.midX, y: barRect.minY)))
                    }
                }
//                HStack {
//                    ForEach(0 ..< vm.spectrum.count) { i in
//                        Text("\(vm.spectrum[i])")
//                    }
//                }
            }
        }
        // Set a black background behind the bars
        .background(.black)
        // Clip the whole visualization to a rounded rectangle
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // Animate bar changes with a spring effect whenever spectrum changes
    }
}
