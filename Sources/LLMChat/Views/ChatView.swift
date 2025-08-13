import SwiftUI
import SwiftData
import PhotosUI

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    
    let conversation: Conversation
    
    @State private var messageText = ""
    @State private var showingModelPicker = false
    @State private var isGenerating = false
    @State private var currentStreamingMessageId: UUID?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingCameraPicker = false
    
    private var sortedMessages: [Message] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                List {
                    ForEach(sortedMessages) { message in
                        MessageRowView(message: message)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .id(message.id)
                    }
                }
                .listStyle(.plain)
                .onChange(of: sortedMessages.count) { _, _ in
                    if let lastMessage = sortedMessages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Composer
            VStack(spacing: 0) {
                Divider()
                
                MessageComposerView(
                    text: $messageText,
                    isGenerating: $isGenerating,
                    selectedPhotos: $selectedPhotos,
                    selectedImages: $selectedImages,
                    onSend: sendMessage,
                    onCancel: cancelCurrentGeneration,
                    onCameraCapture: {
                        showingCameraPicker = true
                    },
                    onModelSelect: {
                        showingModelPicker = true
                    }
                )
                .padding()
            }
            .background(.regularMaterial)
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingModelPicker = true
                } label: {
                    Text(modelDisplayName)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerView(
                selectedModel: Binding(
                    get: { conversation.modelId },
                    set: { newModel in
                        conversation.modelId = newModel
                        conversation.updatedAt = Date()
                        try? modelContext.save()
                    }
                )
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPickerView { image in
                selectedImages.append(image)
                showingCameraPicker = false
            }
        }
        .onAppear {
            markMessagesAsRead()
        }
    }
    
    private var modelDisplayName: String {
        conversation.modelId.components(separatedBy: "/").last?.capitalized ?? conversation.modelId
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty else { return }
        
        // Haptic feedback for sending message
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let userMessage = Message(
            role: .user,
            text: messageText,
            conversation: conversation
        )
        
        // Handle image attachments
        if !selectedImages.isEmpty {
            for image in selectedImages {
                // Optimize image before saving
                let optimizedImage = ImageStorageService.shared.optimizeImageForUpload(image) ?? image
                if let (url, data) = ImageStorageService.shared.saveImage(optimizedImage) {
                    let attachment = Attachment(
                        type: .image,
                        localURL: url,
                        sha256: data.sha256,
                        sizeBytes: Int64(data.count),
                        mimeType: "image/jpeg"
                    )
                    modelContext.insert(attachment)
                    userMessage.attachments.append(attachment)
                }
            }
        }
        
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        
        // Update title if this is the first message
        if conversation.messages.count == 1 {
            conversation.title = String(messageText.prefix(50))
        }
        
        let assistantMessage = Message(
            role: .assistant,
            text: "",
            conversation: conversation
        )
        assistantMessage.state = .streaming
        
        modelContext.insert(assistantMessage)
        conversation.messages.append(assistantMessage)
        
        try? modelContext.save()
        
        let messageTextToSend = messageText
        let imagesToSend = selectedImages
        messageText = ""
        selectedImages.removeAll()
        selectedPhotos.removeAll()
        isGenerating = true
        currentStreamingMessageId = assistantMessage.id
        
        Task {
            await generateResponse(userMessage: messageTextToSend, images: imagesToSend, assistantMessage: assistantMessage)
        }
    }
    
    @MainActor
    private func generateResponse(userMessage: String, images: [UIImage], assistantMessage: Message) async {
        guard let apiKey = appState.currentAPIKey else {
            assistantMessage.text = "Error: No API key found"
            assistantMessage.state = .error
            isGenerating = false
            try? modelContext.save()
            return
        }
        
        var messages = conversation.messages
            .filter { $0.state == .complete }
            .map { message -> ChatMessage in
                if message.attachments.isEmpty {
                    return ChatMessage(role: message.role.rawValue, text: message.text)
                } else {
                    // Handle multimodal messages
                    var content: [ContentItem] = []
                    
                    // Add text content if present
                    if !message.text.isEmpty {
                        content.append(ContentItem(type: "text", text: message.text))
                    }
                    
                    // Add image content
                    for attachment in message.attachments {
                        if attachment.type == .image,
                           let data = try? Data(contentsOf: URL(fileURLWithPath: attachment.localURL)) {
                            let base64String = data.base64EncodedString()
                            let dataURL = "data:\(attachment.mimeType ?? "image/jpeg");base64,\(base64String)"
                            content.append(ContentItem(type: "image_url", imageUrl: dataURL))
                        }
                    }
                    
                    return ChatMessage(role: message.role.rawValue, content: content)
                }
            }
        
        // Add the current user message with images
        var currentContent: [ContentItem] = []
        if !userMessage.isEmpty {
            currentContent.append(ContentItem(type: "text", text: userMessage))
        }
        
        for image in images {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let base64String = imageData.base64EncodedString()
                let dataURL = "data:image/jpeg;base64,\(base64String)"
                currentContent.append(ContentItem(type: "image_url", imageUrl: dataURL))
            }
        }
        
        messages.append(ChatMessage(role: "user", content: currentContent))
        
        let request = ChatCompletionRequest(
            model: conversation.modelId,
            messages: messages,
            temperature: conversation.temperature,
            maxTokens: nil,
            stream: true,
            tools: nil,
            toolChoice: nil,
            providerOrder: conversation.providerOrder.isEmpty ? nil : conversation.providerOrder,
            allowFallbacks: conversation.allowFallbacks
        )
        
        OpenRouterAPI.shared.streamMessage(
            request: request,
            apiKey: apiKey,
            messageId: assistantMessage.id,
            onToken: { token in
                assistantMessage.text += token
                try? modelContext.save()
            },
            onComplete: { usage in
                assistantMessage.state = .complete
                
                if let usage = usage {
                    assistantMessage.promptTokens = usage.promptTokens
                    assistantMessage.completionTokens = usage.completionTokens
                    
                    // Calculate cost if we have pricing info
                    // This would be enhanced with actual model pricing from the Models API
                }
                
                conversation.updatedAt = Date()
                isGenerating = false
                currentStreamingMessageId = nil
                try? modelContext.save()
            },
            onError: { error in
                let errorMessage = error.localizedDescription
                let recoverySuggestion = (error as? OpenRouterError)?.recoverySuggestion
                
                assistantMessage.text = "Error: \(errorMessage)"
                if let suggestion = recoverySuggestion {
                    assistantMessage.text += "\n\n💡 \(suggestion)"
                }
                
                assistantMessage.state = .error
                isGenerating = false
                currentStreamingMessageId = nil
                try? modelContext.save()
            }
        )
    }
    
    private func cancelCurrentGeneration() {
        guard let messageId = currentStreamingMessageId else { return }
        
        OpenRouterAPI.shared.cancelStream(for: messageId)
        
        // Update the message state
        if let message = conversation.messages.first(where: { $0.id == messageId }) {
            message.state = .error
            message.text = message.text.isEmpty ? "Generation cancelled" : message.text + "\n\n[Generation cancelled]"
        }
        
        isGenerating = false
        currentStreamingMessageId = nil
        try? modelContext.save()
    }
    
    private func markMessagesAsRead() {
        for message in conversation.messages where !message.isRead {
            message.isRead = true
        }
        try? modelContext.save()
    }
}

struct MessageRowView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                UserMessageBubble(message: message)
            } else {
                AssistantMessageBubble(message: message)
                Spacer()
            }
        }
    }
}

struct UserMessageBubble: View {
    let message: Message
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .trailing, spacing: 8) {
                // Show images if any
                if !message.attachments.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                        ForEach(message.attachments.filter { $0.type == .image }, id: \.id) { attachment in
                            AttachmentImageView(attachment: attachment)
                                .frame(maxWidth: 100, maxHeight: 100)
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Show text if any
                if !message.text.isEmpty {
                    Text(message.text)
                        .padding(12)
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.text
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                shareMessage()
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive, action: {
                                deleteMessage()
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            
            Text(message.createdAt, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
    }
    
    private func shareMessage() {
        let activityVC = UIActivityViewController(activityItems: [message.text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func deleteMessage() {
        message.conversation?.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        try? modelContext.save()
    }
}

struct AssistantMessageBubble: View {
    let message: Message
    @Environment(\.modelContext) private var modelContext
    @State private var showingReactions = false
    
    private let availableReactions = ["❤️", "⭐", "😂", "👍", "👎"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .padding(12)
                        .background(.gray.opacity(0.1))
                        .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
                        .onTapGesture(count: 2) {
                            showingReactions.toggle()
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.text
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                shareMessage()
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: {
                                retryMessage()
                            }) {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            
                            Button(role: .destructive, action: {
                                deleteMessage()
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    
                    if message.state == .streaming {
                        TypingIndicatorView()
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Show existing reactions
                    if !message.reactions.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(Set(message.reactions.map { $0.emoji })), id: \.self) { emoji in
                                let count = message.reactions.filter { $0.emoji == emoji }.count
                                Button(action: {
                                    toggleReaction(emoji)
                                }) {
                                    HStack(spacing: 2) {
                                        Text(emoji)
                                        if count > 1 {
                                            Text("\(count)")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.gray.opacity(0.2))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Reaction picker
                    if showingReactions {
                        HStack(spacing: 8) {
                            ForEach(availableReactions, id: \.self) { emoji in
                                Button(action: {
                                    addReaction(emoji)
                                    showingReactions = false
                                }) {
                                    Text(emoji)
                                        .font(.title3)
                                        .padding(8)
                                        .background(.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    HStack {
                        Text(message.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let totalTokens = message.totalTokens {
                            Text("\(totalTokens) tokens")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if message.state == .error {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity * 0.8, alignment: .leading)
    }
    
    private func addReaction(_ emoji: String) {
        let reaction = MessageReaction(emoji: emoji)
        message.reactions.append(reaction)
        try? modelContext.save()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func toggleReaction(_ emoji: String) {
        if let existingIndex = message.reactions.firstIndex(where: { $0.emoji == emoji }) {
            message.reactions.remove(at: existingIndex)
        } else {
            let reaction = MessageReaction(emoji: emoji)
            message.reactions.append(reaction)
        }
        try? modelContext.save()
    }
    
    private func shareMessage() {
        let activityVC = UIActivityViewController(activityItems: [message.text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func retryMessage() {
        // Reset message state and trigger regeneration
        message.text = ""
        message.state = .streaming
        try? modelContext.save()
        
        // Trigger regeneration (this would need to be passed in as a callback in a real implementation)
        // For now, we'll just mark it as an error with instructions
        message.text = "To retry this message, please send your request again."
        message.state = .error
        try? modelContext.save()
    }
    
    private func deleteMessage() {
        message.conversation?.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        try? modelContext.save()
    }
}

struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.gray)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct MessageComposerView: View {
    @Binding var text: String
    @Binding var isGenerating: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var selectedImages: [UIImage]
    let onSend: () -> Void
    let onCancel: () -> Void
    let onCameraCapture: () -> Void
    let onModelSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Image preview section
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                    selectedPhotos.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white, in: Circle())
                                }
                                .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Input section
            HStack(alignment: .bottom, spacing: 12) {
                Button(action: onModelSelect) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                }
                
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Add photos")
                .accessibilityHint("Select photos from your photo library to include with your message")
                .onChange(of: selectedPhotos) { _, newItems in
                    Task {
                        await loadSelectedImages(from: newItems)
                    }
                }
                
                Button(action: onCameraCapture) {
                    Image(systemName: "camera")
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Take photo")
                .accessibilityHint("Take a new photo with your camera to include with your message")
                
                TextField("Message", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .disabled(isGenerating)
                
                Button(action: isGenerating ? onCancel : onSend) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(isGenerating ? .red : (canSend ? .blue : .gray))
                }
                .disabled(!canSend && !isGenerating)
                .accessibilityLabel(isGenerating ? "Stop generation" : "Send message")
                .accessibilityHint(isGenerating ? "Stops the current AI response" : "Sends your message to the AI")
            }
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
    }
    
    private func loadSelectedImages(from items: [PhotosPickerItem]) async {
        selectedImages.removeAll()
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImages.append(image)
                }
            }
        }
    }
}

struct AttachmentImageView: View {
    let attachment: Attachment
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        Task {
            if let loadedImage = ImageStorageService.shared.loadImage(from: attachment.localURL) {
                await MainActor.run {
                    self.image = loadedImage
                }
            }
        }
    }
}

struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        
        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// Helper extension for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Helper extension for SHA256
import CryptoKit

extension Data {
    var sha256: String {
        let hashed = SHA256.hash(data: self)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationView {
        ChatView(conversation: Conversation())
            .environmentObject(AppState())
    }
    .modelContainer(for: [
        Conversation.self,
        Message.self,
        Attachment.self,
        ModelInfo.self
    ])
}