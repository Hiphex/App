import Foundation
import SwiftData

enum AttachmentType: String, Codable, CaseIterable {
    case image
    case pdf
    case audio
    case other
}

@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var type: AttachmentType
    var localURL: String
    var thumbnailURL: String?
    var sha256: String
    var sizeBytes: Int64
    var originalFilename: String?
    var mimeType: String?
    
    // Relationships
    var message: Message?
    
    init(
        type: AttachmentType,
        localURL: String,
        sha256: String,
        sizeBytes: Int64,
        originalFilename: String? = nil,
        mimeType: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.type = type
        self.localURL = localURL
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.originalFilename = originalFilename
        self.mimeType = mimeType
    }
    
    var fileURL: URL? {
        URL(string: localURL)
    }
    
    var thumbnailFileURL: URL? {
        guard let thumbnailURL else { return nil }
        return URL(string: thumbnailURL)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}