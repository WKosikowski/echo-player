/*
 MetalSumVisualiserShaders.metal

 This Metal shader file visualizes a sum of sine waves—each with independent amplitude, phase, and frequency—across multiple frequency bins. It is designed for real-time audio or signal visualization, such as in spectrum or sum visualizer applications.

 Key Components:
 - Uniforms: Contains the bin count, controlling how many sine components are summed.
 - VertexOut: Structure passed from vertex to fragment shader, contains position and color.
 - vertexShader: Computes the position and color for each vertex along a line, summing the sinusoids and mapping the result to normalized device coordinates (NDC) and a vibrant color along the x-axis using HSV-to-RGB conversion.
 - fragmentShader: Outputs the color computed in the vertex stage.

 The x-axis maps each vertex evenly in NDC space; the y-axis is the normalized, clamped sum of all sine wave contributions for each vertex. This produces a dynamic, colorful waveform visual across the rendered geometry.
*/

#include <metal_stdlib>
#define M_PI 3.14159265358979323846

using namespace metal;

// Uniforms struct: Holds the number of bins (sine components) to sum
struct Uniforms {
    uint   binCount;
};

// Vertex output struct: Carries final position and color to fragment shader
struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// Vertex shader: Sums multiple sine waves, computes position (xy) and color for each vertex
vertex VertexOut vertexShader(
    uint vertexID [[vertex_id]],                                 // Current vertex index (0...N)
    const device float *amplitudes [[buffer(0)]],                // Array of amplitudes (per bin)
    const device float *phases [[buffer(1)]],                    // Array of phases (per bin)
    const device float *frequencies [[buffer(2)]],               // Array of frequencies (per bin)
    constant Uniforms &uniforms [[buffer(3)]]                    // Uniforms, contains binCount
) {
    VertexOut out;
    
    // Map vertexID to normalized device coordinate [-1, 1] along x
    float nx = float(vertexID) / float(1023) * 2.0 - 1.0;
    // Map vertexID to [0, 2π] for use as input to sine wave sum
    float fx = float(vertexID) / float(1023) * 2.0 * float(M_PI);

    // Sum all sine waves with given amplitude, phase, frequency
    float signal = 0.0;
    for (uint i = 0; i < uniforms.binCount; ++i) {
        float freq = frequencies[i];          // Frequency for this component
        float omega = 2 * M_PI * freq;        // Angular frequency
        float phase = phases[i];              // Phase offset
        float amp = amplitudes[i];            // Amplitude
        signal += amp * sin(omega * fx + phase); // Sum for this bin
    }
    // Normalize result to [-1, 1] (approximate maximum sum)
    float maxSum = float(uniforms.binCount);
    signal = clamp(signal / maxSum, -1.0, 1.0);
    // Set y position as the signal value (vertical, waveform)
    float ny = signal;
    out.position = float4(nx, ny, 0, 1);

    // Assign color by mapping x-position to hue (rainbow across x axis)
    float hue = float(vertexID) / 1023.0;     // [0, 1] hue
    float s = 1.0, v = 1.0;                   // Full saturation, value
    float c = v * s;
    float hh = hue * 6.0;
    float x = c * (1.0 - fabs(fmod(hh, 2.0) - 1.0));
    float3 rgb;
    // HSV to RGB conversion using sector logic
    if (hh < 1.0)      rgb = float3(c, x, 0);
    else if (hh < 2.0) rgb = float3(x, c, 0);
    else if (hh < 3.0) rgb = float3(0, c, x);
    else if (hh < 4.0) rgb = float3(0, x, c);
    else if (hh < 5.0) rgb = float3(x, 0, c);
    else              rgb = float3(c, 0, x);
    float m = v - c;
    out.color = float4(rgb + m, 1.0);
    return out;
}

// Fragment shader: Outputs the color determined in the vertex shader
fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
