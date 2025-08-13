import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var searchService = SearchService.shared
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var showingExportOptions = false
    @State private var selectedResults: Set<UUID> = []
    @State private var isSelectionMode = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBarView(
                    text: $searchText,
                    onSearchChanged: { query in
                        Task {
                            await searchService.search(query)
                        }
                    },
                    onFiltersPressed: {
                        showingFilters = true
                    }
                )
                
                // Search suggestions (when typing)
                if !searchText.isEmpty && searchService.searchResults.isEmpty && !searchService.isSearching {
                    SearchSuggestionsView(
                        query: searchText,
                        suggestions: searchService.getSuggestions(for: searchText),
                        history: searchService.searchHistory,
                        onSuggestionSelected: { suggestion in
                            searchText = suggestion
                            Task {
                                await searchService.search(suggestion)
                            }
                        }
                    )
                }
                
                // Results
                if searchService.isSearching {
                    SearchLoadingView()
                } else if !searchService.searchResults.isEmpty {
                    SearchResultsView(
                        results: searchService.searchResults,
                        selectedResults: $selectedResults,
                        isSelectionMode: $isSelectionMode
                    )
                } else if !searchText.isEmpty {
                    SearchEmptyView(query: searchText)
                } else {
                    SearchWelcomeView()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !searchService.searchResults.isEmpty {
                        if isSelectionMode {
                            Button("Export Selected") {
                                showingExportOptions = true
                            }
                            .disabled(selectedResults.isEmpty)
                            
                            Button("Cancel") {
                                isSelectionMode = false
                                selectedResults.removeAll()
                            }
                        } else {
                            Button("Select") {
                                isSelectionMode = true
                            }
                            
                            Button("Export All") {
                                showingExportOptions = true
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            searchService.configure(with: modelContext)
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchService.searchFilters)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                conversations: getConversationsToExport(),
                onExport: { format, options in
                    Task {
                        await exportConversations(format: format, options: options)
                    }
                }
            )
        }
    }
    
    private func getConversationsToExport() -> [Conversation] {
        let results = isSelectionMode && !selectedResults.isEmpty ?
            searchService.searchResults.filter { selectedResults.contains($0.id) } :
            searchService.searchResults
        
        let conversations = Set(results.compactMap(\.conversation))
        return Array(conversations)
    }
    
    private func exportConversations(format: ExportService.ExportFormat, options: ExportService.ExportOptions) async {
        let conversations = getConversationsToExport()
        
        do {
            let result = try await ExportService.shared.exportMultipleConversations(
                conversations,
                format: format,
                options: options
            )
            
            await MainActor.run {
                ExportService.shared.shareExport(result)
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
}

// MARK: - Search Bar

struct SearchBarView: View {
    @Binding var text: String
    let onSearchChanged: (String) -> Void
    let onFiltersPressed: () -> Void
    
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search conversations...", text: $text)
                    .focused($isFocused)
                    .onSubmit {
                        onSearchChanged(text)
                    }
                    .onChange(of: text) { _, newValue in
                        if newValue.isEmpty {
                            onSearchChanged("")
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onSearchChanged("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Button(action: onFiltersPressed) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .onTapGesture {
            isFocused = true
        }
    }
}

// MARK: - Search Suggestions

struct SearchSuggestionsView: View {
    let query: String
    let suggestions: [String]
    let history: [String]
    let onSuggestionSelected: (String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestions, id: \.self) { suggestion in
                            SuggestionRowView(
                                suggestion: suggestion,
                                query: query,
                                icon: "lightbulb",
                                onTap: { onSuggestionSelected(suggestion) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                if !history.isEmpty {
                    Section("Recent Searches") {
                        ForEach(Array(history.prefix(5)), id: \.self) { historyItem in
                            SuggestionRowView(
                                suggestion: historyItem,
                                query: query,
                                icon: "clock",
                                onTap: { onSuggestionSelected(historyItem) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct SuggestionRowView: View {
    let suggestion: String
    let query: String
    let icon: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Text(suggestion)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Results

struct SearchResultsView: View {
    let results: [SearchResult]
    @Binding var selectedResults: Set<UUID>
    @Binding var isSelectionMode: Bool
    
    var body: some View {
        List {
            ForEach(results) { result in
                SearchResultRowView(
                    result: result,
                    isSelected: selectedResults.contains(result.id),
                    isSelectionMode: isSelectionMode,
                    onToggleSelection: {
                        if selectedResults.contains(result.id) {
                            selectedResults.remove(result.id)
                        } else {
                            selectedResults.insert(result.id)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }
}

struct SearchResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: () -> Void
    
    private var typeIcon: String {
        switch result.type {
        case .conversation: return "bubble.left.and.bubble.right"
        case .message: return "message"
        case .attachment: return "paperclip"
        }
    }
    
    private var typeColor: Color {
        switch result.type {
        case .conversation: return .blue
        case .message: return .green
        case .attachment: return .orange
        }
    }
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: typeIcon)
                        .foregroundColor(typeColor)
                        .font(.caption)
                    
                    Text(result.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(result.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(result.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(result.snippet)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(.vertical, 4)
        }
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            } else {
                navigateToResult()
            }
        }
    }
    
    private func navigateToResult() {
        // Implementation would navigate to the specific conversation/message
        print("Navigate to result: \(result.title)")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Search States

struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchEmptyView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("No conversations or messages match '\(query)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Try:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• Different keywords")
                Text("• Shorter search terms")
                Text("• Checking your filters")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchWelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Search Your Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Find messages, conversations, and attachments quickly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                SearchTipView(
                    icon: "text.quote",
                    title: "Search text",
                    description: "Find specific words or phrases"
                )
                
                SearchTipView(
                    icon: "person.circle",
                    title: "Filter by role",
                    description: "Use 'from:user' or 'from:assistant'"
                )
                
                SearchTipView(
                    icon: "calendar",
                    title: "Filter by date",
                    description: "Use 'after:2024-01-01' or 'before:2024-12-31'"
                )
                
                SearchTipView(
                    icon: "doc.text",
                    title: "Search types",
                    description: "Use 'type:message', 'type:conversation', or 'type:attachment'"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchTipView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Extensions

extension SearchResultType {
    var displayName: String {
        switch self {
        case .conversation: return "Conversation"
        case .message: return "Message"
        case .attachment: return "Attachment"
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [
            Conversation.self,
            Message.self,
            Attachment.self
        ])
}