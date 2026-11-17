import AppKit
import AVFoundation
import Speech

// MARK: - Dictado (voz a texto, en el propio Mac cuando es posible)

@MainActor
final class Dictation: ObservableObject {
    @Published var isRunning = false
    @Published var partial = ""
    @Published var level: Float = 0
    @Published var message: String?

    var onCommit: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() { isRunning ? stop() : start() }

    func start() {
        message = nil
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.message = L("Activa el reconocimiento de voz para Suelta en Ajustes del Sistema › Privacidad y seguridad.")
                    return
                }
                AVAudioApplication.requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        if ok { self.begin() } else {
                            self.message = L("Activa el micrófono para Suelta en Ajustes del Sistema › Privacidad y seguridad.")
                        }
                    }
                }
            }
        }
    }

    private func begin() {
        let recognizer = SFSpeechRecognizer(locale: Lang.current.speechLocale)
            ?? SFSpeechRecognizer(locale: Lang.current.locale)
        guard let recognizer, recognizer.isAvailable else {
            message = L("El dictado no está disponible ahora mismo.")
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            let lvl = Self.rms(buffer)
            DispatchQueue.main.async { self?.level = lvl }
        }
        engine.prepare()
        do { try engine.start() } catch {
            message = L("No pude usar el micrófono.")
            input.removeTap(onBus: 0)
            return
        }
        isRunning = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.partial = result.bestTranscription.formattedString
                    if result.isFinal { self.commit() }
                }
                if error != nil, self.isRunning { self.stop() }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        level = 0
        commit()
    }

    private func commit() {
        let t = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        partial = ""
        if !t.isEmpty { onCommit?(t) }
    }

    nonisolated static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let ch = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        if n == 0 { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        let rms = sqrt(sum / Float(n))
        return min(1, max(0, (20 * log10(max(rms, 0.000_01)) + 50) / 45))
    }
}

// MARK: - Notas de voz

@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var elapsed: TimeInterval = 0
    @Published var level: Float = 0
    @Published var message: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private(set) var currentFile: String?

    func start(in dir: URL, completion: @escaping (Bool) -> Void) {
        message = nil
        AVAudioApplication.requestRecordPermission { ok in
            DispatchQueue.main.async {
                guard ok else {
                    self.message = L("Activa el micrófono para Suelta en Ajustes del Sistema › Privacidad y seguridad.")
                    completion(false)
                    return
                }
                let name = UUID().uuidString + ".m4a"
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ]
                do {
                    let r = try AVAudioRecorder(url: dir.appendingPathComponent(name), settings: settings)
                    r.isMeteringEnabled = true
                    r.record()
                    self.recorder = r
                    self.currentFile = name
                    self.isRecording = true
                    self.elapsed = 0
                    self.startTimer()
                    completion(true)
                } catch {
                    self.message = L("No pude empezar a grabar.")
                    completion(false)
                }
            }
        }
    }

    /// Devuelve (archivo, duración).
    func stop() -> (String, TimeInterval)? {
        guard let r = recorder, let f = currentFile else { return nil }
        let d = r.currentTime
        r.stop()
        recorder = nil
        isRecording = false
        level = 0
        timer?.invalidate()
        return (f, d)
    }

    func togglePlay(_ url: URL) {
        if isPlaying { stopPlayback(); return }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        p.isMeteringEnabled = true
        p.play()
        player = p
        isPlaying = true
        startTimer()
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        level = 0
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let r = self.recorder {
                    r.updateMeters()
                    self.elapsed = r.currentTime
                    self.level = max(0, min(1, (r.averagePower(forChannel: 0) + 50) / 45))
                } else if let p = self.player {
                    p.updateMeters()
                    self.elapsed = p.currentTime
                    self.level = max(0, min(1, (p.averagePower(forChannel: 0) + 50) / 45))
                }
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.stopPlayback() }
    }
}

// MARK: - Efectos de sonido

@MainActor
enum SoundFX {
    private static var cache: [String: NSSound] = [:]
    private static let finder = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/finder/"

    static func play(_ name: String, volume: Float = 1) {
        let sound: NSSound?
        if let s = cache[name] {
            sound = s
        } else if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            sound = NSSound(contentsOf: url, byReference: true)
        } else {
            sound = NSSound(contentsOfFile: finder + name + ".aif", byReference: true)
        }
        guard let s = sound else { return }
        cache[name] = s
        s.stop()
        s.volume = volume
        s.play()
    }

    static func play(_ name: String, after delay: Double, volume: Float = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { play(name, volume: volume) }
    }
}

func formatDuration(_ t: TimeInterval) -> String {
    let s = Int(t.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
}
