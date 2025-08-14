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
    
    // Media-specific metadata
    var duration: TimeInterval? // For audio/video files
    var transcription: String? // For audio files with speech-to-text
    var width: Int? // For images
    var height: Int? // For images
    var pageCount: Int? // For PDFs
    
    // Relationships
    var message: Message?
    
    init(
        type: AttachmentType,
        localURL: String,
        sha256: String,
        sizeBytes: Int64,
        originalFilename: String? = nil,
        mimeType: String? = nil,
        duration: TimeInterval? = nil,
        transcription: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        pageCount: Int? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.type = type
        self.localURL = localURL
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.originalFilename = originalFilename
        self.mimeType = mimeType
        self.duration = duration
        self.transcription = transcription
        self.width = width
        self.height = height
        self.pageCount = pageCount
    }
    
    var fileURL: URL? {
        // Handle both file paths and URLs
        if localURL.hasPrefix("file://") {
            return URL(string: localURL)
        } else {
            return URL(fileURLWithPath: localURL)
        }
    }
    
    var thumbnailFileURL: URL? {
        guard let thumbnailURL else { return nil }
        
        // Handle both file paths and URLs
        if thumbnailURL.hasPrefix("file://") {
            return URL(string: thumbnailURL)
        } else {
            return URL(fileURLWithPath: thumbnailURL)
        }
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration)
    }
}