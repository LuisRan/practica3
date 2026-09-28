//
//  AudioServices.swift
//  Grabación con AVAudioRecorder y reproducción con AVAudioPlayer.
//  - Sensibilidad: ganancia de entrada (si el hardware lo permite) + calidad de grabación.
//  - Temporizador: duración máxima de grabación (record(forDuration:)).
//  - Medidor de nivel en tiempo real (updateMeters / averagePower).
//

import AVFoundation
import Foundation

enum MicSensitivity: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }

    /// Ganancia de entrada 0...1 (AVAudioSession.setInputGain).
    var gain: Float {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 1.0
        }
    }

    /// Nivel (dB) por debajo del cual se considera silencio en el medidor.
    var noiseFloor: Float {
        switch self {
        case .low: return -40
        case .medium: return -50
        case .high: return -60
        }
    }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: return "Voz (22 kHz)"
        case .medium: return "Estándar (44.1 kHz)"
        case .high: return "Alta (48 kHz)"
        }
    }
    var sampleRate: Double {
        switch self {
        case .low: return 22_050
        case .medium: return 44_100
        case .high: return 48_000
        }
    }
    var avQuality: AVAudioQuality {
        switch self {
        case .low: return .medium
        case .medium: return .high
        case .high: return .max
        }
    }
}

final class AudioRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0            // 0...1 para la UI
    @Published private(set) var levelHistory: [Float] = Array(repeating: 0, count: 40)
    @Published private(set) var permissionDenied = false
    @Published var errorMessage: String?

    @Published var sensitivity: MicSensitivity = .medium
    @Published var quality: AudioQuality = .medium
    /// Duración máxima (segundos). 0 = sin límite.
    @Published var maxDuration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentURL: URL?
    var onFinished: ((URL, TimeInterval) -> Void)?

    // MARK: - Permisos

    @MainActor
    func requestPermission() async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        permissionDenied = !granted
        return granted
    }

    // MARK: - Grabación

    @MainActor
    func start() async {
        guard await requestPermission() else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            if session.isInputGainSettable {
                try? session.setInputGain(sensitivity.gain)
            }
            let url = MediaStore.directory(for: .audio)
                .appendingPathComponent(MediaStore.newFileName(kind: .audio, ext: "m4a"))
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: quality.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: quality.avQuality.rawValue
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.delegate = self
            rec.isMeteringEnabled = true
            rec.prepareToRecord()
            let ok = maxDuration > 0 ? rec.record(forDuration: maxDuration) : rec.record()
            guard ok else {
                errorMessage = "No se pudo iniciar la grabación."
                return
            }
            recorder = rec
            currentURL = url
            isRecording = true
            isPaused = false
            elapsed = 0
            startMetering()
        } catch {
            errorMessage = "Error de audio: \(error.localizedDescription)"
        }
    }

    func pauseOrResume() {
        guard let recorder else { return }
        if recorder.isRecording {
            recorder.pause()
            isPaused = true
        } else {
            recorder.record()
            isPaused = false
        }
    }

    func stop() {
        recorder?.stop() // dispara audioRecorderDidFinishRecording
    }

    func cancel() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.delegate = nil
        recorder.stop()
        recorder.deleteRecording()
        try? FileManager.default.removeItem(at: url)
        cleanup()
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // -160...0 dB
            let floor = self.sensitivity.noiseFloor
            let normalized = power < floor ? 0 : (power - floor) / -floor
            self.level = max(0, min(1, normalized))
            self.levelHistory.removeFirst()
            self.levelHistory.append(self.level)
            if recorder.isRecording { self.elapsed = recorder.currentTime }
        }
    }

    private func cleanup() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder = nil
        isRecording = false
        isPaused = false
        level = 0
        levelHistory = Array(repeating: 0, count: 40)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        cleanup()
        guard flag else {
            errorMessage = "La grabación terminó con error."
            return
        }
        let duration = AudioDuration.of(url)
        onFinished?(url, duration)
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        errorMessage = "Error al codificar: \(error?.localizedDescription ?? "desconocido")"
        cleanup()
    }
}

final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var rate: Float = 1 {
        didSet { player?.rate = rate }
    }
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(_ url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.enableRate = true
            p.rate = rate
            p.delegate = self
            p.prepareToPlay()
            player = p
            duration = p.duration
            currentTime = 0
        } catch {
            errorMessage = "No se pudo reproducir el archivo (¿dañado o formato no soportado?)."
        }
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func skip(_ seconds: TimeInterval) {
        guard let player else { return }
        seek(to: max(0, min(player.duration, player.currentTime + seconds)))
    }

    func stop() {
        player?.stop()
        timer?.invalidate()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer?.invalidate()
        isPlaying = false
        currentTime = 0
    }
}

extension TimeInterval {
    var mmss: String {
        let total = Int(self.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
