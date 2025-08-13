import SwiftUI
import SwiftData

struct ChatsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    
    @Query(
        filter: #Predicate<Conversation> { !$0.isArchived },
        sort: [
            SortDescriptor(\Conversation.isPinned, order: .reverse),
            SortDescriptor(\Conversation.updatedAt, order: .reverse)
        ]
    ) private var conversations: [Conversation]
    
    @State private var showingNewChat = false
    @State private var showingSettings = false
    @State private var searchText = ""
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                conversation.messages.contains { message in
                    message.text.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredConversations.isEmpty {
                    EmptyStateView()
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredConversations) { conversation in
                        NavigationLink(destination: ChatView(conversation: conversation)) {
                            ConversationRowView(conversation: conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                deleteConversation(conversation)
                            }
                            
                            Button(conversation.isPinned ? "Unpin" : "Pin") {
                                togglePin(conversation)
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(appState)
            }
        }
    }
    
    private func createNewChat() {
        let conversation = Conversation()
        modelContext.insert(conversation)
        try? modelContext.save()
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
    
    private func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        conversation.updatedAt = Date()
        try? modelContext.save()
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Text(conversation.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(conversation.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                if conversation.unreadCount > 0 {
                    Badge(count: conversation.unreadCount)
                }
            }
            
            // Model indicator
            Text(conversation.modelId)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct Badge: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue)
            .cornerRadius(10)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No conversations yet")
                    .font(.headline)
                
                Text("Tap the compose button to start your first chat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        ChatsListView()
            .environmentObject(AppState())
    }
    .modelContainer(for: [
        Conversation.self,
        Message.self,
        Attachment.self,
        ModelInfo.self
    ])
}