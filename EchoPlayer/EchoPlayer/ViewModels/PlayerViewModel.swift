//
//  CrossfadeAudioPlayer.swift
//  EchoPlayer
//
//  Created by Wojciech Kosikowski on 07/07/2025.
//

import SwiftUI
import AudioKit
import AudioKitEX
import AudioToolbox
import AVFoundation
import Accelerate

@MainActor
final class PlayerViewModel: ObservableObject {
    // Published UI state
    @Published var isPlaying = false
    
    @Published var assetFileName: String = ""
    
    // Playback progress properties
    @Published var playbackProgress: Double = 0.0
    @Published private(set) var playbackTime: Double = 0.0
    @Published private(set) var duration: Double = 0.0
    
    // Audio graph
    private let engine  = AVAudioEngine()
    private let player  = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    
    private var timer: Timer?
    
    init() {
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
              let file = audioFile else {
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
        engine.connect(player, to: engine.mainMixerNode, format: nil)
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
                play()
            }
        }
    }
    
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "aiff"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                audioFile = try AVAudioFile(forReading: url)
                
                assetFileName = url.lastPathComponent
                let avAsset = AVAsset(url: url)
                
                player.stop()
                if let file = audioFile {
                    player.scheduleFile(file, at: nil)
                    duration =  Double(file.length) / file.fileFormat.sampleRate
                    playbackProgress = 0
                    playbackTime = 0
                    play()
                }
            } catch { print("Error loading file: \(error)") }
        }
    }
    
    func play() {
        guard !isPlaying else { pause(); return }
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { player.play() }
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }
}
