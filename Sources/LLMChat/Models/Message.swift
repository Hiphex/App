import Foundation
import SwiftData

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case tool
    case system
}

enum MessageState: String, Codable, CaseIterable {
    case sending
    case streaming
    case complete
    case error
}

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var role: MessageRole
    var text: String
    var state: MessageState
    var isRead: Bool
    
    // Tool calling
    var toolCalls: [ToolCall]
    
    // Usage tracking
    var promptTokens: Int?
    var completionTokens: Int?
    var costUsd: Double?
    
    // Message threading
    var parentMessageId: UUID?
    
    // Reactions
    var reactions: [MessageReaction]
    
    // Relationships
    var conversation: Conversation?
    
    @Relationship(deleteRule: .cascade, inverse: \Attachment.message)
    var attachments: [Attachment]
    
    init(
        role: MessageRole,
        text: String,
        conversation: Conversation? = nil,
        parentMessageId: UUID? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.role = role
        self.text = text
        self.state = role == .user ? .complete : .sending
        self.isRead = role == .user
        self.toolCalls = []
        self.reactions = []
        self.attachments = []
        self.conversation = conversation
        self.parentMessageId = parentMessageId
    }
    
    var totalTokens: Int? {
        guard let prompt = promptTokens, let completion = completionTokens else { return nil }
        return prompt + completion
    }
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: ToolFunction
}

struct ToolFunction: Codable {
    let name: String
    let arguments: String
}

struct MessageReaction: Codable {
    let emoji: String
    let userId: String? // For future multi-user support
    let timestamp: Date
    
    init(emoji: String) {
        self.emoji = emoji
        self.userId = nil
        self.timestamp = Date()
    }
}