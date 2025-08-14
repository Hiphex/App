import Foundation
import UIKit

@MainActor
class HapticService: ObservableObject {
    static let shared = HapticService()
    
    @Published var isHapticsEnabled = true
    @Published var hapticIntensity: HapticIntensity = .medium
    @Published var customPatterns: [String: HapticPattern] = [:]
    
    // Haptic generators
    private var impactFeedbackLight: UIImpactFeedbackGenerator?
    private var impactFeedbackMedium: UIImpactFeedbackGenerator?
    private var impactFeedbackHeavy: UIImpactFeedbackGenerator?
    private var selectionFeedback: UISelectionFeedbackGenerator?
    private var notificationFeedback: UINotificationFeedbackGenerator?
    
    private init() {
        setupHapticGenerators()
        loadSettings()
    }
    
    // MARK: - Setup
    
    private func setupHapticGenerators() {
        impactFeedbackLight = UIImpactFeedbackGenerator(style: .light)
        impactFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)
        impactFeedbackHeavy = UIImpactFeedbackGenerator(style: .heavy)
        selectionFeedback = UISelectionFeedbackGenerator()
        notificationFeedback = UINotificationFeedbackGenerator()
        
        // Prepare all generators for optimal performance
        prepareAllGenerators()
    }
    
    private func prepareAllGenerators() {
        impactFeedbackLight?.prepare()
        impactFeedbackMedium?.prepare()
        impactFeedbackHeavy?.prepare()
        selectionFeedback?.prepare()
        notificationFeedback?.prepare()
    }
    
    private func loadSettings() {
        // Load haptic settings from UserDefaults
        isHapticsEnabled = UserDefaults.standard.object(forKey: "HapticsEnabled") as? Bool ?? true
        
        if let intensityRaw = UserDefaults.standard.object(forKey: "HapticIntensity") as? String,
           let intensity = HapticIntensity(rawValue: intensityRaw) {
            hapticIntensity = intensity
        }
        
        // Load custom patterns
        if let patternsData = UserDefaults.standard.data(forKey: "CustomHapticPatterns"),
           let patterns = try? JSONDecoder().decode([String: HapticPattern].self, from: patternsData) {
            customPatterns = patterns
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isHapticsEnabled, forKey: "HapticsEnabled")
        UserDefaults.standard.set(hapticIntensity.rawValue, forKey: "HapticIntensity")
        
        if let patternsData = try? JSONEncoder().encode(customPatterns) {
            UserDefaults.standard.set(patternsData, forKey: "CustomHapticPatterns")
        }
    }
    
    // MARK: - Basic Haptic Methods
    
    func triggerImpactFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled && UIDevice.current.isHapticsSupported else { return }
        
        let adjustedStyle = adjustStyleForIntensity(style)
        
        switch adjustedStyle {
        case .light:
            impactFeedbackLight?.impactOccurred()
        case .medium:
            impactFeedbackMedium?.impactOccurred()
        case .heavy:
            impactFeedbackHeavy?.impactOccurred()
        @unknown default:
            impactFeedbackMedium?.impactOccurred()
        }
        
        // Re-prepare for next use
        prepareGeneratorForStyle(adjustedStyle)
    }
    
    func triggerSelectionFeedback() {
        guard isHapticsEnabled && UIDevice.current.isHapticsSupported else { return }
        
        if hapticIntensity != .off {
            selectionFeedback?.selectionChanged()
            selectionFeedback?.prepare()
        }
    }
    
    func triggerNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled && UIDevice.current.isHapticsSupported else { return }
        
        if hapticIntensity != .off {
            notificationFeedback?.notificationOccurred(type)
            notificationFeedback?.prepare()
        }
    }
    
    // MARK: - Advanced Haptic Patterns
    
    func triggerCustomPattern(named patternName: String) {
        guard isHapticsEnabled && UIDevice.current.isHapticsSupported,
              let pattern = customPatterns[patternName] else { return }
        
        executeHapticPattern(pattern)
    }
    
    func executeHapticPattern(_ pattern: HapticPattern) {
        guard isHapticsEnabled && UIDevice.current.isHapticsSupported else { return }
        
        Task {
            for event in pattern.events {
                if event.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(event.delay * 1_000_000_000))
                }
                
                switch event.type {
                case .impact(let style):
                    await MainActor.run {
                        triggerImpactFeedback(style)
                    }
                case .selection:
                    await MainActor.run {
                        triggerSelectionFeedback()
                    }
                case .notification(let type):
                    await MainActor.run {
                        triggerNotificationFeedback(type)
                    }
                }
            }
        }
    }
    
    // MARK: - App-Specific Haptic Methods
    
    func triggerMessageSentFeedback() {
        let pattern = customPatterns["messageSent"] ?? HapticPattern.messageSent
        executeHapticPattern(pattern)
    }
    
    func triggerMessageReceivedFeedback() {
        let pattern = customPatterns["messageReceived"] ?? HapticPattern.messageReceived
        executeHapticPattern(pattern)
    }
    
    func triggerConversationStartedFeedback() {
        let pattern = customPatterns["conversationStarted"] ?? HapticPattern.conversationStarted
        executeHapticPattern(pattern)
    }
    
    func triggerErrorFeedback() {
        triggerNotificationFeedback(.error)
    }
    
    func triggerSuccessFeedback() {
        triggerNotificationFeedback(.success)
    }
    
    func triggerWarningFeedback() {
        triggerNotificationFeedback(.warning)
    }
    
    func triggerButtonTapFeedback() {
        triggerImpactFeedback(.light)
    }
    
    func triggerToggleFeedback() {
        triggerImpactFeedback(.medium)
    }
    
    func triggerScrollFeedback() {
        if hapticIntensity == .high {
            triggerSelectionFeedback()
        }
    }
    
    func triggerLongPressFeedback() {
        triggerImpactFeedback(.heavy)
    }
    
    func triggerSwipeFeedback() {
        triggerImpactFeedback(.light)
    }
    
    func triggerRefreshFeedback() {
        let pattern = customPatterns["refresh"] ?? HapticPattern.refresh
        executeHapticPattern(pattern)
    }
    
    func triggerTypingFeedback() {
        if hapticIntensity == .high {
            triggerImpactFeedback(.light)
        }
    }
    
    // MARK: - Settings Management
    
    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        saveSettings()
        
        if enabled {
            prepareAllGenerators()
        }
    }
    
    func setHapticIntensity(_ intensity: HapticIntensity) {
        hapticIntensity = intensity
        saveSettings()
    }
    
    func addCustomPattern(name: String, pattern: HapticPattern) {
        customPatterns[name] = pattern
        saveSettings()
    }
    
    func removeCustomPattern(name: String) {
        customPatterns.removeValue(forKey: name)
        saveSettings()
    }
    
    func resetToDefaults() {
        isHapticsEnabled = true
        hapticIntensity = .medium
        customPatterns.removeAll()
        saveSettings()
    }
    
    // MARK: - Helper Methods
    
    private func adjustStyleForIntensity(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch hapticIntensity {
        case .off:
            return style // Won't be triggered anyway
        case .low:
            return .light
        case .medium:
            return style
        case .high:
            switch style {
            case .light:
                return .medium
            case .medium:
                return .heavy
            case .heavy:
                return .heavy
            @unknown default:
                return style
            }
        }
    }
    
    private func prepareGeneratorForStyle(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactFeedbackLight?.prepare()
        case .medium:
            impactFeedbackMedium?.prepare()
        case .heavy:
            impactFeedbackHeavy?.prepare()
        @unknown default:
            impactFeedbackMedium?.prepare()
        }
    }
}

// MARK: - Supporting Types

enum HapticIntensity: String, CaseIterable, Codable {
    case off = "off"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var description: String {
        switch self {
        case .off: return "No haptic feedback"
        case .low: return "Minimal haptic feedback"
        case .medium: return "Standard haptic feedback"
        case .high: return "Enhanced haptic feedback with additional patterns"
        }
    }
}

struct HapticPattern: Codable {
    let events: [HapticEvent]
    
    init(events: [HapticEvent]) {
        self.events = events
    }
}

struct HapticEvent: Codable {
    let type: HapticEventType
    let delay: TimeInterval
    
    init(type: HapticEventType, delay: TimeInterval = 0) {
        self.type = type
        self.delay = delay
    }
}

enum HapticEventType: Codable {
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case selection
    case notification(UINotificationFeedbackGenerator.FeedbackType)
    
    enum CodingKeys: String, CodingKey {
        case type, style, notificationType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "impact":
            let styleRaw = try container.decode(Int.self, forKey: .style)
            let style = UIImpactFeedbackGenerator.FeedbackStyle(rawValue: styleRaw) ?? .medium
            self = .impact(style)
        case "selection":
            self = .selection
        case "notification":
            let typeRaw = try container.decode(Int.self, forKey: .notificationType)
            let notificationType = UINotificationFeedbackGenerator.FeedbackType(rawValue: typeRaw) ?? .success
            self = .notification(notificationType)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown haptic event type")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .impact(let style):
            try container.encode("impact", forKey: .type)
            try container.encode(style.rawValue, forKey: .style)
        case .selection:
            try container.encode("selection", forKey: .type)
        case .notification(let type):
            try container.encode("notification", forKey: .type)
            try container.encode(type.rawValue, forKey: .notificationType)
        }
    }
}

// MARK: - Predefined Patterns

extension HapticPattern {
    static let messageSent = HapticPattern(events: [
        HapticEvent(type: .impact(.light)),
        HapticEvent(type: .impact(.medium), delay: 0.05)
    ])
    
    static let messageReceived = HapticPattern(events: [
        HapticEvent(type: .impact(.medium)),
        HapticEvent(type: .selection, delay: 0.1)
    ])
    
    static let conversationStarted = HapticPattern(events: [
        HapticEvent(type: .notification(.success))
    ])
    
    static let refresh = HapticPattern(events: [
        HapticEvent(type: .impact(.light)),
        HapticEvent(type: .impact(.light), delay: 0.1),
        HapticEvent(type: .impact(.medium), delay: 0.2)
    ])
    
    static let longPress = HapticPattern(events: [
        HapticEvent(type: .impact(.heavy))
    ])
    
    static let doubleTap = HapticPattern(events: [
        HapticEvent(type: .impact(.light)),
        HapticEvent(type: .impact(.light), delay: 0.1)
    ])
}

// MARK: - UIDevice Extension

extension UIDevice {
    var isHapticsSupported: Bool {
        switch userInterfaceIdiom {
        case .phone:
            return true
        case .pad:
            return false // iPad doesn't support haptics
        default:
            return false
        }
    }
}