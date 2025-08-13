import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    
    let conversation: Conversation
    
    @State private var messageText = ""
    @State private var showingModelPicker = false
    @State private var isGenerating = false
    
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
                    onSend: sendMessage,
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
        .onAppear {
            markMessagesAsRead()
        }
    }
    
    private var modelDisplayName: String {
        conversation.modelId.components(separatedBy: "/").last?.capitalized ?? conversation.modelId
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(
            role: .user,
            text: messageText,
            conversation: conversation
        )
        
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
        messageText = ""
        isGenerating = true
        
        Task {
            await generateResponse(userMessage: messageTextToSend, assistantMessage: assistantMessage)
        }
    }
    
    @MainActor
    private func generateResponse(userMessage: String, assistantMessage: Message) async {
        guard let apiKey = appState.currentAPIKey else {
            assistantMessage.text = "Error: No API key found"
            assistantMessage.state = .error
            isGenerating = false
            try? modelContext.save()
            return
        }
        
        let messages = conversation.messages
            .filter { $0.state == .complete }
            .map { message in
                ChatMessage(role: message.role.rawValue, text: message.text)
            }
        
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
                try? modelContext.save()
            },
            onError: { error in
                assistantMessage.text = "Error: \(error.localizedDescription)"
                assistantMessage.state = .error
                isGenerating = false
                try? modelContext.save()
            }
        )
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
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.text)
                .padding(12)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
            
            Text(message.createdAt, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
    }
}

struct AssistantMessageBubble: View {
    let message: Message
    
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
                    
                    if message.state == .streaming {
                        TypingIndicatorView()
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
    let onSend: () -> Void
    let onModelSelect: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Button(action: onModelSelect) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
            }
            
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...6)
                .disabled(isGenerating)
            
            Button(action: onSend) {
                Image(systemName: isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend && !isGenerating)
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// Helper extension for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
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