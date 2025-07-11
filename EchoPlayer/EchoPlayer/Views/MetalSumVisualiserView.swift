//
//  MetalSumVisualiserView.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 11/07/2025.
//

import AppKit
import MetalKit
import SwiftUI

/// A SwiftUI wrapper for an MTKView that renders a dynamic sum of sine waves using Metal shaders.
/// This view passes amplitude, phase, and frequency buffers (from PlayerViewModel) to the GPU, where the Metal shader generates the summed waveform and assigns color per vertex.
struct MetalEnvelopeVisualiserView: NSViewRepresentable {
    @Bindable var vm: PlayerViewModel // View model providing spectrum and phase data

    func makeCoordinator() -> RendererCoordinator {
        RendererCoordinator(vm: vm)
    }

    // Create and configure the MTKView (MetalKit view), assign delegate
    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported on this device")
        }
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 60
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    // Update the coordinator's reference to the current PlayerViewModel (needed for live data)
    func updateNSView(_: MTKView, context: Context) {
        context.coordinator.vm = vm
    }

    /// Coordinator class responsible for all Metal setup and rendering logic.
    /// Prepares Metal buffers and pipeline, updates GPU data each frame, and encodes draw calls.
    class RendererCoordinator: NSObject, MTKViewDelegate {
        var vm: PlayerViewModel // Provides live spectrum and phase
        weak var mtkView: MTKView?

        // Metal objects and pipeline
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLRenderPipelineState

        // Buffers for amplitudes, phases, and frequencies (updated each frame)
        var amplitudesBuffer: MTLBuffer?
        var phasesBuffer: MTLBuffer?
        var frequenciesBuffer: MTLBuffer?

        // Maximum number of output vertices (resolution of the line strip)
        let maxVertices = 1024

        // Structure matching the Metal shader's Uniforms
        struct Uniforms {
            var binCount: UInt32
        }

        var uniforms = Uniforms(binCount: 64)
        var uniformsBuffer: MTLBuffer?

        // Set up Metal device, command queue, pipeline, and uniform buffer
        init(vm: PlayerViewModel) {
            self.vm = vm
            guard let dev = MTLCreateSystemDefaultDevice(),
                  let queue = dev.makeCommandQueue()
            else {
                fatalError("Failed to create Metal device or command queue")
            }
            device = dev
            commandQueue = queue

            // Load vertex/fragment shader functions from the app's Metal library
            let library = try! device.makeDefaultLibrary(bundle: .main)
            let vertexFunc = library.makeFunction(name: "vertexShader")!
            let fragmentFunc = library.makeFunction(name: "fragmentShader")!

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunc
            pipelineDescriptor.fragmentFunction = fragmentFunc
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("Failed to create pipeline state: \(error)")
            }

            super.init()

            // Allocate buffer for uniforms
            uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        }

        // Main rendering function, called each frame by MTKView
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }

            // Fetch latest spectrum (amplitudes) and phase arrays from the view model
            let amplitudes = vm.spectrum
            let phases = vm.spectrumPhase

            // Number of frequency bins (one wave per bin)
            let binCount = amplitudes.count

            // Calculate frequency for each bin, smoothly from minPeriods to maxPeriods
            let minPeriods: Float = 2.1
            let maxPeriods: Float = 16.0
            var frequencies = (0 ..< binCount).map { i in
                let t = Float(i) / max(Float(binCount - 1), 1)
                let freq = minPeriods + (maxPeriods - minPeriods) * t
                return freq
            }

            // Update uniforms struct and GPU buffer
            uniforms.binCount = UInt32(binCount)
            if let uniformsBuffer = uniformsBuffer {
                let ptr = uniformsBuffer.contents()
                ptr.copyMemory(from: &uniforms, byteCount: MemoryLayout<Uniforms>.stride)
            }

            // Ensure amplitudes buffer is large enough, then upload data
            let amplitudesSize = binCount * MemoryLayout<Float>.stride
            if amplitudesBuffer == nil || amplitudesBuffer!.length < amplitudesSize {
                amplitudesBuffer = device.makeBuffer(length: amplitudesSize, options: [])
            }
            if let amplitudesBuffer = amplitudesBuffer {
                let ptr = amplitudesBuffer.contents()
                amplitudes.withUnsafeBytes { srcPtr in
                    ptr.copyMemory(from: srcPtr.baseAddress!, byteCount: amplitudesSize)
                }
            }

            // Ensure phases buffer is large enough, then upload data
            let phasesSize = binCount * MemoryLayout<Float>.stride
            if phasesBuffer == nil || phasesBuffer!.length < phasesSize {
                phasesBuffer = device.makeBuffer(length: phasesSize, options: [])
            }
            if let phasesBuffer = phasesBuffer {
                let ptr = phasesBuffer.contents()
                phases.withUnsafeBytes { srcPtr in
                    ptr.copyMemory(from: srcPtr.baseAddress!, byteCount: phasesSize)
                }
            }

            // Ensure frequencies buffer is large enough, then upload data
            let frequenciesSize = binCount * MemoryLayout<Float>.stride
            if frequenciesBuffer == nil || frequenciesBuffer!.length < frequenciesSize {
                frequenciesBuffer = device.makeBuffer(length: frequenciesSize, options: [])
            }
            if let frequenciesBuffer = frequenciesBuffer {
                let ptr = frequenciesBuffer.contents()
                frequencies.withUnsafeBytes { srcPtr in
                    ptr.copyMemory(from: srcPtr.baseAddress!, byteCount: frequenciesSize)
                }
            }

            // Create command buffer and encoder for draw call
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

            renderEncoder.setRenderPipelineState(pipelineState)

            // Pass Metal buffers to the vertex shader (indices must match shader code)
            if let amplitudesBuffer = amplitudesBuffer {
                renderEncoder.setVertexBuffer(amplitudesBuffer, offset: 0, index: 0)
            }
            if let phasesBuffer = phasesBuffer {
                renderEncoder.setVertexBuffer(phasesBuffer, offset: 0, index: 1)
            }
            if let frequenciesBuffer = frequenciesBuffer {
                renderEncoder.setVertexBuffer(frequenciesBuffer, offset: 0, index: 2)
            }
            if let uniformsBuffer = uniformsBuffer {
                renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 3)
            }

            // Draw all vertices as a line strip (joined polyline)
            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: maxVertices)

            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        // Handle view resize (not used here, but required by MTKViewDelegate)
        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
            // Handle size changes if needed
        }
        // All CPU-side waveform logic is removed; GPU shader generates waveform and color.
    }
}
