import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications

@main
struct LLMChatApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var backgroundTaskService = BackgroundTaskService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var hapticService = HapticService.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var searchModelService = SearchModelConfigurationService.shared
    
    init() {
        // Configure app for background tasks
        setupBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(backgroundTaskService)
                .environmentObject(notificationService)
                .environmentObject(hapticService)
                .environmentObject(cloudKitService)
                .environmentObject(searchModelService)
                .onOpenURL { url in
                    handleURLScheme(url)
                }
        }
        .modelContainer(for: [
            Conversation.self,
            Message.self,
            Attachment.self,
            ModelInfo.self
        ])
        .backgroundTask(.appRefresh("com.llmchat.background-sync")) {
            await backgroundTaskService.handleAppDidEnterBackground()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupBackgroundTasks() {
        // Background tasks are registered in BackgroundTaskService
        // This is just for app lifecycle management
    }
    
    private func handleURLScheme(_ url: URL) {
        guard url.scheme == "llmchat" else { return }
        
        switch url.host {
        case "share":
            // Handle share extension data
            handleShareExtensionData()
        default:
            break
        }
    }
    
    private func handleShareExtensionData() {
        // Check for pending share data from share extension
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.llmchat.shared"),
              let data = sharedDefaults.data(forKey: "pendingShare") else {
            return
        }
        
        do {
            let shareContext = try JSONDecoder().decode(ShareContext.self, from: data)
            
            // Process the shared content
            print("Processing shared content: \(shareContext.userMessage)")
            
            // Clean up the shared data
            sharedDefaults.removeObject(forKey: "pendingShare")
            
            // Send haptic feedback
            hapticService.triggerMessageReceivedFeedback()
            
        } catch {
            print("Failed to decode share context: \(error)")
        }
    }
}

// MARK: - App Lifecycle

extension LLMChatApp {
    func sceneDidEnterBackground() {
        backgroundTaskService.handleAppDidEnterBackground()
        cloudKitService.saveChangeToken()
    }
    
    func sceneWillEnterForeground() {
        backgroundTaskService.handleAppWillEnterForeground()
        notificationService.checkAuthorizationStatus()
        cloudKitService.checkCloudKitAvailability()
    }
}