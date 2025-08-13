import Foundation
import UIKit
import PDFKit

@Observable
class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - Export Formats
    
    enum ExportFormat: String, CaseIterable {
        case markdown = "md"
        case json = "json"
        case plainText = "txt"
        case pdf = "pdf"
        
        var displayName: String {
            switch self {
            case .markdown: return "Markdown"
            case .json: return "JSON"
            case .plainText: return "Plain Text"
            case .pdf: return "PDF"
            }
        }
        
        var mimeType: String {
            switch self {
            case .markdown: return "text/markdown"
            case .json: return "application/json"
            case .plainText: return "text/plain"
            case .pdf: return "application/pdf"
            }
        }
    }
    
    // MARK: - Export Options
    
    struct ExportOptions {
        var includeAttachments: Bool = true
        var includeTimestamps: Bool = true
        var includeMetadata: Bool = true
        var includeReactions: Bool = true
        var includeToolCalls: Bool = true
        var dateFormat: String = "yyyy-MM-dd HH:mm:ss"
        var includeSystemMessages: Bool = false
    }
    
    // MARK: - Export Methods
    
    func exportConversation(
        _ conversation: Conversation,
        format: ExportFormat,
        options: ExportOptions = ExportOptions()
    ) async throws -> ExportResult {
        
        switch format {
        case .markdown:
            return try await exportToMarkdown(conversation, options: options)
        case .json:
            return try await exportToJSON(conversation, options: options)
        case .plainText:
            return try await exportToPlainText(conversation, options: options)
        case .pdf:
            return try await exportToPDF(conversation, options: options)
        }
    }
    
    func exportMultipleConversations(
        _ conversations: [Conversation],
        format: ExportFormat,
        options: ExportOptions = ExportOptions()
    ) async throws -> ExportResult {
        
        switch format {
        case .markdown:
            return try await exportMultipleToMarkdown(conversations, options: options)
        case .json:
            return try await exportMultipleToJSON(conversations, options: options)
        case .plainText:
            return try await exportMultipleToPlainText(conversations, options: options)
        case .pdf:
            return try await exportMultipleToPDF(conversations, options: options)
        }
    }
    
    // MARK: - Markdown Export
    
    private func exportToMarkdown(_ conversation: Conversation, options: ExportOptions) async throws -> ExportResult {
        var markdown = ""
        
        // Header
        markdown += "# \(conversation.title)\n\n"
        
        if options.includeMetadata {
            markdown += "**Created:** \(formatDate(conversation.createdAt, format: options.dateFormat))\n"
            markdown += "**Updated:** \(formatDate(conversation.updatedAt, format: options.dateFormat))\n"
            markdown += "**Model:** \(conversation.modelId)\n"
            markdown += "**Temperature:** \(conversation.temperature)\n\n"
            
            if let systemPrompt = conversation.systemPrompt {
                markdown += "**System Prompt:** \(systemPrompt)\n\n"
            }
        }
        
        markdown += "---\n\n"
        
        // Messages
        let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        
        for message in sortedMessages {
            if !options.includeSystemMessages && message.role == .system {
                continue
            }
            
            markdown += "## \(message.role.rawValue.capitalized)\n\n"
            
            if options.includeTimestamps {
                markdown += "*\(formatDate(message.createdAt, format: options.dateFormat))*\n\n"
            }
            
            // Message content
            markdown += "\(message.text)\n\n"
            
            // Attachments
            if options.includeAttachments && !message.attachments.isEmpty {
                markdown += "### Attachments\n\n"
                for attachment in message.attachments {
                    markdown += "- **\(attachment.originalFilename ?? "Unknown file")** "
                    markdown += "(\(attachment.type.rawValue), \(attachment.formattedSize))\n"
                    
                    if let transcription = attachment.transcription {
                        markdown += "  - Transcription: \(transcription)\n"
                    }
                }
                markdown += "\n"
            }
            
            // Tool calls
            if options.includeToolCalls && !message.toolCalls.isEmpty {
                markdown += "### Tool Calls\n\n"
                for toolCall in message.toolCalls {
                    markdown += "- **\(toolCall.function.name)**\n"
                    markdown += "  - Arguments: `\(toolCall.function.arguments)`\n"
                }
                markdown += "\n"
            }
            
            // Reactions
            if options.includeReactions && !message.reactions.isEmpty {
                markdown += "### Reactions\n\n"
                let reactionGroups = Dictionary(grouping: message.reactions, by: \.emoji)
                for (emoji, reactions) in reactionGroups {
                    markdown += "\(emoji) \(reactions.count)\n"
                }
                markdown += "\n"
            }
            
            markdown += "---\n\n"
        }
        
        let filename = "\(sanitizeFilename(conversation.title)).\(ExportFormat.markdown.rawValue)"
        return ExportResult(
            filename: filename,
            data: markdown.data(using: .utf8) ?? Data(),
            mimeType: ExportFormat.markdown.mimeType
        )
    }
    
    // MARK: - JSON Export
    
    private func exportToJSON(_ conversation: Conversation, options: ExportOptions) async throws -> ExportResult {
        let exportData = ConversationExport(
            conversation: conversation,
            options: options
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(exportData)
        
        let filename = "\(sanitizeFilename(conversation.title)).\(ExportFormat.json.rawValue)"
        return ExportResult(
            filename: filename,
            data: jsonData,
            mimeType: ExportFormat.json.mimeType
        )
    }
    
    // MARK: - Plain Text Export
    
    private func exportToPlainText(_ conversation: Conversation, options: ExportOptions) async throws -> ExportResult {
        var text = ""
        
        // Header
        text += "\(conversation.title)\n"
        text += String(repeating: "=", count: conversation.title.count) + "\n\n"
        
        if options.includeMetadata {
            text += "Created: \(formatDate(conversation.createdAt, format: options.dateFormat))\n"
            text += "Updated: \(formatDate(conversation.updatedAt, format: options.dateFormat))\n"
            text += "Model: \(conversation.modelId)\n"
            text += "Temperature: \(conversation.temperature)\n\n"
        }
        
        // Messages
        let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        
        for message in sortedMessages {
            if !options.includeSystemMessages && message.role == .system {
                continue
            }
            
            text += "[\(message.role.rawValue.uppercased())"
            
            if options.includeTimestamps {
                text += " - \(formatDate(message.createdAt, format: options.dateFormat))"
            }
            
            text += "]\n"
            text += "\(message.text)\n"
            
            // Attachments
            if options.includeAttachments && !message.attachments.isEmpty {
                text += "\nAttachments:\n"
                for attachment in message.attachments {
                    text += "- \(attachment.originalFilename ?? "Unknown file") "
                    text += "(\(attachment.type.rawValue), \(attachment.formattedSize))\n"
                }
            }
            
            // Reactions
            if options.includeReactions && !message.reactions.isEmpty {
                text += "\nReactions: "
                let reactionGroups = Dictionary(grouping: message.reactions, by: \.emoji)
                let reactionStrings = reactionGroups.map { "\($0.key) \($0.value.count)" }
                text += reactionStrings.joined(separator: ", ")
                text += "\n"
            }
            
            text += "\n" + String(repeating: "-", count: 50) + "\n\n"
        }
        
        let filename = "\(sanitizeFilename(conversation.title)).\(ExportFormat.plainText.rawValue)"
        return ExportResult(
            filename: filename,
            data: text.data(using: .utf8) ?? Data(),
            mimeType: ExportFormat.plainText.mimeType
        )
    }
    
    // MARK: - PDF Export
    
    private func exportToPDF(_ conversation: Conversation, options: ExportOptions) async throws -> ExportResult {
        let markdownResult = try await exportToMarkdown(conversation, options: options)
        let markdownContent = String(data: markdownResult.data, encoding: .utf8) ?? ""
        
        // Create PDF from markdown content
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 612, height: 792)) // US Letter size
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 612, height: 792), nil)
        
        let pageRect = CGRect(x: 40, y: 40, width: 532, height: 712) // With margins
        var currentY: CGFloat = 60
        
        UIGraphicsBeginPDFPage()
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let titleString = NSAttributedString(string: conversation.title, attributes: titleAttributes)
        let titleSize = titleString.boundingRect(with: CGSize(width: pageRect.width, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
        
        titleString.draw(in: CGRect(x: pageRect.minX, y: currentY, width: pageRect.width, height: titleSize.height))
        currentY += titleSize.height + 20
        
        // Content
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let contentString = NSAttributedString(string: markdownContent, attributes: contentAttributes)
        let contentSize = contentString.boundingRect(with: CGSize(width: pageRect.width, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
        
        contentString.draw(in: CGRect(x: pageRect.minX, y: currentY, width: pageRect.width, height: min(contentSize.height, pageRect.maxY - currentY)))
        
        UIGraphicsEndPDFContext()
        
        let filename = "\(sanitizeFilename(conversation.title)).\(ExportFormat.pdf.rawValue)"
        return ExportResult(
            filename: filename,
            data: pdfData as Data,
            mimeType: ExportFormat.pdf.mimeType
        )
    }
    
    // MARK: - Multiple Conversations Export
    
    private func exportMultipleToMarkdown(_ conversations: [Conversation], options: ExportOptions) async throws -> ExportResult {
        var markdown = "# Exported Conversations\n\n"
        markdown += "**Exported on:** \(formatDate(Date(), format: options.dateFormat))\n"
        markdown += "**Number of conversations:** \(conversations.count)\n\n"
        markdown += "---\n\n"
        
        for conversation in conversations {
            let singleResult = try await exportToMarkdown(conversation, options: options)
            let singleMarkdown = String(data: singleResult.data, encoding: .utf8) ?? ""
            markdown += singleMarkdown + "\n\n"
        }
        
        let filename = "exported_conversations_\(formatDate(Date(), format: "yyyy-MM-dd")).md"
        return ExportResult(
            filename: filename,
            data: markdown.data(using: .utf8) ?? Data(),
            mimeType: ExportFormat.markdown.mimeType
        )
    }
    
    private func exportMultipleToJSON(_ conversations: [Conversation], options: ExportOptions) async throws -> ExportResult {
        let exportData = conversations.map { ConversationExport(conversation: $0, options: options) }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(exportData)
        
        let filename = "exported_conversations_\(formatDate(Date(), format: "yyyy-MM-dd")).json"
        return ExportResult(
            filename: filename,
            data: jsonData,
            mimeType: ExportFormat.json.mimeType
        )
    }
    
    private func exportMultipleToPlainText(_ conversations: [Conversation], options: ExportOptions) async throws -> ExportResult {
        var text = "EXPORTED CONVERSATIONS\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        text += "Exported on: \(formatDate(Date(), format: options.dateFormat))\n"
        text += "Number of conversations: \(conversations.count)\n\n"
        
        for (index, conversation) in conversations.enumerated() {
            text += "CONVERSATION \(index + 1)\n"
            text += String(repeating: "=", count: 20) + "\n\n"
            
            let singleResult = try await exportToPlainText(conversation, options: options)
            let singleText = String(data: singleResult.data, encoding: .utf8) ?? ""
            text += singleText + "\n\n"
        }
        
        let filename = "exported_conversations_\(formatDate(Date(), format: "yyyy-MM-dd")).txt"
        return ExportResult(
            filename: filename,
            data: text.data(using: .utf8) ?? Data(),
            mimeType: ExportFormat.plainText.mimeType
        )
    }
    
    private func exportMultipleToPDF(_ conversations: [Conversation], options: ExportOptions) async throws -> ExportResult {
        // For multiple conversations, create a combined markdown first, then convert to PDF
        let markdownResult = try await exportMultipleToMarkdown(conversations, options: options)
        let markdownContent = String(data: markdownResult.data, encoding: .utf8) ?? ""
        
        // Simple PDF generation (in a real app, you'd want more sophisticated PDF layout)
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 612, height: 792), nil)
        UIGraphicsBeginPDFPage()
        
        let pageRect = CGRect(x: 40, y: 40, width: 532, height: 712)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        let attributedString = NSAttributedString(string: markdownContent, attributes: attributes)
        attributedString.draw(in: pageRect)
        
        UIGraphicsEndPDFContext()
        
        let filename = "exported_conversations_\(formatDate(Date(), format: "yyyy-MM-dd")).pdf"
        return ExportResult(
            filename: filename,
            data: pdfData as Data,
            mimeType: ExportFormat.pdf.mimeType
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    // MARK: - Share Functionality
    
    func shareExport(_ result: ExportResult, from sourceView: UIView? = nil) {
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(result.filename)
        
        do {
            try result.data.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                // Handle iPad presentation
                if let popover = activityVC.popoverPresentationController {
                    if let sourceView = sourceView {
                        popover.sourceView = sourceView
                        popover.sourceRect = sourceView.bounds
                    } else {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                }
                
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to share export: \(error)")
        }
    }
}

// MARK: - Export Data Models

struct ExportResult {
    let filename: String
    let data: Data
    let mimeType: String
}

struct ConversationExport: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let modelId: String
    let temperature: Double
    let systemPrompt: String?
    let allowFallbacks: Bool
    let providerOrder: [String]
    let isPinned: Bool
    let isArchived: Bool
    let messages: [MessageExport]
    
    init(conversation: Conversation, options: ExportService.ExportOptions) {
        self.id = conversation.id.uuidString
        self.title = conversation.title
        self.createdAt = conversation.createdAt
        self.updatedAt = conversation.updatedAt
        self.modelId = conversation.modelId
        self.temperature = conversation.temperature
        self.systemPrompt = conversation.systemPrompt
        self.allowFallbacks = conversation.allowFallbacks
        self.providerOrder = conversation.providerOrder
        self.isPinned = conversation.isPinned
        self.isArchived = conversation.isArchived
        
        let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        self.messages = sortedMessages.compactMap { message in
            if !options.includeSystemMessages && message.role == .system {
                return nil
            }
            return MessageExport(message: message, options: options)
        }
    }
}

struct MessageExport: Codable {
    let id: String
    let createdAt: Date
    let role: String
    let text: String
    let state: String
    let isRead: Bool
    let toolCalls: [ToolCallExport]?
    let promptTokens: Int?
    let completionTokens: Int?
    let costUsd: Double?
    let parentMessageId: String?
    let reactions: [MessageReactionExport]?
    let attachments: [AttachmentExport]?
    
    init(message: Message, options: ExportService.ExportOptions) {
        self.id = message.id.uuidString
        self.createdAt = message.createdAt
        self.role = message.role.rawValue
        self.text = message.text
        self.state = message.state.rawValue
        self.isRead = message.isRead
        self.promptTokens = message.promptTokens
        self.completionTokens = message.completionTokens
        self.costUsd = message.costUsd
        self.parentMessageId = message.parentMessageId?.uuidString
        
        self.toolCalls = options.includeToolCalls && !message.toolCalls.isEmpty ?
            message.toolCalls.map(ToolCallExport.init) : nil
        
        self.reactions = options.includeReactions && !message.reactions.isEmpty ?
            message.reactions.map(MessageReactionExport.init) : nil
        
        self.attachments = options.includeAttachments && !message.attachments.isEmpty ?
            message.attachments.map(AttachmentExport.init) : nil
    }
}

struct ToolCallExport: Codable {
    let id: String
    let type: String
    let function: ToolFunctionExport
    
    init(toolCall: ToolCall) {
        self.id = toolCall.id
        self.type = toolCall.type
        self.function = ToolFunctionExport(function: toolCall.function)
    }
}

struct ToolFunctionExport: Codable {
    let name: String
    let arguments: String
    
    init(function: ToolFunction) {
        self.name = function.name
        self.arguments = function.arguments
    }
}

struct MessageReactionExport: Codable {
    let emoji: String
    let userId: String?
    let timestamp: Date
    
    init(reaction: MessageReaction) {
        self.emoji = reaction.emoji
        self.userId = reaction.userId
        self.timestamp = reaction.timestamp
    }
}

struct AttachmentExport: Codable {
    let id: String
    let createdAt: Date
    let type: String
    let originalFilename: String?
    let mimeType: String?
    let sizeBytes: Int64
    let duration: TimeInterval?
    let transcription: String?
    let width: Int?
    let height: Int?
    let pageCount: Int?
    
    init(attachment: Attachment) {
        self.id = attachment.id.uuidString
        self.createdAt = attachment.createdAt
        self.type = attachment.type.rawValue
        self.originalFilename = attachment.originalFilename
        self.mimeType = attachment.mimeType
        self.sizeBytes = attachment.sizeBytes
        self.duration = attachment.duration
        self.transcription = attachment.transcription
        self.width = attachment.width
        self.height = attachment.height
        self.pageCount = attachment.pageCount
    }
}