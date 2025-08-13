import SwiftUI
import SwiftData

// MARK: - Message Reactions View

struct MessageReactionsView: View {
    let message: Message
    @Environment(\.modelContext) private var modelContext
    @State private var showingReactionPicker = false
    
    private let commonEmojis = ["👍", "👎", "❤️", "😂", "😮", "😢", "😡", "🎉"]
    
    var body: some View {
        if !message.reactions.isEmpty || showingReactionPicker {
            HStack(spacing: 8) {
                // Existing reactions
                ForEach(uniqueReactions, id: \.emoji) { reaction in
                    ReactionButton(
                        emoji: reaction.emoji,
                        count: reactionCount(for: reaction.emoji),
                        isSelected: hasUserReacted(to: reaction.emoji),
                        onTap: {
                            toggleReaction(reaction.emoji)
                        }
                    )
                }
                
                // Add reaction button
                Button(action: {
                    showingReactionPicker = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 4)
            .popover(isPresented: $showingReactionPicker) {
                ReactionPickerView(onReactionSelected: { emoji in
                    addReaction(emoji)
                    showingReactionPicker = false
                })
                .presentationCompactAdaptation(.popover)
            }
        }
    }
    
    private var uniqueReactions: [MessageReaction] {
        let uniqueEmojis = Set(message.reactions.map(\.emoji))
        return uniqueEmojis.compactMap { emoji in
            message.reactions.first { $0.emoji == emoji }
        }
    }
    
    private func reactionCount(for emoji: String) -> Int {
        return message.reactions.filter { $0.emoji == emoji }.count
    }
    
    private func hasUserReacted(to emoji: String) -> Bool {
        // For now, assume single user. In multi-user, check userId
        return message.reactions.contains { $0.emoji == emoji && $0.userId == nil }
    }
    
    private func toggleReaction(_ emoji: String) {
        if hasUserReacted(to: emoji) {
            removeReaction(emoji)
        } else {
            addReaction(emoji)
        }
    }
    
    private func addReaction(_ emoji: String) {
        let reaction = MessageReaction(emoji: emoji)
        message.reactions.append(reaction)
        try? modelContext.save()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func removeReaction(_ emoji: String) {
        if let index = message.reactions.firstIndex(where: { $0.emoji == emoji && $0.userId == nil }) {
            message.reactions.remove(at: index)
            try? modelContext.save()
        }
    }
}

// MARK: - Reaction Button

struct ReactionButton: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                
                if count > 1 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reaction Picker

struct ReactionPickerView: View {
    let onReactionSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let emojiCategories: [(String, [String])] = [
        ("Smileys", ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳"]),
        ("Emotions", ["😭", "😢", "😥", "😰", "😨", "😧", "😦", "😮", "😯", "😲", "🥺", "😳", "🥵", "🥶", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱", "😴", "😪", "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕"]),
        ("Gestures", ["👍", "👎", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👋", "🤚", "🖐", "✋", "🖖", "👏", "🙌", "🤲", "🤝", "🙏"]),
        ("Hearts", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟"]),
        ("Symbols", ["💯", "💢", "💥", "💫", "💦", "💨", "🕳", "💬", "👁‍🗨", "🗨", "🗯", "💭", "💤", "👋", "🔥", "⭐", "✨", "💎", "🎉", "🎊"])
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(emojiCategories, id: \.0) { category, emojis in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 40)), count: 8), spacing: 8) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button(action: {
                                        onReactionSelected(emoji)
                                    }) {
                                        Text(emoji)
                                            .font(.title2)
                                            .frame(width: 40, height: 40)
                                            .background(Color(.systemGray6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Add Reaction")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Rich Text Formatting

struct FormattedTextView: View {
    let text: String
    let isMarkdownEnabled: Bool
    
    init(_ text: String, enableMarkdown: Bool = true) {
        self.text = text
        self.isMarkdownEnabled = enableMarkdown
    }
    
    var body: some View {
        if isMarkdownEnabled {
            MarkdownFormattedText(text)
        } else {
            Text(text)
        }
    }
}

struct MarkdownFormattedText: View {
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(content), id: \.id) { element in
                element.view
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("# ") {
                elements.append(.heading1(String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                elements.append(.heading2(String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                elements.append(.heading3(String(line.dropFirst(4))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                elements.append(.bulletPoint(String(line.dropFirst(2))))
            } else if line.hasPrefix("> ") {
                elements.append(.quote(String(line.dropFirst(2))))
            } else if line.hasPrefix("```") {
                // Handle code blocks (simplified)
                elements.append(.codeBlock(line))
            } else if !line.isEmpty {
                elements.append(.paragraph(formatInlineMarkdown(line)))
            } else {
                elements.append(.spacing)
            }
        }
        
        return elements
    }
    
    private func formatInlineMarkdown(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        // Bold **text**
        let boldPattern = #"\*\*(.*?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let boldText = String(text[range])
                    let content = String(boldText.dropFirst(2).dropLast(2))
                    attributed.characters[range].font = .boldSystemFont(ofSize: 16)
                }
            }
        }
        
        // Italic *text*
        let italicPattern = #"\*(.*?)\*"#
        if let regex = try? NSRegularExpression(pattern: italicPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    attributed.characters[range].font = .italicSystemFont(ofSize: 16)
                }
            }
        }
        
        // Code `text`
        let codePattern = #"`(.*?)`"#
        if let regex = try? NSRegularExpression(pattern: codePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    attributed.characters[range].font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                    attributed.characters[range].backgroundColor = UIColor.systemGray6
                }
            }
        }
        
        return attributed
    }
}

// MARK: - Markdown Elements

enum MarkdownElement: Identifiable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case paragraph(AttributedString)
    case bulletPoint(String)
    case quote(String)
    case codeBlock(String)
    case spacing
    
    var id: String {
        switch self {
        case .heading1(let text): return "h1-\(text)"
        case .heading2(let text): return "h2-\(text)"
        case .heading3(let text): return "h3-\(text)"
        case .paragraph(let text): return "p-\(text.description)"
        case .bulletPoint(let text): return "bullet-\(text)"
        case .quote(let text): return "quote-\(text)"
        case .codeBlock(let text): return "code-\(text)"
        case .spacing: return "spacing-\(UUID())"
        }
    }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .heading1(let text):
            Text(text)
                .font(.title)
                .fontWeight(.bold)
                .padding(.vertical, 4)
        case .heading2(let text):
            Text(text)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.vertical, 3)
        case .heading3(let text):
            Text(text)
                .font(.title3)
                .fontWeight(.medium)
                .padding(.vertical, 2)
        case .paragraph(let text):
            Text(text)
                .font(.body)
        case .bulletPoint(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .foregroundColor(.secondary)
                Text(text)
                    .font(.body)
                Spacer()
            }
        case .quote(let text):
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.body)
                        .italic()
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        case .codeBlock(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .spacing:
            Spacer()
                .frame(height: 8)
        }
    }
}

// MARK: - Message Actions Menu

struct MessageActionsView: View {
    let message: Message
    @Environment(\.modelContext) private var modelContext
    @State private var showingReactionPicker = false
    @State private var showingCopyConfirmation = false
    
    var body: some View {
        Menu {
            Button(action: {
                showingReactionPicker = true
            }) {
                Label("Add Reaction", systemImage: "face.smiling")
            }
            
            Button(action: copyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button(action: shareMessage) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            if message.role == .user {
                Button(action: editMessage) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: deleteMessage) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
        .popover(isPresented: $showingReactionPicker) {
            ReactionPickerView(onReactionSelected: { emoji in
                addReaction(emoji)
                showingReactionPicker = false
            })
        }
        .overlay(
            Group {
                if showingCopyConfirmation {
                    Text("Copied!")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .offset(y: -30)
                        .transition(.opacity)
                }
            }
        )
    }
    
    private func addReaction(_ emoji: String) {
        let reaction = MessageReaction(emoji: emoji)
        message.reactions.append(reaction)
        try? modelContext.save()
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.text
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showingCopyConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingCopyConfirmation = false
            }
        }
    }
    
    private func shareMessage() {
        let activityVC = UIActivityViewController(activityItems: [message.text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func editMessage() {
        // This would typically open an edit interface
        // For now, we'll just mark it as editable
        print("Edit message: \(message.text)")
    }
    
    private func deleteMessage() {
        message.conversation?.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        try? modelContext.save()
    }
}

#Preview {
    VStack {
        MessageReactionsView(message: Message(role: .assistant, text: "Hello world!"))
        
        Divider()
        
        FormattedTextView("This is **bold** and *italic* text with `code` formatting.")
        
        Divider()
        
        MessageActionsView(message: Message(role: .user, text: "Sample message"))
    }
    .padding()
}