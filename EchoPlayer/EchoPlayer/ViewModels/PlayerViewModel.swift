//
//  PlayerViewModel.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import Accelerate
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PlayerViewModel: ObservableObject {
    enum VisualiserMode {
        case spectrum, sine, metalSum
    }

    // Published UI state
    @Published var showDbs = false
    @Published var spectrumDbMax: Float = 90
    @Published var log: Bool = false
    @Published var isPlaying = false
    @Published var gains: [Float] = Array(repeating: 0, count: 12)
    @Published var spectrum: [Float] = Array(repeating: 0, count: 64) // 0‥1
    @Published var spectrumPhase: [Float] = Array(repeating: 0, count: 64)
    @Published var visualiserMode: VisualiserMode = .spectrum
    @Published var volume: Float = 1.0 {
        didSet {
            player.volume = volume
        }
    }

    @Published var globalGain: Float = -12.0 {
        didSet {
            eq.globalGain = globalGain
        }
    }

    @Published var assetFileName: String = ""

    // Playback progress properties
    @Published var playbackProgress: Double = 0.0
    @Published private(set) var playbackTime: Double = 0.0
    @Published private(set) var duration: Double = 0.0

    // Audio graph
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 12)
    private var audioFile: AVAudioFile?

    private var timer: Timer?

    // FFT helpers (single‑precision, 512 points)
    private let fftSize = 512
    private let fftSetup = vDSP.FFT(log2n: 9, radix: .radix2, ofType: DSPSplitComplex.self)! // 2⁹ = 512
    private var window = [Float](repeating: 0, count: 512)
    private var fftReal = [Float](repeating: 0, count: 512)
    private var fftImag = [Float](repeating: 0, count: 512)

    init() {
        configureEQ()
        setupEngine()
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: fftSize, isHalfWindow: false)
        setupTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
        }
    }

    private func updatePlaybackTime() {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime),
              let file = audioFile
        else {
            playbackTime = 0
            playbackProgress = 0
            return
        }
        let currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        playbackTime = currentTime
        duration = Double(file.length) / file.fileFormat.sampleRate
        if duration > 0 {
            playbackProgress = min(max(currentTime / duration, 0), 1)
        } else {
            playbackProgress = 0
        }
    }

    private func setupEngine() {
        engine.attach(player)
        engine.attach(eq)
        engine.connect(player, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        try? engine.start()
        installTap()
    }

    func seek(to progress: Double) {
        guard let file = audioFile else { return }
        let seekTime = progress * (Double(file.length) / file.fileFormat.sampleRate)
        player.stop()
        // Schedule file from seekTime
        let sampleRate = file.processingFormat.sampleRate
        let startSampleTime = AVAudioFramePosition(seekTime * sampleRate)
        let length = AVAudioFrameCount(file.length - startSampleTime)
        playbackProgress = progress

        do {
            if length > 0 {
                player.scheduleSegment(file, startingFrame: startSampleTime, frameCount: length, at: nil) {
//                    DispatchQueue.main.async { [weak self] in
//                        self?.isPlaying = false
//                    }
                }
            }
        }
        play()
        print(playbackProgress, playbackTime)
    }

    // Tap post‑EQ for visualiser
    private func installTap() {
        let mixer = engine.mainMixerNode
        mixer.removeTap(onBus: 0)
        mixer.installTap(onBus: 0,
                         bufferSize: AVAudioFrameCount(1024),
                         format: mixer.outputFormat(forBus: 0))
        { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
    }

    private func configureEQ() {
        let freqs: [Float] = [32, 64, 128, 256, 512, 1000, 2000, 4000, 8000, 12000, 14000, 16000]
        for (i, band) in eq.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = freqs[i]
            band.bandwidth = 1.0 // octaves
            band.gain = 0
            band.bypass = false
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .wav, .mpeg4Audio, .aiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                audioFile = try AVAudioFile(forReading: url)

                assetFileName = url.lastPathComponent
                let avAsset = AVURLAsset(url: url)

                player.stop()
                if let file = audioFile {
                    player.scheduleFile(file, at: nil)
                    duration = Double(file.length) / file.fileFormat.sampleRate
                    playbackProgress = 0
                    playbackTime = 0
                    play()
                }
            } catch { print("Error loading file: \(error)") }
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let src = buffer.floatChannelData?.pointee,
              buffer.frameLength >= fftSize else { return }

        // Copy first 512 samples & apply Hann window
        fftReal.withUnsafeMutableBufferPointer { dst in
            dst.baseAddress?.update(from: src, count: fftSize)
        }
        vDSP.multiply(fftReal, window, result: &fftReal)
        fftImag = Array(repeating: 0, count: fftSize) // zero imag

        // Forward FFT (in‑place)
        fftReal.withUnsafeMutableBufferPointer { realBuf in
            fftImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                fftSetup.forward(input: split, output: &split)

                // Magnitude spectrum
                var mags = [Float](repeating: 0, count: fftSize / 2)
                vDSP.absolute(split, result: &mags) // |⟂|

                // Phase spectrum
                var phases = [Float](repeating: 0, count: fftSize / 2)
                for bin in 0 ..< (fftSize / 2) {
                    phases[bin] = atan2f(split.imagp[bin], split.realp[bin])
                }

                // Mean‑downsample to 64 bins
                let bins = 64, step = mags.count / bins
                var reduced = [Float](repeating: 0, count: bins)
                for i in 0 ..< bins {
                    let slice = mags[(i * step) ..< ((i + 1) * step)]
                    let mag = vDSP.mean(slice)
                    // Convert magnitudes to dB and normalize for logarithmic visualizer
                    if showDbs {
                        reduced[i] = 20 * log10(max(mag, 1e-7))
                    } else {
                        reduced[i] = mag
                    }
                }

                // Also downsample phases similarly
                var reducedPhase = [Float](repeating: 0, count: bins)
                for i in 0 ..< bins {
                    let slice = phases[(i * step) ..< ((i + 1) * step)]
                    reducedPhase[i] = vDSP.mean(slice)
                }

                // Normalize dB values: 0 dB is max, -60 dB or less is silence (0)
                if showDbs {
                    reduced = reduced.map { min(max(($0 + 60) / spectrumDbMax, 0), 1) }
                } else {
                    reduced = reduced.map { $0 / 25 } // Normalize to 0–1
                }

                DispatchQueue.main.async { [weak self] in
                    self?.spectrum = reduced
                    self?.spectrumPhase = reducedPhase
                }
            }
        }
    }

    func updateGain(band: Int, value: Float) {
        gains[band] = value
        eq.bands[band].gain = value
    }

    func togglePlay() {
        print(isPlaying)
        guard !isPlaying else { pause(); return }
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { player.play() }
        isPlaying = true
    }

    func play() {
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { player.play() }
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }
}
