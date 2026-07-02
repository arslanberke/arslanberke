import AVFoundation

/// Synthesizes all game audio at runtime with AVAudioEngine — no bundled files,
/// tiny binary size, fully offline.
final class AudioManager {
    static let shared = AudioManager()

    enum Effect { case snap, rotate, reject, complete, unlock, teleport, combo, fail, coin }

    private let engine = AVAudioEngine()
    private let effectPlayer = AVAudioPlayerNode()
    private let ambientPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var effectBuffers: [Effect: AVAudioPCMBuffer] = [:]
    private var ambientBuffer: AVAudioPCMBuffer?

    private var soundOn: Bool { GameSettings.shared.soundEnabled }
    private var musicOn: Bool { GameSettings.shared.musicEnabled }

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        engine.attach(effectPlayer)
        engine.attach(ambientPlayer)
        engine.connect(effectPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(ambientPlayer, to: engine.mainMixerNode, format: format)
        ambientPlayer.volume = 0.25
        buildBuffers()
        try? engine.start()
    }

    func play(_ effect: Effect) {
        guard soundOn, let buffer = effectBuffers[effect] else { return }
        if !engine.isRunning { try? engine.start() }
        effectPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
        effectPlayer.play()
    }

    func startAmbient() {
        guard musicOn, let buffer = ambientBuffer else { return }
        if !engine.isRunning { try? engine.start() }
        ambientPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        ambientPlayer.play()
    }

    func stopAmbient() { ambientPlayer.stop() }

    // MARK: - Synthesis

    private func buildBuffers() {
        effectBuffers[.snap] = tone(frequencies: [880, 1320], duration: 0.09, decay: 18)
        effectBuffers[.rotate] = tone(frequencies: [520], duration: 0.05, decay: 30)
        effectBuffers[.reject] = tone(frequencies: [180, 170], duration: 0.15, decay: 10)
        effectBuffers[.complete] = arpeggio(frequencies: [523.25, 659.25, 783.99, 1046.5], noteDuration: 0.11)
        effectBuffers[.unlock] = tone(frequencies: [660, 990], duration: 0.12, decay: 12)
        effectBuffers[.teleport] = sweep(from: 300, to: 1200, duration: 0.2)
        effectBuffers[.combo] = arpeggio(frequencies: [659.25, 830.6, 987.77], noteDuration: 0.08)
        effectBuffers[.fail] = sweep(from: 400, to: 150, duration: 0.35)
        effectBuffers[.coin] = tone(frequencies: [1174.7, 1568], duration: 0.08, decay: 16)
        ambientBuffer = ambientPad()
    }

    private func makeBuffer(duration: Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        buffer?.frameLength = frames
        return buffer
    }

    private func tone(frequencies: [Double], duration: Double, decay: Double) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration), let data = buffer.floatChannelData?[0] else { return nil }
        let sampleRate = format.sampleRate
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / sampleRate
            let envelope = exp(-t * decay)
            var sample = 0.0
            for freq in frequencies { sample += sin(2 * .pi * freq * t) }
            data[frame] = Float(sample / Double(frequencies.count) * envelope * 0.5)
        }
        return buffer
    }

    private func arpeggio(frequencies: [Double], noteDuration: Double) -> AVAudioPCMBuffer? {
        let total = noteDuration * Double(frequencies.count) + 0.3
        guard let buffer = makeBuffer(duration: total), let data = buffer.floatChannelData?[0] else { return nil }
        let sampleRate = format.sampleRate
        for (noteIndex, freq) in frequencies.enumerated() {
            let start = Double(noteIndex) * noteDuration
            let noteFrames = Int((noteDuration + 0.25) * sampleRate)
            let startFrame = Int(start * sampleRate)
            for offset in 0..<noteFrames where startFrame + offset < Int(buffer.frameLength) {
                let t = Double(offset) / sampleRate
                let envelope = exp(-t * 7)
                data[startFrame + offset] += Float(sin(2 * .pi * freq * t) * envelope * 0.35)
            }
        }
        return buffer
    }

    private func sweep(from startFreq: Double, to endFreq: Double, duration: Double) -> AVAudioPCMBuffer? {
        guard let buffer = makeBuffer(duration: duration), let data = buffer.floatChannelData?[0] else { return nil }
        let sampleRate = format.sampleRate
        var phase = 0.0
        for frame in 0..<Int(buffer.frameLength) {
            let progress = Double(frame) / Double(buffer.frameLength)
            let freq = startFreq + (endFreq - startFreq) * progress
            phase += 2 * .pi * freq / sampleRate
            let envelope = sin(.pi * progress)
            data[frame] = Float(sin(phase) * envelope * 0.4)
        }
        return buffer
    }

    /// A slowly-evolving warm pad chord that loops seamlessly (~8s).
    private func ambientPad() -> AVAudioPCMBuffer? {
        let duration = 8.0
        guard let buffer = makeBuffer(duration: duration), let data = buffer.floatChannelData?[0] else { return nil }
        let sampleRate = format.sampleRate
        let chord = [130.81, 164.81, 196.0, 246.94] // C3 E3 G3 B3
        let frames = Int(buffer.frameLength)
        for frame in 0..<frames {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for (index, freq) in chord.enumerated() {
                let lfo = 0.5 + 0.5 * sin(2 * .pi * t / duration + Double(index) * 1.3)
                sample += sin(2 * .pi * freq * t) * lfo
            }
            // crossfade the loop point
            let fade = min(1.0, min(t, duration - t) * 4)
            data[frame] = Float(sample / Double(chord.count) * 0.18 * fade)
        }
        return buffer
    }
}
