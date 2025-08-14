import Foundation
import BackgroundTasks
import SwiftData
import UserNotifications

@MainActor
class BackgroundTaskService: ObservableObject {
    static let shared = BackgroundTaskService()
    
    // Background task identifiers
    private let syncTaskIdentifier = "com.llmchat.background-sync"
    private let cleanupTaskIdentifier = "com.llmchat.background-cleanup"
    
    @Published var isProcessingBackground = false
    @Published var lastBackgroundSync: Date?
    
    private init() {
        registerBackgroundTasks()
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        // Register background app refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: syncTaskIdentifier,
            using: nil
        ) { task in
            Task {
                await self.handleBackgroundSync(task as! BGAppRefreshTask)
            }
        }
        
        // Register background processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: cleanupTaskIdentifier,
            using: nil
        ) { task in
            Task {
                await self.handleBackgroundCleanup(task as! BGProcessingTask)
            }
        }
    }
    
    // MARK: - Schedule Background Tasks
    
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: syncTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background sync scheduled")
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }
    
    func scheduleBackgroundCleanup() {
        let request = BGProcessingTaskRequest(identifier: cleanupTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background cleanup scheduled")
        } catch {
            print("Failed to schedule background cleanup: \(error)")
        }
    }
    
    // MARK: - Background Task Handlers
    
    private func handleBackgroundSync(_ task: BGAppRefreshTask) async {
        print("Background sync started")
        isProcessingBackground = true
        
        // Schedule the next background sync
        scheduleBackgroundSync()
        
        let taskCompleted = await withCheckedContinuation { continuation in
            Task {
                do {
                    // Perform CloudKit sync
                    await CloudKitService.shared.performBackgroundSync()
                    
                    // Check for pending messages that need processing
                    await processePendingMessages()
                    
                    // Update last sync time
                    lastBackgroundSync = Date()
                    
                    // Send local notification if there are new messages
                    await checkForNewMessagesAndNotify()
                    
                    continuation.resume(returning: true)
                } catch {
                    print("Background sync failed: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
        
        isProcessingBackground = false
        task.setTaskCompleted(success: taskCompleted)
        print("Background sync completed")
    }
    
    private func handleBackgroundCleanup(_ task: BGProcessingTask) async {
        print("Background cleanup started")
        isProcessingBackground = true
        
        // Schedule the next cleanup
        scheduleBackgroundCleanup()
        
        let taskCompleted = await withCheckedContinuation { continuation in
            Task {
                do {
                    // Clean up old attachments
                    await ImageStorageService.shared.cleanupOldAttachments()
                    
                    // Clean up temporary files
                    await cleanupTemporaryFiles()
                    
                    // Optimize database
                    await optimizeDatabase()
                    
                    continuation.resume(returning: true)
                } catch {
                    print("Background cleanup failed: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
        
        isProcessingBackground = false
        task.setTaskCompleted(success: taskCompleted)
        print("Background cleanup completed")
    }
    
    // MARK: - Background Processing Methods
    
    private func processePendingMessages() async {
        // Process any messages that were interrupted during sending
        // This would integrate with your existing message processing logic
        print("Processing pending messages...")
    }
    
    private func checkForNewMessagesAndNotify() async {
        // Check if there are new messages since last check
        // Send local notifications for important updates
        print("Checking for new messages...")
        
        // Example: Send notification for conversation updates
        await NotificationService.shared.scheduleConversationUpdateNotification()
    }
    
    private func cleanupTemporaryFiles() async {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
            
            for fileURL in tempFiles {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < twoDaysAgo {
                    try FileManager.default.removeItem(at: fileURL)
                    print("Cleaned up temp file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Failed to cleanup temp files: \(error)")
        }
    }
    
    private func optimizeDatabase() async {
        // Perform database optimization tasks
        print("Optimizing database...")
        // This would integrate with SwiftData optimization if needed
    }
    
    // MARK: - App Lifecycle Methods
    
    func handleAppDidEnterBackground() {
        scheduleBackgroundSync()
        scheduleBackgroundCleanup()
    }
    
    func handleAppWillEnterForeground() {
        // Cancel any pending background tasks when app comes to foreground
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: syncTaskIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: cleanupTaskIdentifier)
    }
}