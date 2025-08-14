import Foundation
import CloudKit
import SwiftData
import Combine

@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    @Published var isCloudKitAvailable = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var syncError: String?
    @Published var isCloudKitEnabled = true
    
    // CloudKit containers and database
    private let container = CKContainer.default()
    private lazy var privateDatabase = container.privateCloudDatabase
    private lazy var sharedDatabase = container.sharedCloudDatabase
    
    // Record types
    private let conversationRecordType = "Conversation"
    private let messageRecordType = "Message"
    private let attachmentRecordType = "Attachment"
    
    // Sync state
    private var changeToken: CKServerChangeToken?
    private var isPerformingSync = false
    private var syncCancellables = Set<AnyCancellable>()
    
    private init() {
        checkCloudKitAvailability()
        loadSyncSettings()
        setupSubscriptions()
    }
    
    // MARK: - Setup and Configuration
    
    func checkCloudKitAvailability() {
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch accountStatus {
                case .available:
                    self.isCloudKitAvailable = true
                    self.requestPermissions()
                case .noAccount:
                    self.isCloudKitAvailable = false
                    self.syncError = "No iCloud account found"
                case .restricted:
                    self.isCloudKitAvailable = false
                    self.syncError = "iCloud access is restricted"
                case .couldNotDetermine:
                    self.isCloudKitAvailable = false
                    self.syncError = "Could not determine iCloud status"
                @unknown default:
                    self.isCloudKitAvailable = false
                    self.syncError = "Unknown iCloud status"
                }
                
                if let error = error {
                    self.syncError = error.localizedDescription
                }
            }
        }
    }
    
    private func requestPermissions() {
        container.requestApplicationPermission(.userDiscoverability) { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKit permission error: \(error)")
                }
                // Continue regardless of permission status for basic sync
                self?.initializeSync()
            }
        }
    }
    
    private func initializeSync() {
        guard isCloudKitAvailable && isCloudKitEnabled else { return }
        
        // Set up remote notifications for CloudKit changes
        setupRemoteNotifications()
        
        // Load previous change token
        loadChangeToken()
        
        // Perform initial sync
        Task {
            await performFullSync()
        }
    }
    
    private func setupRemoteNotifications() {
        // Subscribe to CloudKit remote notifications for real-time sync
        let subscription = CKDatabaseSubscription(subscriptionID: "all-changes")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { subscription, error in
            if let error = error {
                print("Failed to save CloudKit subscription: \(error)")
            } else {
                print("CloudKit subscription saved successfully")
            }
        }
    }
    
    private func setupSubscriptions() {
        // Listen for app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.performIncrementalSync()
                }
            }
            .store(in: &syncCancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.saveChangeToken()
            }
            .store(in: &syncCancellables)
    }
    
    // MARK: - Sync Operations
    
    func performFullSync() async {
        guard isCloudKitAvailable && isCloudKitEnabled && !isPerformingSync else { return }
        
        isPerformingSync = true
        isSyncing = true
        syncProgress = 0.0
        syncError = nil
        
        do {
            // Upload local changes first
            syncProgress = 0.25
            try await uploadLocalChanges()
            
            // Download remote changes
            syncProgress = 0.50
            try await downloadRemoteChanges()
            
            // Resolve conflicts
            syncProgress = 0.75
            try await resolveConflicts()
            
            // Complete sync
            syncProgress = 1.0
            lastSyncDate = Date()
            
            // Schedule notification for successful sync
            await NotificationService.shared.scheduleSystemNotification(
                title: "Sync Complete",
                body: "Your conversations have been synced across devices"
            )
            
        } catch {
            syncError = error.localizedDescription
            print("CloudKit sync failed: \(error)")
            
            // Send haptic feedback for error
            HapticService.shared.triggerErrorFeedback()
        }
        
        isPerformingSync = false
        isSyncing = false
    }
    
    func performIncrementalSync() async {
        guard isCloudKitAvailable && isCloudKitEnabled && !isPerformingSync else { return }
        
        do {
            try await downloadRemoteChanges()
            try await uploadLocalChanges()
        } catch {
            print("Incremental sync failed: \(error)")
        }
    }
    
    func performBackgroundSync() async {
        guard isCloudKitAvailable && isCloudKitEnabled else { return }
        
        do {
            // Quick sync for background processing
            try await downloadRemoteChanges()
            
            // Only upload critical changes in background
            try await uploadCriticalChanges()
            
        } catch {
            print("Background sync failed: \(error)")
        }
    }
    
    // MARK: - Upload Operations
    
    private func uploadLocalChanges() async throws {
        // This would integrate with your SwiftData model context
        // For now, we'll outline the structure
        
        try await uploadConversations()
        try await uploadMessages()
        try await uploadAttachments()
    }
    
    private func uploadCriticalChanges() async throws {
        // Upload only essential changes during background sync
        // This might include new messages or urgent updates
        try await uploadRecentMessages()
    }
    
    private func uploadConversations() async throws {
        // Get conversations that need to be uploaded
        let conversationsToUpload = await getLocalConversationsToUpload()
        
        for conversation in conversationsToUpload {
            let record = try createConversationRecord(from: conversation)
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                await updateLocalConversationWithCloudKitRecord(conversation, record: savedRecord)
            } catch {
                print("Failed to upload conversation: \(error)")
                throw error
            }
        }
    }
    
    private func uploadMessages() async throws {
        let messagesToUpload = await getLocalMessagesToUpload()
        
        for message in messagesToUpload {
            let record = try createMessageRecord(from: message)
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                await updateLocalMessageWithCloudKitRecord(message, record: savedRecord)
            } catch {
                print("Failed to upload message: \(error)")
                throw error
            }
        }
    }
    
    private func uploadAttachments() async throws {
        let attachmentsToUpload = await getLocalAttachmentsToUpload()
        
        for attachment in attachmentsToUpload {
            let record = try createAttachmentRecord(from: attachment)
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                await updateLocalAttachmentWithCloudKitRecord(attachment, record: savedRecord)
            } catch {
                print("Failed to upload attachment: \(error)")
                throw error
            }
        }
    }
    
    private func uploadRecentMessages() async throws {
        // Upload only messages from the last hour for background sync
        let recentMessages = await getRecentLocalMessages()
        
        for message in recentMessages {
            let record = try createMessageRecord(from: message)
            try await privateDatabase.save(record)
        }
    }
    
    // MARK: - Download Operations
    
    private func downloadRemoteChanges() async throws {
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
        
        var changedZoneIDs: [CKRecordZone.ID] = []
        var deletedZoneIDs: [CKRecordZone.ID] = []
        
        changesOperation.recordZoneWithIDChangedBlock = { zoneID in
            changedZoneIDs.append(zoneID)
        }
        
        changesOperation.recordZoneWithIDWasDeletedBlock = { zoneID in
            deletedZoneIDs.append(zoneID)
        }
        
        changesOperation.changeTokenUpdatedBlock = { newToken in
            self.changeToken = newToken
        }
        
        changesOperation.fetchDatabaseChangesCompletionBlock = { newToken, moreComing, error in
            if let error = error {
                print("Database changes fetch failed: \(error)")
                return
            }
            
            self.changeToken = newToken
        }
        
        privateDatabase.add(changesOperation)
        
        // Wait for operation to complete
        try await withCheckedThrowingContinuation { continuation in
            changesOperation.completionBlock = {
                continuation.resume()
            }
        }
        
        // Fetch changes from each changed zone
        for zoneID in changedZoneIDs {
            try await downloadChangesFromZone(zoneID)
        }
    }
    
    private func downloadChangesFromZone(_ zoneID: CKRecordZone.ID) async throws {
        let zoneChangesOperation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration()]
        )
        
        zoneChangesOperation.recordChangedBlock = { record in
            Task { @MainActor in
                await self.processDownloadedRecord(record)
            }
        }
        
        zoneChangesOperation.recordWithIDWasDeletedBlock = { recordID, recordType in
            Task { @MainActor in
                await self.processDeletedRecord(recordID, recordType: recordType)
            }
        }
        
        privateDatabase.add(zoneChangesOperation)
        
        try await withCheckedThrowingContinuation { continuation in
            zoneChangesOperation.completionBlock = {
                continuation.resume()
            }
        }
    }
    
    // MARK: - Record Processing
    
    private func processDownloadedRecord(_ record: CKRecord) async {
        switch record.recordType {
        case conversationRecordType:
            await processConversationRecord(record)
        case messageRecordType:
            await processMessageRecord(record)
        case attachmentRecordType:
            await processAttachmentRecord(record)
        default:
            print("Unknown record type: \(record.recordType)")
        }
    }
    
    private func processDeletedRecord(_ recordID: CKRecord.ID, recordType: String) async {
        switch recordType {
        case conversationRecordType:
            await deleteLocalConversation(withCloudKitID: recordID.recordName)
        case messageRecordType:
            await deleteLocalMessage(withCloudKitID: recordID.recordName)
        case attachmentRecordType:
            await deleteLocalAttachment(withCloudKitID: recordID.recordName)
        default:
            print("Unknown deleted record type: \(recordType)")
        }
    }
    
    private func processConversationRecord(_ record: CKRecord) async {
        // Convert CloudKit record to local conversation
        // This would integrate with your SwiftData model
        print("Processing conversation record: \(record.recordID.recordName)")
    }
    
    private func processMessageRecord(_ record: CKRecord) async {
        // Convert CloudKit record to local message
        print("Processing message record: \(record.recordID.recordName)")
    }
    
    private func processAttachmentRecord(_ record: CKRecord) async {
        // Convert CloudKit record to local attachment
        print("Processing attachment record: \(record.recordID.recordName)")
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflicts() async throws {
        // Get records with conflicts
        let conflictedRecords = await getConflictedRecords()
        
        for conflict in conflictedRecords {
            try await resolveConflict(conflict)
        }
    }
    
    private func resolveConflict(_ conflict: SyncConflict) async throws {
        switch conflict.resolutionStrategy {
        case .serverWins:
            await applyServerRecord(conflict.serverRecord)
        case .clientWins:
            try await uploadLocalRecord(conflict.localRecord)
        case .merge:
            let mergedRecord = try await mergeRecords(
                local: conflict.localRecord,
                server: conflict.serverRecord
            )
            try await uploadLocalRecord(mergedRecord)
        }
    }
    
    private func mergeRecords(local: Any, server: CKRecord) async throws -> Any {
        // Implement smart merging logic based on record type and timestamps
        // For now, return the server record
        return server
    }
    
    // MARK: - Record Creation
    
    private func createConversationRecord(from conversation: Any) throws -> CKRecord {
        // This would create a CloudKit record from your local conversation model
        let record = CKRecord(recordType: conversationRecordType)
        
        // Set fields based on your Conversation model
        // record["title"] = conversation.title
        // record["createdAt"] = conversation.createdAt
        // record["updatedAt"] = conversation.updatedAt
        
        return record
    }
    
    private func createMessageRecord(from message: Any) throws -> CKRecord {
        let record = CKRecord(recordType: messageRecordType)
        
        // Set fields based on your Message model
        // record["content"] = message.content
        // record["role"] = message.role
        // record["timestamp"] = message.timestamp
        
        return record
    }
    
    private func createAttachmentRecord(from attachment: Any) throws -> CKRecord {
        let record = CKRecord(recordType: attachmentRecordType)
        
        // Set fields based on your Attachment model
        // record["filename"] = attachment.filename
        // record["data"] = attachment.data
        
        return record
    }
    
    // MARK: - Local Data Access
    
    private func getLocalConversationsToUpload() async -> [Any] {
        // This would query your SwiftData context for conversations that need uploading
        return []
    }
    
    private func getLocalMessagesToUpload() async -> [Any] {
        // This would query your SwiftData context for messages that need uploading
        return []
    }
    
    private func getLocalAttachmentsToUpload() async -> [Any] {
        // This would query your SwiftData context for attachments that need uploading
        return []
    }
    
    private func getRecentLocalMessages() async -> [Any] {
        // Get messages from the last hour
        return []
    }
    
    private func getConflictedRecords() async -> [SyncConflict] {
        // This would identify records with conflicts between local and remote versions
        return []
    }
    
    private func updateLocalConversationWithCloudKitRecord(_ conversation: Any, record: CKRecord) async {
        // Update local conversation with CloudKit metadata
    }
    
    private func updateLocalMessageWithCloudKitRecord(_ message: Any, record: CKRecord) async {
        // Update local message with CloudKit metadata
    }
    
    private func updateLocalAttachmentWithCloudKitRecord(_ attachment: Any, record: CKRecord) async {
        // Update local attachment with CloudKit metadata
    }
    
    private func deleteLocalConversation(withCloudKitID cloudKitID: String) async {
        // Delete local conversation that was deleted remotely
    }
    
    private func deleteLocalMessage(withCloudKitID cloudKitID: String) async {
        // Delete local message that was deleted remotely
    }
    
    private func deleteLocalAttachment(withCloudKitID cloudKitID: String) async {
        // Delete local attachment that was deleted remotely
    }
    
    private func applyServerRecord(_ record: CKRecord) async {
        // Apply server record to local database
    }
    
    private func uploadLocalRecord(_ record: Any) async throws {
        // Upload local record to CloudKit
    }
    
    // MARK: - Settings and Token Management
    
    private func loadSyncSettings() {
        isCloudKitEnabled = UserDefaults.standard.object(forKey: "CloudKitSyncEnabled") as? Bool ?? true
        
        if let syncDateData = UserDefaults.standard.data(forKey: "LastCloudKitSyncDate") {
            lastSyncDate = try? JSONDecoder().decode(Date.self, from: syncDateData)
        }
    }
    
    private func saveSyncSettings() {
        UserDefaults.standard.set(isCloudKitEnabled, forKey: "CloudKitSyncEnabled")
        
        if let lastSyncDate = lastSyncDate,
           let syncDateData = try? JSONEncoder().encode(lastSyncDate) {
            UserDefaults.standard.set(syncDateData, forKey: "LastCloudKitSyncDate")
        }
    }
    
    private func loadChangeToken() {
        if let tokenData = UserDefaults.standard.data(forKey: "CloudKitChangeToken"),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData) {
            changeToken = token
        }
    }
    
    private func saveChangeToken() {
        guard let changeToken = changeToken else { return }
        
        if let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: changeToken, requiringSecureCoding: true) {
            UserDefaults.standard.set(tokenData, forKey: "CloudKitChangeToken")
        }
    }
    
    // MARK: - Public Configuration
    
    func setCloudKitEnabled(_ enabled: Bool) {
        isCloudKitEnabled = enabled
        saveSyncSettings()
        
        if enabled && isCloudKitAvailable {
            Task {
                await performFullSync()
            }
        }
    }
    
    func forceSyncNow() async {
        await performFullSync()
    }
    
    func resetSync() {
        changeToken = nil
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: "CloudKitChangeToken")
        UserDefaults.standard.removeObject(forKey: "LastCloudKitSyncDate")
        
        Task {
            await performFullSync()
        }
    }
}

// MARK: - Supporting Types

struct SyncConflict {
    let localRecord: Any
    let serverRecord: CKRecord
    let resolutionStrategy: ConflictResolutionStrategy
}

enum ConflictResolutionStrategy {
    case serverWins
    case clientWins
    case merge
}

// MARK: - CloudKit Extensions

extension CKDatabase {
    func save(_ record: CKRecord) async throws -> CKRecord {
        return try await withCheckedThrowingContinuation { continuation in
            save(record) { savedRecord, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let savedRecord = savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }
        }
    }
    
    func fetch(withRecordID recordID: CKRecord.ID) async throws -> CKRecord {
        return try await withCheckedThrowingContinuation { continuation in
            fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let record = record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }
}