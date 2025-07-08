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
    // Published UI state
    @Published var isPlaying = false
    @Published var gains: [Float]  = Array(repeating: 0, count: 12)
    @Published var volume: Float = 1.0 {
        didSet {
            player.volume = volume
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
    private let eq      = AVAudioUnitEQ(numberOfBands: 12)
    private var audioFile: AVAudioFile?

    private var timer: Timer?

    init() {
        configureEQ()
        setupEngine()
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
    }

    func seek(to progress: Double) {
        guard let file = audioFile else { return }
        let seekTime = progress * (Double(file.length) / file.fileFormat.sampleRate)
        player.stop()
        // Schedule file from seekTime
        let sampleRate = file.processingFormat.sampleRate
        let startSampleTime = AVAudioFramePosition(seekTime * sampleRate)
        let length = AVAudioFrameCount(file.length - startSampleTime)
        
        do {
            if length > 0 {
                player.scheduleSegment(file, startingFrame: startSampleTime, frameCount: length, at: nil) {
                    DispatchQueue.main.async { [weak self] in
                        self?.isPlaying = false
                    }
                }
                togglePlay()
            }
        }
    }
    
    private func configureEQ() {
        let freqs: [Float] = [32, 64, 128, 250, 500, 1_000, 2_000, 4_000, 8_000, 12_000, 14_000, 16_000]
        for (i, band) in eq.bands.enumerated() {
            band.filterType = .parametric
            band.frequency  = freqs[i]
            band.bandwidth  = 1.0        // octaves
            band.gain       = 0
            band.bypass     = false
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
    
    func updateGain(band: Int, value: Float) {
        gains[band]         = value
        eq.bands[band].gain = value
    }
    
    

    func togglePlay() {
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
