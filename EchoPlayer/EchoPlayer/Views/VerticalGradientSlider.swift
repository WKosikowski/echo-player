//
//  VerticalGradientSlider.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 09/07/2025.
//


import SwiftUI

/// VerticalGradientSlider.swift
///
/// A custom vertical slider component displaying a linear gradient track.
/// The slider includes a draggable thumb with a transparent horizontal window
/// that reveals the underlying gradient color at the current slider value.
///
/// - `VerticalGradientSlider`: The main slider view accepting a binding value and gradient.
/// - `ThumbView`: The draggable thumb shape displaying the current color.
/// - `Color` extension: Utility methods for color interpolation and component extraction.

public struct VerticalGradientSlider: View {
    @Binding var value: Float // Binding slider value normalized between 0 and 1
    var gradient: Gradient // Gradient defining the slider's color spectrum
    var sliderWidth: CGFloat = 40 // Width of the slider track
    var sliderHeight: CGFloat = 200 // Height of the slider track
    var thumbWidth: CGFloat = 40 // Width of the draggable thumb
    var thumbHeight: CGFloat = 32 // Height of the draggable thumb

    @State private var startValue: Float = 0.0 // Slider value captured at drag start for relative movement

    public init(value: Binding<Float>,
                gradient: Gradient,
                sliderWidth: CGFloat = 40,
                sliderHeight: CGFloat = 200,
                thumbWidth: CGFloat = 40,
                thumbHeight: CGFloat = 32)
    {
        _value = value
        self.gradient = gradient
        self.sliderWidth = sliderWidth
        self.sliderHeight = sliderHeight
        self.thumbWidth = thumbWidth
        self.thumbHeight = thumbHeight
    }

    public var body: some View {
        // The slider is composed of a vertical gradient track and a draggable thumb.
        // The ZStack aligns the gradient and thumb from the top.
        // The entire slider area is made tappable and draggable to update the slider value.
        ZStack(alignment: .top) {
            // Gradient track with rounded ends
            RoundedRectangle(cornerRadius: sliderWidth / 2)
                .fill(
                    LinearGradient(gradient: gradient,
                                   startPoint: .bottom,
                                   endPoint: .top)
                )
                .frame(width: sliderWidth,
                       height: sliderHeight)
            
            Rectangle()
                .size(CGSize(width: Double(sliderWidth), height: 1))
                .offset(x: 0, y: 0.5*sliderHeight - 1)

            // Draggable thumb showing the color at the current slider value
            ThumbView(colorAtThumb: .black,
                      width: thumbWidth,
                      height: thumbHeight)
                .offset(y: thumbOffsetY()) // Vertically position thumb according to slider value
        }
        .frame(width: sliderWidth, height: sliderHeight)
        .contentShape(Rectangle()) // Make entire slider tappable for gestures
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let travel = sliderHeight - thumbHeight
                    // Calculate new value based on vertical drag translation relative to slider height
                    let raw = Double(startValue) - g.translation.height / travel
                    value = Float(min(max(raw, -1), 1)) // Clamp value between 0 and 1
                }
                .onEnded { _ in startValue = value } // Update start value on drag end for continued dragging
        )
        .onAppear { startValue = value } // Initialize startValue when view appears
    }

    // MARK: Helpers

    /// Calculates the vertical offset for the thumb based on the current slider value.
    /// - Returns: The y-offset for positioning the thumb, where value 1 corresponds to top and 0 to bottom.
    private func thumbOffsetY() -> CGFloat {
        let travel = (sliderHeight - thumbHeight) / 2
        return travel * CGFloat((1 - value)) // Invert value so 1 is top offset, 0 is bottom offset
    }

    /// Determines the interpolated color at the current slider value within the gradient.
    /// - Returns: Color corresponding to the slider's current value by interpolating gradient stops.
    private func colorForCurrentValue() -> Color {
        let stops = gradient.stops
        guard stops.count > 1 else { return Color(stops.first?.color ?? .black) }

        var lower = stops.first!, upper = stops.last!
        for stop in stops {
            if stop.location <= Double(value) { lower = stop }
            if stop.location >= Double(value) { upper = stop; break }
        }

        let range = upper.location - lower.location
        let fraction = range > 0 ? (CGFloat(value) - lower.location) / range : 0
        return Color.interpolate(from: lower.color, to: upper.color, fraction: Float(fraction))
    }
}

/// The visual thumb component of the slider.
/// Consists of a semi-transparent circular background with a horizontal colored rectangle
/// representing the current gradient color under the thumb.
private struct ThumbView: View {
    var colorAtThumb: Color // Color sample at current slider value
    var width: CGFloat // Thumb width
    var height: CGFloat // Thumb height

    var body: some View {
        ZStack {
            // Circular translucent background with shadow for depth
            Circle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: width, height: height)
                .shadow(radius: 3)

            // Horizontal rectangle showing the actual color at the thumb's position
            Rectangle()
                .fill(colorAtThumb)
                .frame(width: width - 12, height: height / 3)
                .cornerRadius(height / 8)
                .opacity(0.9)
        }
    }
}

private extension Color {
    /// Performs linear interpolation between two Colors in sRGB color space.
    /// - Parameters:
    ///   - from: Starting color
    ///   - to: Ending color
    ///   - fraction: Interpolation fraction between 0 and 1
    /// - Returns: Interpolated Color
    static func interpolate(from: Color, to: Color, fraction: Float) -> Color {
        let f = from.components, t = to.components
        return Color(.sRGB,
                     red: Double(f.r + (t.r - f.r) * fraction),
                     green: Double(f.g + (t.g - f.g) * fraction),
                     blue: Double(f.b + (t.b - f.b) * fraction),
                     opacity: Double(f.a + (t.a - f.a) * fraction))
    }

    /// Extracts the RGBA components of the Color in sRGB space.
    /// - Returns: Tuple containing red, green, blue, and alpha components as Doubles.
    var components: (r: Float, g: Float, b: Float, a: Float) {
        #if canImport(UIKit)
            typealias NativeColor = UIColor
        #else
            typealias NativeColor = NSColor
        #endif

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let native = NativeColor(self)

        #if canImport(UIKit)
            guard native.getRed(&r, green: &g, blue: &b, alpha: &a) else { return (0, 0, 0, 1) }
        #else
            guard let rgb = native.usingColorSpace(.deviceRGB) else { return (0, 0, 0, 1) }
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        return (Float(r), Float(g), Float(b), Float(a))
    }
}

#Preview {
    /// Preview demonstrating the VerticalGradientSlider with a blue-to-red gradient,
    /// customized dimensions and thumb size, embedded in a padded white background.
    struct PreviewWrapper: View {
        @State private var value: Float = 0.9
        var body: some View {
            VerticalGradientSlider(
                value: $value,
                gradient: Gradient(colors: [.blue, .green, .yellow, .red]),
                sliderWidth: 44,
                sliderHeight: 320,
                thumbWidth: 44,
                thumbHeight: 36
            )
            .padding(40)
            .background(Color.white)
        }
    }
    return PreviewWrapper()
}
