//
//  VisualiserView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 08/07/2025.
//


import SwiftUI

// VisualiserView presents a real-time audio spectrum visualization as a colorful bar graph.
struct VisualiserView: View {
    // Access the PlayerViewModel, which provides the spectrum data
    @ObservedObject var vm: PlayerViewModel

    var body: some View {
        // Use GeometryReader to make the bars responsive to container size
        GeometryReader { geo in
            // Calculate each bar's width based on the total number of spectrum bins
            let barWidth = geo.size.width / CGFloat(vm.spectrum.count)
            // Arrange bars horizontally, aligned to the bottom with small spacing
            ZStack{
                Rectangle()
                    .fill(.blue)
                    .frame(width: geo.size.width, height: 5)
                HStack(alignment: .top, spacing: 1) {
                    Rectangle()
                        .frame(width: 0, height: 320)
                    // Iterate through all spectrum values to render each bar
                    ForEach(vm.spectrum.indices, id: \.self) { i in
                        // Assign a unique hue for each bar based on its position
                        let hue = Double(i) / Double(vm.spectrum.count) * 0.33
                        // Generate a vibrant color for the bar
                        let color = Color(hue: hue, saturation: 0.9, brightness: 1.0)
                        Rectangle()
                        // Fill each bar with a vertical gradient from transparent to full color
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.1), color]),
                                startPoint: .leading,
                                endPoint: .trailing))
                        // Set each bar's frame, scaling height according to spectrum value
                            .frame(width: barWidth,
                                   height: geo.size.height * CGFloat(vm.spectrum[i]))
                            .alignmentGuide(.bottom) { d in d[.bottom] }
                            .cornerRadius(3) // Slightly round bar corners
                            .shadow(color: color.opacity(0.8), radius: 8, x: 0, y: 0) // Add glowing shadow in bar's color
                    }
                }
            }
        }
        // Set a black background behind the bars
        .background(.black)
        // Clip the whole visualization to a rounded rectangle
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // Animate bar changes with a spring effect whenever spectrum changes
//        .animation(.interpolatingSpring(stiffness: 100, damping: 15), value: vm.spectrum)
    }
}
