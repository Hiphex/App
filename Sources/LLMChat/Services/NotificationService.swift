import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isNotificationsEnabled = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // Notification categories
    private let messageCategory = "MESSAGE_CATEGORY"
    private let conversationCategory = "CONVERSATION_CATEGORY"
    private let systemCategory = "SYSTEM_CATEGORY"
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional, .criticalAlert]
            )
            
            await MainActor.run {
                isNotificationsEnabled = granted
                if granted {
                    authorizationStatus = .authorized
                } else {
                    authorizationStatus = .denied
                }
            }
            
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized || 
                                            settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        // Message reply actions
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your message..."
        )
        
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark as Read",
            options: []
        )
        
        let deleteAction = UNNotificationAction(
            identifier: "DELETE_ACTION",
            title: "Delete",
            options: [.destructive]
        )
        
        // Categories
        let messageCategory = UNNotificationCategory(
            identifier: self.messageCategory,
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            options: []
        )
        
        let conversationCategory = UNNotificationCategory(
            identifier: self.conversationCategory,
            actions: [markReadAction, deleteAction],
            intentIdentifiers: [],
            options: []
        )
        
        let systemCategory = UNNotificationCategory(
            identifier: self.systemCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            messageCategory,
            conversationCategory,
            systemCategory
        ])
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleMessageNotification(
        conversationId: String,
        messageText: String,
        senderName: String = "Assistant",
        delay: TimeInterval = 0
    ) async {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = messageText.count > 100 ? 
            String(messageText.prefix(100)) + "..." : messageText
        content.sound = .default
        content.categoryIdentifier = messageCategory
        content.userInfo = [
            "conversationId": conversationId,
            "type": "message",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add custom sound and haptics
        content.sound = UNNotificationSound(named: UNNotificationSoundName("message_sound.wav"))
        
        let trigger = delay > 0 ? 
            UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        
        let request = UNNotificationRequest(
            identifier: "message_\(conversationId)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            await updatePendingNotifications()
        } catch {
            print("Failed to schedule message notification: \(error)")
        }
    }
    
    func scheduleConversationUpdateNotification() async {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "LLM Chat"
        content.body = "Your conversations have been updated"
        content.sound = .default
        content.categoryIdentifier = conversationCategory
        content.userInfo = [
            "type": "conversation_update",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let request = UNNotificationRequest(
            identifier: "conversation_update_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            await updatePendingNotifications()
        } catch {
            print("Failed to schedule conversation update notification: \(error)")
        }
    }
    
    func scheduleSystemNotification(
        title: String,
        body: String,
        delay: TimeInterval = 0,
        isCritical: Bool = false
    ) async {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = systemCategory
        content.userInfo = [
            "type": "system",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if isCritical {
            content.sound = .defaultCritical
        } else {
            content.sound = .default
        }
        
        let trigger = delay > 0 ? 
            UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        
        let request = UNNotificationRequest(
            identifier: "system_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            await updatePendingNotifications()
        } catch {
            print("Failed to schedule system notification: \(error)")
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(withIdentifier identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        await updatePendingNotifications()
    }
    
    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        await updatePendingNotifications()
    }
    
    func cancelNotificationsForConversation(_ conversationId: String) async {
        let pendingNotifications = await getPendingNotifications()
        let identifiersToCancel = pendingNotifications
            .filter { notification in
                if let userInfo = notification.content.userInfo as? [String: Any],
                   let notificationConversationId = userInfo["conversationId"] as? String {
                    return notificationConversationId == conversationId
                }
                return false
            }
            .map { $0.identifier }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        await updatePendingNotifications()
    }
    
    private func updatePendingNotifications() async {
        let notifications = await getPendingNotifications()
        await MainActor.run {
            self.pendingNotifications = notifications
        }
    }
    
    private func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Notification Settings
    
    func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                handleReplyAction(userInfo: userInfo, replyText: textResponse.userText)
            }
            
        case "MARK_READ_ACTION":
            handleMarkReadAction(userInfo: userInfo)
            
        case "DELETE_ACTION":
            handleDeleteAction(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleReplyAction(userInfo: [AnyHashable: Any], replyText: String) {
        Task { @MainActor in
            if let conversationId = userInfo["conversationId"] as? String {
                // Handle reply - this would integrate with your message sending logic
                print("Replying to conversation \(conversationId): \(replyText)")
                
                // Send haptic feedback
                HapticService.shared.triggerNotificationFeedback(.success)
            }
        }
    }
    
    private func handleMarkReadAction(userInfo: [AnyHashable: Any]) {
        Task { @MainActor in
            if let conversationId = userInfo["conversationId"] as? String {
                // Mark conversation as read
                print("Marking conversation \(conversationId) as read")
                
                // Clear badge for this conversation
                await cancelNotificationsForConversation(conversationId)
                
                // Send haptic feedback
                HapticService.shared.triggerNotificationFeedback(.success)
            }
        }
    }
    
    private func handleDeleteAction(userInfo: [AnyHashable: Any]) {
        Task { @MainActor in
            if let conversationId = userInfo["conversationId"] as? String {
                // Handle conversation deletion
                print("Deleting conversation \(conversationId)")
                
                // Send haptic feedback
                HapticService.shared.triggerNotificationFeedback(.warning)
            }
        }
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        Task { @MainActor in
            // Navigate to the relevant conversation
            if let conversationId = userInfo["conversationId"] as? String {
                print("Opening conversation \(conversationId)")
                
                // This would integrate with your navigation logic
                // NotificationCenter.default.post(name: .openConversation, object: conversationId)
                
                // Send haptic feedback
                HapticService.shared.triggerImpactFeedback(.light)
            }
        }
    }
}