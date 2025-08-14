import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var hasValidAPIKey = false
    @Published var currentAPIKey: String?
    @Published var isLoading = false
    @Published var error: String?
    
    private let keychainService = KeychainService.shared
    private let openRouterAPI = OpenRouterAPI.shared
    
    private init() {
        checkAPIKey()
    }
    
    // MARK: - API Key Management
    
    func checkAPIKey() {
        do {
            currentAPIKey = try keychainService.getAPIKey()
            hasValidAPIKey = currentAPIKey != nil
        } catch {
            print("Error checking API key: \(error)")
            hasValidAPIKey = false
            currentAPIKey = nil
        }
    }
    
    func setAPIKey(_ key: String) async {
        isLoading = true
        error = nil
        
        // Validate format first
        guard keychainService.validateAPIKey(key) else {
            error = "Invalid API key format. OpenRouter keys start with 'sk-or-'"
            isLoading = false
            return
        }
        
        // Test the key by trying to fetch models
        do {
            _ = try await openRouterAPI.fetchModels(apiKey: key)
            
            // If successful, save to keychain
            try keychainService.saveAPIKey(key)
            currentAPIKey = key
            hasValidAPIKey = true
            
        } catch {
            self.error = "Failed to validate API key: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func removeAPIKey() {
        do {
            try keychainService.deleteAPIKey()
            currentAPIKey = nil
            hasValidAPIKey = false
        } catch {
            self.error = "Failed to remove API key: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Settings
    
    @AppStorage("defaultModel") var defaultModel = "anthropic/claude-3.5-sonnet"
    @AppStorage("defaultTemperature") var defaultTemperature = 0.7
    @AppStorage("allowFallbacks") var allowFallbacks = true
    @AppStorage("showTokenCount") var showTokenCount = true
    @AppStorage("showCostEstimates") var showCostEstimates = true
    
    // Search Settings
    @AppStorage("searchModel") var searchModel = "anthropic/claude-3-haiku"
    @AppStorage("searchTemperature") var searchTemperature = 0.3
    @AppStorage("enableSemanticSearch") var enableSemanticSearch = true
    @AppStorage("maxSearchResults") var maxSearchResults = 50
    @AppStorage("searchResultsGrouping") var searchResultsGrouping = "conversation"
    
    // Advanced Settings
    @AppStorage("enableAutoSync") var enableAutoSync = true
    @AppStorage("enableBackgroundSync") var enableBackgroundSync = true
    @AppStorage("syncFrequency") var syncFrequency = 15 // minutes
    @AppStorage("enableAdvancedLogging") var enableAdvancedLogging = false
    @AppStorage("maxCacheSize") var maxCacheSize = 100 // MB
    
    // Haptic Settings
    @AppStorage("hapticsEnabled") var hapticsEnabled = true
    @AppStorage("hapticIntensity") var hapticIntensityRaw = "medium"
    
    var hapticIntensity: HapticIntensity {
        get {
            HapticIntensity(rawValue: hapticIntensityRaw) ?? .medium
        }
        set {
            hapticIntensityRaw = newValue.rawValue
        }
    }
    
    // Notification Settings
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("messageNotifications") var messageNotifications = true
    @AppStorage("systemNotifications") var systemNotifications = true
    @AppStorage("notificationSounds") var notificationSounds = true
    
    // MARK: - Theme
    
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("accentColor") var accentColorData = Data()
    
    var accentColor: Color {
        get {
            // Safely unarchive color data with proper error handling
            guard !accentColorData.isEmpty else { return .blue }
            
            do {
                if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: accentColorData) {
                    return Color(uiColor: color)
                }
            } catch {
                print("Failed to unarchive accent color: \(error)")
                // Reset corrupted data
                accentColorData = Data()
            }
            
            return .blue
        }
        set {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: UIColor(newValue), requiringSecureCoding: false)
                accentColorData = data
            } catch {
                print("Failed to archive accent color: \(error)")
                // Keep existing data if archiving fails
            }
        }
    }
}