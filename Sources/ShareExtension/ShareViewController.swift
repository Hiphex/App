import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    private var selectedModel: String = "anthropic/claude-3.5-sonnet"
    private var shareContext: ShareContext = ShareContext()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadSharedContent()
        loadUserPreferences()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "Share to LLM Chat"
        navigationController?.navigationBar.tintColor = .systemBlue
        
        // Add model selection option
        let modelConfig = SLComposeSheetConfigurationItem()
        modelConfig?.title = "AI Model"
        modelConfig?.value = getModelDisplayName(selectedModel)
        modelConfig?.tapHandler = { [weak self] in
            self?.presentModelPicker()
        }
        
        // Add conversation option
        let conversationConfig = SLComposeSheetConfigurationItem()
        conversationConfig?.title = "Conversation"
        conversationConfig?.value = shareContext.targetConversation?.title ?? "New Conversation"
        conversationConfig?.tapHandler = { [weak self] in
            self?.presentConversationPicker()
        }
        
        // Set configuration items
        if let modelConfig = modelConfig {
            configurationItems = [modelConfig]
        }
        
        if let conversationConfig = conversationConfig {
            configurationItems?.append(conversationConfig)
        }
        
        // Set placeholder text based on content type
        updatePlaceholderText()
    }
    
    private func updatePlaceholderText() {
        let hasImages = !shareContext.images.isEmpty
        let hasFiles = !shareContext.files.isEmpty
        let hasText = !shareContext.sharedText.isEmpty
        
        var placeholder = "What would you like to ask about"
        
        if hasImages && hasFiles {
            placeholder += " these images and files?"
        } else if hasImages {
            placeholder += " \(shareContext.images.count == 1 ? "this image" : "these images")?"
        } else if hasFiles {
            placeholder += " \(shareContext.files.count == 1 ? "this file" : "these files")?"
        } else if hasText {
            placeholder += " this content?"
        } else {
            placeholder = "What can I help you with?"
        }
        
        self.placeholder = placeholder
    }
    
    // MARK: - Content Loading
    
    private func loadSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            return
        }
        
        guard let attachments = extensionItem.attachments else {
            return
        }
        
        let group = DispatchGroup()
        
        for attachment in attachments {
            group.enter()
            
            if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                loadTextContent(from: attachment) {
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                loadImageContent(from: attachment) {
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                loadURLContent(from: attachment) {
                    group.leave()
                }
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadFileContent(from: attachment) {
                    group.leave()
                }
            } else {
                // Try to load as generic content
                loadGenericContent(from: attachment) {
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.updatePlaceholderText()
            self.updateCharacterCount()
        }
    }
    
    private func loadTextContent(from attachment: NSItemProvider, completion: @escaping () -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] item, error in
            defer { completion() }
            
            if let error = error {
                print("Error loading text content: \(error)")
                return
            }
            
            if let text = item as? String {
                DispatchQueue.main.async {
                    self?.shareContext.sharedText = text
                    self?.textView.text = text
                }
            }
        }
    }
    
    private func loadImageContent(from attachment: NSItemProvider, completion: @escaping () -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
            defer { completion() }
            
            if let error = error {
                print("Error loading image content: \(error)")
                return
            }
            
            var imageData: Data?
            
            if let image = item as? UIImage {
                imageData = image.jpegData(compressionQuality: 0.8)
            } else if let url = item as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let data = item as? Data {
                imageData = data
            }
            
            if let data = imageData {
                DispatchQueue.main.async {
                    self?.shareContext.images.append(SharedImage(data: data, filename: "image.jpg"))
                }
            }
        }
    }
    
    private func loadURLContent(from attachment: NSItemProvider, completion: @escaping () -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            defer { completion() }
            
            if let error = error {
                print("Error loading URL content: \(error)")
                return
            }
            
            if let url = item as? URL {
                DispatchQueue.main.async {
                    self?.shareContext.urls.append(url)
                    
                    // Add URL to shared text
                    let urlText = url.absoluteString
                    if self?.shareContext.sharedText.isEmpty == true {
                        self?.shareContext.sharedText = urlText
                        self?.textView.text = urlText
                    } else {
                        self?.shareContext.sharedText += "\n\(urlText)"
                        self?.textView.text = self?.shareContext.sharedText
                    }
                }
            }
        }
    }
    
    private func loadFileContent(from attachment: NSItemProvider, completion: @escaping () -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            defer { completion() }
            
            if let error = error {
                print("Error loading file content: \(error)")
                return
            }
            
            if let url = item as? URL {
                // Load file data asynchronously to prevent memory issues
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        // Check file size before loading to prevent memory issues
                        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                        let fileSize = resourceValues.fileSize ?? 0
                        
                        // Limit file size to 50MB to prevent memory issues
                        guard fileSize < 50_000_000 else {
                            print("File too large: \(fileSize) bytes")
                            return
                        }
                        
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        
                        DispatchQueue.main.async {
                            self?.shareContext.files.append(SharedFile(
                                data: data, 
                                filename: filename, 
                                mimeType: self?.getMimeType(for: url)
                            ))
                        }
                    } catch {
                        print("Error reading file data: \(error)")
                    }
                }
            }
        }
    }
    
    private func loadGenericContent(from attachment: NSItemProvider, completion: @escaping () -> Void) {
        // Try to load as plain text first
        if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            loadTextContent(from: attachment, completion: completion)
        } else {
            completion()
        }
    }
    
    // MARK: - Configuration
    
    private func presentModelPicker() {
        let alertController = UIAlertController(title: "Select AI Model", message: "Choose the AI model for processing", preferredStyle: .actionSheet)
        
        let models = [
            ("anthropic/claude-3.5-sonnet", "Claude 3.5 Sonnet", "Best overall performance"),
            ("openai/gpt-4o", "GPT-4o", "Great for analysis and reasoning"),
            ("anthropic/claude-3-haiku", "Claude 3 Haiku", "Fast and efficient"),
            ("openai/gpt-3.5-turbo", "GPT-3.5 Turbo", "Quick responses"),
            ("google/gemini-pro", "Gemini Pro", "Google's latest model")
        ]
        
        for (id, name, description) in models {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.selectedModel = id
                self?.reloadConfigurationItems()
            }
            action.setValue(description, forKey: "subtitle")
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Set up for iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alertController, animated: true)
    }
    
    private func presentConversationPicker() {
        let alertController = UIAlertController(title: "Select Conversation", message: "Choose where to add this content", preferredStyle: .actionSheet)
        
        // Add "New Conversation" option
        let newAction = UIAlertAction(title: "New Conversation", style: .default) { [weak self] _ in
            self?.shareContext.targetConversation = nil
            self?.reloadConfigurationItems()
        }
        alertController.addAction(newAction)
        
        // Load recent conversations from shared app group
        let recentConversations = loadRecentConversations()
        
        for conversation in recentConversations.prefix(5) {
            let action = UIAlertAction(title: conversation.title, style: .default) { [weak self] _ in
                self?.shareContext.targetConversation = conversation
                self?.reloadConfigurationItems()
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Set up for iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alertController, animated: true)
    }
    
    // MARK: - SLComposeServiceViewController Overrides
    
    override func isContentValid() -> Bool {
        let hasContent = !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !shareContext.images.isEmpty ||
                        !shareContext.files.isEmpty ||
                        !shareContext.urls.isEmpty
        
        updateCharacterCount()
        return hasContent
    }
    
    override func didSelectPost() {
        // Prepare the content for sharing
        shareContext.userMessage = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        shareContext.selectedModel = selectedModel
        
        // Save to shared app group container
        saveSharedContent()
        
        // Open the main app
        openMainApp()
        
        // Complete the extension
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        let modelConfig = SLComposeSheetConfigurationItem()
        modelConfig?.title = "AI Model"
        modelConfig?.value = getModelDisplayName(selectedModel)
        modelConfig?.tapHandler = { [weak self] in
            self?.presentModelPicker()
        }
        
        let conversationConfig = SLComposeSheetConfigurationItem()
        conversationConfig?.title = "Conversation"
        conversationConfig?.value = shareContext.targetConversation?.title ?? "New Conversation"
        conversationConfig?.tapHandler = { [weak self] in
            self?.presentConversationPicker()
        }
        
        return [modelConfig, conversationConfig].compactMap { $0 }
    }
    
    // MARK: - Helper Methods
    
    private func updateCharacterCount() {
        let count = contentText.count
        let hasOtherContent = !shareContext.images.isEmpty || !shareContext.files.isEmpty || !shareContext.urls.isEmpty
        
        if count > 0 || hasOtherContent {
            charactersRemaining = max(0, 2000 - count) // Set reasonable limit
        }
    }
    
    private func getModelDisplayName(_ modelId: String) -> String {
        switch modelId {
        case "anthropic/claude-3.5-sonnet":
            return "Claude 3.5 Sonnet"
        case "openai/gpt-4o":
            return "GPT-4o"
        case "anthropic/claude-3-haiku":
            return "Claude 3 Haiku"
        case "openai/gpt-3.5-turbo":
            return "GPT-3.5 Turbo"
        case "google/gemini-pro":
            return "Gemini Pro"
        default:
            return "Default Model"
        }
    }
    
    private func getMimeType(for url: URL) -> String? {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            return nil
        }
    }
    
    private func loadUserPreferences() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.llmchat.shared") {
            selectedModel = sharedDefaults.string(forKey: "lastUsedModel") ?? "anthropic/claude-3.5-sonnet"
        }
    }
    
    private func saveSharedContent() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.llmchat.shared") else {
            return
        }
        
        // Save the shared content
        do {
            let data = try JSONEncoder().encode(shareContext)
            sharedDefaults.set(data, forKey: "pendingShare")
            sharedDefaults.set(selectedModel, forKey: "lastUsedModel")
            sharedDefaults.set(Date(), forKey: "shareTimestamp")
        } catch {
            print("Failed to save shared content: \(error)")
        }
    }
    
    private func loadRecentConversations() -> [SharedConversation] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.llmchat.shared"),
              let data = sharedDefaults.data(forKey: "recentConversations") else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([SharedConversation].self, from: data)
        } catch {
            print("Failed to load recent conversations: \(error)")
            return []
        }
    }
    
    private func openMainApp() {
        let url = URL(string: "llmchat://share")!
        
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }
        
        // Fallback: try with extension context
        extensionContext?.open(url, completionHandler: nil)
    }
}

// MARK: - Supporting Types
// ShareContext models are now imported from LLMChat module