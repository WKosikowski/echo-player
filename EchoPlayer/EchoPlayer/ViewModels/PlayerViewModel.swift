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
@Observable
final class PlayerViewModel {
    enum VisualiserMode {
        case spectrum, sine, metalSum
    }

    // Published UI state
    var joinWindows = false
    var showDbs = false
    var spectrumDbMax: Float = 90
    var log: Bool = false
    var isPlaying = false
    var gains: [Float] = Array(repeating: 0, count: 12)
    var spectrum: [Float] = Array(repeating: 0, count: 64) // 0‥1
    var spectrumPhase: [Float] = Array(repeating: 0, count: 64)
    var visualiserMode: VisualiserMode = .spectrum
    var currentlyPlaying: ListedFile?
    var volume: Float = 1.0 {
        didSet {
            player.volume = volume
        }
    }

    var globalGain: Float = -12.0 {
        didSet {
            eq.globalGain = globalGain
        }
    }

    var assetFileName: String = ""
    var menuBarText: String {
        if assetFileName.count == 0 {
            return "♬"
        }
        return "[♪ \(Int(max(1, playbackProgress * 100)))%] " + assetFileName
    }
    
    private let decoder: JSONDecoder = .init()
    private let store: UserDefaults = .standard
    private let encoder: JSONEncoder = .init()
    
    var files: [ListedFile] = []

    // Playback progress properties
    var playbackProgress: Double = 0.0
    private(set) var playbackTime: Double = 0.0
    private(set) var duration: Double = 0.0

    // Audio graph
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 12)
    private var audioFile: AVAudioFile?

    private var seekFrameOffset: AVAudioFramePosition = 0

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
        
        do {
            if let list = store.value(forKey: "lastPlaybackList") as? Data {
                files = try decoder.decode([ListedFile].self, from: list)
            }
        } catch {
            print(error)
        }
    }

    deinit {
//        timer?.invalidate()
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackTime()
            }
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
        let seekOffsetSeconds = Double(seekFrameOffset) / playerTime.sampleRate
        let currentTime = (Double(playerTime.sampleTime) / playerTime.sampleRate) + seekOffsetSeconds
        playbackTime = currentTime
        duration = Double(file.length) / file.fileFormat.sampleRate
        if duration > 0 {
            playbackProgress = min(max(currentTime / duration, 0), 1)
            if playbackProgress >= 1 {
                playNext()
            }
        } else {
            playbackProgress = 0
        }
        
        
    }
    
    func nextFile(after file: ListedFile, in files: [ListedFile]) -> ListedFile? {
        guard let currentIndex = files.firstIndex(where: { $0.id == file.id }) else { return nil }
        let nextIndex = (currentIndex + 1) % files.count
        return files[nextIndex]
    }
    
    func previousFile(before file: ListedFile, in files: [ListedFile]) -> ListedFile? {
        guard !files.isEmpty else { return nil }
        guard let currentIndex = files.firstIndex(where: { $0.id == file.id }) else { return nil }
        let previousIndex = (currentIndex - 1 + files.count) % files.count
        return files[previousIndex]
    }
    
    func playLast() {
        if let currentlyPlaying = currentlyPlaying {
            if files.count > 0 {
                let nextFile = previousFile(before: currentlyPlaying, in: files)!
                let nextURL = URL(string:  nextFile.fullPath )!
                
                do {
                    audioFile = try AVAudioFile(forReading: nextURL)
                    seekFrameOffset = 0
                    
                    assetFileName = nextURL.lastPathComponent
                    let avAsset = AVURLAsset(url: nextURL)
                    
                    player.stop()
                    if let file = audioFile {
                        player.scheduleFile(file, at: nil)
                        duration = Double(file.length) / file.fileFormat.sampleRate
                        playbackProgress = 0
                        playbackTime = 0
                        play()
                        self.currentlyPlaying = nextFile
                    }
                } catch { print("Error loading file: \(error)") }
            }
        }
    }
    
    func playNext() {
        if let currentlyPlaying = currentlyPlaying {
            if files.count > 0 {
                let nextFile = nextFile(after: currentlyPlaying, in: files)!
                let nextURL = URL(string:  nextFile.fullPath )!
                
                do {
                    audioFile = try AVAudioFile(forReading: nextURL)
                    seekFrameOffset = 0
                    
                    assetFileName = nextURL.lastPathComponent
                    let avAsset = AVURLAsset(url: nextURL)
                    
                    player.stop()
                    if let file = audioFile {
                        player.scheduleFile(file, at: nil)
                        duration = Double(file.length) / file.fileFormat.sampleRate
                        playbackProgress = 0
                        playbackTime = 0
                        play()
                        self.currentlyPlaying = nextFile
                    }
                } catch { print("Error loading file: \(error)") }
            }
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

        let newFrame = AVAudioFramePosition(progress * Double(file.length))
        seekFrameOffset = newFrame
        let framesToPlay = AVAudioFrameCount(file.length - newFrame)
        playbackProgress = progress

        player.stop()
        if framesToPlay > 0 {
            player.scheduleSegment(
                file,
                startingFrame: newFrame,
                frameCount: framesToPlay,
                at: nil // Play immediately
            )
        }
        play()
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
        eq.globalGain = -12
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .wav, .mpeg4Audio, .aiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                audioFile = try AVAudioFile(forReading: url)
                seekFrameOffset = 0
                print(url)
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

    func playFile(url: URL) {
        do {
            audioFile = try AVAudioFile(forReading: url)
            seekFrameOffset = 0

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
        gains[band] = value * 24
        eq.bands[band].gain = value * 24
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
    
    
    func saveToStore() {
        do {
            let data = try encoder.encode(files)
            store.set(data, forKey: "lastPlaybackList")
        } catch {
            print(error)
        }
    }
    
    // Adds supported files from dropped URLs (recursively for folders)
    func add(urls: [URL]) {
        var added: [ListedFile] = []
        for url in urls {
            if url.hasDirectoryPath {
                let fileURLs = filesRecursively(in: url)
                added.append(contentsOf: fileURLs)
            } else if isSupported(url) {
                if url.pathExtension == "eplist" {
                    loadJSON(url: url)
                } else {
                    added.append(ListedFile(url: url))
                }
            }
        }
        // Avoid duplicates
        let existingPaths = Set(files.map { $0.fullPath })
        let deduped = added.filter { !existingPaths.contains($0.fullPath) }
        files.append(contentsOf: deduped)
        saveToStore()
    }
    
    func clear() {
        files = []
        saveToStore()
    }
    
    // Save as JSON to chosen file
    @MainActor
    func saveToJSON() async {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["eplist", "epl", "eps", "json"]
        savePanel.nameFieldStringValue = "file-list.eplist"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(files)
                try data.write(to: url)
            } catch {
                print(error)
            }
        }
    }
    
    func loadJSON(url: URL) {
        clear()
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedFiles = try decoder.decode([ListedFile].self, from: data)
            // Avoid duplicates
            let existingPaths = Set(files.map { $0.fullPath })
            let deduped = loadedFiles.filter { !existingPaths.contains($0.fullPath) }
            files.append(contentsOf: deduped)
        } catch {
            print("Error loading JSON: \(error)")
        }
    }
    
    // Load files from a JSON file
    @MainActor
    func loadJSONFromPanel() async {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["eplist", "eps", "epl", "json"]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let loadedFiles = try decoder.decode([ListedFile].self, from: data)
                // Avoid duplicates
                let existingPaths = Set(files.map { $0.fullPath })
                let deduped = loadedFiles.filter { !existingPaths.contains($0.fullPath) }
                files.append(contentsOf: deduped)
            } catch {
                print("Error loading JSON: \(error)")
            }
        }
        saveToStore()
    }
}

private func filesRecursively(in directory: URL) -> [ListedFile] {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil)
    var files: [ListedFile] = []
    while let element = enumerator?.nextObject() as? URL {
        if !element.hasDirectoryPath, isSupported(element) {
            files.append(ListedFile(url: element))
        }
    }
    return files
}

private let supportedExtensions: Set<String> = ["mp3", "wav", "eplist", "eps", "epl", "json"]

private func isSupported(_ url: URL) -> Bool {
    supportedExtensions.contains(url.pathExtension.lowercased())
}
