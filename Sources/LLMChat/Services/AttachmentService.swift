import Foundation
import UIKit
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

class AttachmentService {
    static let shared = AttachmentService()
    
    private let documentsDirectory: URL
    private let attachmentsDirectory: URL
    private let thumbnailsDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        attachmentsDirectory = documentsDirectory.appendingPathComponent("Attachments")
        thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Image Handling
    
    func saveImage(_ image: UIImage, quality: CGFloat = 0.8) -> (url: String, data: Data, thumbnailURL: String?)? {
        guard let imageData = image.jpegData(compressionQuality: quality) else { return nil }
        
        let filename = UUID().uuidString + ".jpg"
        let fileURL = attachmentsDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            
            // Generate and save thumbnail
            let thumbnailURL = generateAndSaveThumbnail(for: image, filename: filename)
            
            return (url: fileURL.path, data: imageData, thumbnailURL: thumbnailURL)
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    func loadImage(from path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - PDF Handling
    
    func savePDF(from data: Data, originalName: String) -> (url: String, thumbnailURL: String?)? {
        let filename = UUID().uuidString + ".pdf"
        let fileURL = attachmentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            
            // Generate PDF thumbnail
            let thumbnailURL = generatePDFThumbnail(from: fileURL, filename: filename)
            
            return (url: fileURL.path, thumbnailURL: thumbnailURL)
        } catch {
            print("Failed to save PDF: \(error)")
            return nil
        }
    }
    
    private func generatePDFThumbnail(from fileURL: URL, filename: String) -> String? {
        guard let document = PDFDocument(url: fileURL),
              let page = document.page(at: 0) else { return nil }
        
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 200.0 / max(pageRect.width, pageRect.height)
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let thumbnailImage = renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return saveThumbnailImage(thumbnailImage, filename: filename.replacingOccurrences(of: ".pdf", with: "_thumb.jpg"))
    }
    
    // MARK: - Audio Handling
    
    func saveAudio(from data: Data, originalName: String) -> (url: String, duration: TimeInterval?)? {
        let filename = UUID().uuidString + ".m4a"
        let fileURL = attachmentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            
            // Get audio duration
            let asset = AVURLAsset(url: fileURL)
            let duration = asset.duration.seconds
            
            return (url: fileURL.path, duration: duration.isFinite ? duration : nil)
        } catch {
            print("Failed to save audio: \(error)")
            return nil
        }
    }
    
    func saveRecordedAudio(from url: URL) -> (url: String, duration: TimeInterval?)? {
        let filename = UUID().uuidString + ".m4a"
        let destinationURL = attachmentsDirectory.appendingPathComponent(filename)
        
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            let asset = AVURLAsset(url: destinationURL)
            let duration = asset.duration.seconds
            
            return (url: destinationURL.path, duration: duration.isFinite ? duration : nil)
        } catch {
            print("Failed to save recorded audio: \(error)")
            return nil
        }
    }
    
    // MARK: - Generic File Handling
    
    func saveFile(from data: Data, originalName: String, mimeType: String) -> (url: String, thumbnailURL: String?)? {
        let fileExtension = URL(fileURLWithPath: originalName).pathExtension
        let filename = UUID().uuidString + "." + fileExtension
        let fileURL = attachmentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return (url: fileURL.path, thumbnailURL: nil)
        } catch {
            print("Failed to save file: \(error)")
            return nil
        }
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateAndSaveThumbnail(for image: UIImage, filename: String) -> String? {
        guard let thumbnail = generateImageThumbnail(from: image) else { return nil }
        let thumbnailFilename = filename.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
        return saveThumbnailImage(thumbnail, filename: thumbnailFilename)
    }
    
    private func generateImageThumbnail(from image: UIImage, maxSize: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        var newSize = maxSize
        
        if aspectRatio > 1 {
            newSize.height = maxSize.width / aspectRatio
        } else {
            newSize.width = maxSize.height * aspectRatio
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: UIGraphicsImageRendererFormat())
        renderer.format.scale = 1.0
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func saveThumbnailImage(_ image: UIImage, filename: String) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save thumbnail: \(error)")
            return nil
        }
    }
    
    // MARK: - File Management
    
    func deleteAttachment(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
    
    func deleteThumbnail(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
    
    // MARK: - Utility Methods
    
    func getAttachmentType(for mimeType: String) -> AttachmentType {
        let type = UTType(mimeType: mimeType)
        
        if type?.conforms(to: .image) == true {
            return .image
        } else if type?.conforms(to: .pdf) == true {
            return .pdf
        } else if type?.conforms(to: .audio) == true {
            return .audio
        } else {
            return .other
        }
    }
    
    func optimizeImageForUpload(_ image: UIImage, maxWidth: CGFloat = 1024) -> UIImage? {
        guard image.size.width > maxWidth else { return image }
        
        let aspectRatio = image.size.height / image.size.width
        let newSize = CGSize(width: maxWidth, height: maxWidth * aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: UIGraphicsImageRendererFormat())
        renderer.format.scale = 1.0
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - File Type Extensions

extension AttachmentService {
    func isImageType(_ mimeType: String) -> Bool {
        return mimeType.hasPrefix("image/")
    }
    
    func isPDFType(_ mimeType: String) -> Bool {
        return mimeType == "application/pdf"
    }
    
    func isAudioType(_ mimeType: String) -> Bool {
        return mimeType.hasPrefix("audio/")
    }
    
    func getSupportedFileTypes() -> [UTType] {
        return [.image, .pdf, .audio, .plainText, .data]
    }
}