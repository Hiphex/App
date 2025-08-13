import SwiftUI
import PDFKit
import AVFoundation

// MARK: - Main Attachment View

struct AttachmentView: View {
    let attachment: Attachment
    @State private var showingFullscreen = false
    
    var body: some View {
        Group {
            switch attachment.type {
            case .image:
                ImageAttachmentView(attachment: attachment)
                    .onTapGesture {
                        showingFullscreen = true
                    }
            case .pdf:
                PDFAttachmentView(attachment: attachment)
                    .onTapGesture {
                        showingFullscreen = true
                    }
            case .audio:
                AudioAttachmentView(attachment: attachment)
            case .other:
                FileAttachmentView(attachment: attachment)
            }
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            FullscreenAttachmentView(attachment: attachment)
        }
    }
}

// MARK: - Image Attachment View

struct ImageAttachmentView: View {
    let attachment: Attachment
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 250, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 200, height: 150)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            } else {
                // Error state
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 200, height: 150)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let loadedImage = AttachmentService.shared.loadImage(from: attachment.localURL) else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.image = loadedImage
            self.isLoading = false
        }
    }
}

// MARK: - PDF Attachment View

struct PDFAttachmentView: View {
    let attachment: Attachment
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if isLoading {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(width: 60, height: 80)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemRed).opacity(0.1))
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "doc.text")
                                .foregroundColor(.red)
                                .font(.title2)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.originalFilename ?? "PDF Document")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if let pageCount = attachment.pageCount {
                        Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(attachment.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let thumbnailPath = attachment.thumbnailURL,
              let loadedImage = AttachmentService.shared.loadImage(from: thumbnailPath) else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.thumbnailImage = loadedImage
            self.isLoading = false
        }
    }
}

// MARK: - Audio Attachment View

struct AudioAttachmentView: View {
    let attachment: Attachment
    @StateObject private var audioPlayer = AudioPlayerService()
    @State private var isPlaying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Play/Pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .disabled(audioPlayer.isLoading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.originalFilename ?? "Audio Recording")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        if let duration = attachment.formattedDuration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(attachment.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if audioPlayer.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Progress bar
            if audioPlayer.duration > 0 {
                ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 0.5)
            }
            
            // Transcription if available
            if let transcription = attachment.transcription, !transcription.isEmpty {
                Text(transcription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .italic()
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(audioPlayer.$isPlaying) { playing in
            isPlaying = playing
        }
    }
    
    private func togglePlayback() {
        guard let fileURL = attachment.fileURL else { return }
        
        if isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play(url: fileURL)
        }
    }
}

// MARK: - Generic File Attachment View

struct FileAttachmentView: View {
    let attachment: Attachment
    
    private var fileIcon: String {
        guard let mimeType = attachment.mimeType else { return "doc" }
        
        if mimeType.hasPrefix("text/") {
            return "doc.text"
        } else if mimeType.hasPrefix("application/") {
            if mimeType.contains("zip") || mimeType.contains("archive") {
                return "archivebox"
            } else {
                return "doc.plaintext"
            }
        } else {
            return "doc"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.originalFilename ?? "Unknown File")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(attachment.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            shareFile()
        }
    }
    
    private func shareFile() {
        guard let fileURL = attachment.fileURL else { return }
        
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Handle iPad presentation
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Fullscreen Attachment View

struct FullscreenAttachmentView: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                switch attachment.type {
                case .image:
                    FullscreenImageView(attachment: attachment)
                case .pdf:
                    FullscreenPDFView(attachment: attachment)
                default:
                    VStack {
                        Text("Preview not available")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(attachment.originalFilename ?? "Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Fullscreen Image View

struct FullscreenImageView: View {
    let attachment: Attachment
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        if scale < 1 {
                                            scale = 1
                                            offset = .zero
                                        } else if scale > 5 {
                                            scale = 5
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        if scale <= 1 {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .task {
            image = AttachmentService.shared.loadImage(from: attachment.localURL)
        }
    }
}

// MARK: - Fullscreen PDF View

struct FullscreenPDFView: View {
    let attachment: Attachment
    
    var body: some View {
        PDFKitView(url: attachment.fileURL)
    }
}

// MARK: - PDFKit Integration

struct PDFKitView: UIViewRepresentable {
    let url: URL?
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let url = url, let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Audio Player Service

@Observable
class AudioPlayerService: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    var isPlaying: Bool = false
    var isLoading: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    func play(url: URL) {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            isLoading = false
            
            audioPlayer?.play()
            isPlaying = true
            
            startProgressTimer()
        } catch {
            print("Failed to play audio: \(error)")
            isLoading = false
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopProgressTimer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        isLoading = false
        stopProgressTimer()
        if let error = error {
            print("Audio decode error: \(error)")
        }
    }
}