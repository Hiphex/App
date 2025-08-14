import Foundation
import UIKit

class ImageStorageService {
    static let shared = ImageStorageService()
    
    private let documentsDirectory: URL
    private let imagesDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        imagesDirectory = documentsDirectory.appendingPathComponent("Images")
        
        // Create images directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }
    
    func saveImage(_ image: UIImage, quality: CGFloat = 0.8) -> (url: String, data: Data)? {
        guard let imageData = image.jpegData(compressionQuality: quality) else { return nil }
        
        let filename = UUID().uuidString + ".jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            return (url: fileURL.path, data: imageData)
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    func loadImage(from path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return UIImage(data: data)
    }
    
    func generateThumbnail(from image: UIImage, maxSize: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        // Calculate the aspect ratio and new size
        let aspectRatio = image.size.width / image.size.height
        var newSize = maxSize
        
        if aspectRatio > 1 {
            // Landscape
            newSize.height = maxSize.width / aspectRatio
        } else {
            // Portrait or square
            newSize.width = maxSize.height * aspectRatio
        }
        
        // Use UIGraphicsImageRenderer for better performance and memory usage
        let renderer = UIGraphicsImageRenderer(size: newSize, format: UIGraphicsImageRendererFormat())
        renderer.format.scale = 1.0 // Prevent retina scaling issues
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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
    
    func deleteImage(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
    
    // MARK: - Cleanup Methods
    
    func cleanupOldAttachments() async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let attachmentsPath = documentsPath.appendingPathComponent("attachments")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: attachmentsPath, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            
            for fileURL in files {
                if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < thirtyDaysAgo {
                    try? FileManager.default.removeItem(at: fileURL)
                    print("Cleaned up old attachment: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Failed to cleanup old attachments: \(error)")
        }
    }
}