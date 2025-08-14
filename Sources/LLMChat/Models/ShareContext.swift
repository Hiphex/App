import Foundation

// MARK: - Share Context Models

struct ShareContext: Codable {
    var userMessage: String = ""
    var sharedText: String = ""
    var selectedModel: String = ""
    var images: [SharedImage] = []
    var files: [SharedFile] = []
    var urls: [URL] = []
    var targetConversation: SharedConversation?
    var timestamp: Date = Date()
}

struct SharedImage: Codable {
    let data: Data
    let filename: String
}

struct SharedFile: Codable {
    let data: Data
    let filename: String
    let mimeType: String?
}

struct SharedConversation: Codable {
    let id: String
    let title: String
    let lastMessage: String?
    let updatedAt: Date
}