import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    // Model configuration
    var modelId: String
    var temperature: Double
    var systemPrompt: String?
    var allowFallbacks: Bool
    var providerOrder: [String]
    
    // UI state
    var isPinned: Bool
    var isArchived: Bool
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]
    
    init(
        title: String = "New Chat",
        modelId: String = "anthropic/claude-3.5-sonnet",
        temperature: Double = 0.7,
        systemPrompt: String? = nil,
        allowFallbacks: Bool = true,
        providerOrder: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelId = modelId
        self.temperature = temperature
        self.systemPrompt = systemPrompt
        self.allowFallbacks = allowFallbacks
        self.providerOrder = providerOrder
        self.isPinned = false
        self.isArchived = false
        self.messages = []
    }
    
    var lastMessage: Message? {
        messages.sorted { $0.createdAt > $1.createdAt }.first
    }
    
    var unreadCount: Int {
        messages.filter { $0.role == .assistant && !$0.isRead }.count
    }
}