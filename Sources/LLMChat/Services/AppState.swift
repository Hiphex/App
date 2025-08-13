import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var hasValidAPIKey = false
    @Published var currentAPIKey: String?
    @Published var isLoading = false
    @Published var error: String?
    
    private let keychainService = KeychainService.shared
    private let openRouterAPI = OpenRouterAPI.shared
    
    init() {
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
    
    // MARK: - Theme
    
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("accentColor") var accentColorData = Data()
    
    var accentColor: Color {
        get {
            if let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: accentColorData) {
                return Color(uiColor: color)
            }
            return .blue
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(newValue), requiringSecureCoding: false) {
                accentColorData = data
            }
        }
    }
}