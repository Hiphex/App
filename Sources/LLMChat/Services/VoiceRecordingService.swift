import Foundation
import AVFoundation
import Speech

@Observable
class VoiceRecordingService: NSObject {
    static let shared = VoiceRecordingService()
    
    private var audioEngine: AVAudioEngine
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioRecorder: AVAudioRecorder?
    private var speechSynthesizer: AVSpeechSynthesizer
    
    // Observable properties
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var isSpeaking: Bool = false
    var recordingLevel: Float = 0.0
    var currentTranscription: String = ""
    var recordingDuration: TimeInterval = 0.0
    
    // Permissions
    var microphonePermission: AVAudioSession.RecordPermission = .undetermined
    var speechRecognitionPermission: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        self.audioEngine = AVAudioEngine()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.speechSynthesizer = AVSpeechSynthesizer()
        
        super.init()
        
        setupAudioSession()
        checkPermissions()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async -> Bool {
        let micPermission = await requestMicrophonePermission()
        let speechPermission = await requestSpeechRecognitionPermission()
        return micPermission && speechPermission
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechRecognitionPermission = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    private func checkPermissions() {
        microphonePermission = AVAudioSession.sharedInstance().recordPermission
        speechRecognitionPermission = SFSpeechRecognizer.authorizationStatus()
    }
    
    // MARK: - Recording
    
    func startRecording() async throws -> URL {
        guard !isRecording else { throw VoiceRecordingError.alreadyRecording }
        guard microphonePermission == .granted else { throw VoiceRecordingError.noMicrophonePermission }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording-\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            
            // Start metering timer
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateMeteringLevels()
            }
            
            // Start duration timer
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateRecordingDuration()
            }
            
            return audioFilename
        } catch {
            throw VoiceRecordingError.recordingFailed(error)
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        isRecording = false
        recordingStartTime = nil
        recordingDuration = 0.0
        
        levelTimer?.invalidate()
        levelTimer = nil
        
        durationTimer?.invalidate()
        durationTimer = nil
        
        return audioRecorder?.url
    }
    
    private func updateMeteringLevels() {
        guard let recorder = audioRecorder, isRecording else { return }
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        // Convert to 0-1 range
        recordingLevel = pow(10, averagePower / 20)
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Speech Recognition
    
    func startLiveTranscription() async throws {
        guard speechRecognitionPermission == .authorized else {
            throw VoiceRecordingError.noSpeechRecognitionPermission
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecordingError.transcriptionFailed(NSError(domain: "VoiceRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"]))
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isTranscribing = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.currentTranscription = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self?.stopLiveTranscription()
                }
            }
        }
    }
    
    func stopLiveTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isTranscribing = false
    }
    
    func transcribeAudioFile(at url: URL) async throws -> String {
        guard speechRecognitionPermission == .authorized else {
            throw VoiceRecordingError.noSpeechRecognitionPermission
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        return try await withCheckedThrowingContinuation { continuation in
            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: VoiceRecordingError.transcriptionFailed(error))
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    // MARK: - Text-to-Speech
    
    func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        speechSynthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func pauseSpeaking() {
        speechSynthesizer.pauseSpeaking(at: .immediate)
    }
    
    func continueSpeaking() {
        speechSynthesizer.continueSpeaking()
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            isRecording = false
            print("Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
        isRecording = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceRecordingService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

// MARK: - Error Types

enum VoiceRecordingError: LocalizedError {
    case alreadyRecording
    case noMicrophonePermission
    case noSpeechRecognitionPermission
    case recordingFailed(Error)
    case transcriptionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording audio"
        case .noMicrophonePermission:
            return "Microphone permission not granted"
        case .noSpeechRecognitionPermission:
            return "Speech recognition permission not granted"
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        }
    }
}