import Foundation
import SwiftData

@Observable
class SearchService {
    static let shared = SearchService()
    
    private var modelContext: ModelContext?
    
    // Search state
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var isSearching: Bool = false
    var searchFilters: SearchFilters = SearchFilters()
    var searchHistory: [String] = []
    
    private let maxSearchHistoryCount = 20
    
    init() {
        loadSearchHistory()
    }
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Search Methods
    
    func search(_ query: String, filters: SearchFilters? = nil) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
            searchQuery = query
        }
        
        // Add to search history
        await MainActor.run {
            addToSearchHistory(query)
        }
        
        let results = await performSearch(query: query, filters: filters ?? searchFilters)
        
        await MainActor.run {
            searchResults = results
            isSearching = false
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }
    
    private func performSearch(query: String, filters: SearchFilters) async -> [SearchResult] {
        guard let modelContext = modelContext else { return [] }
        
        let searchTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        do {
            // Fetch all conversations and messages
            let conversationDescriptor = FetchDescriptor<Conversation>()
            let messageDescriptor = FetchDescriptor<Message>()
            
            let conversations = try modelContext.fetch(conversationDescriptor)
            let messages = try modelContext.fetch(messageDescriptor)
            
            var results: [SearchResult] = []
            
            // Search in conversation titles
            if filters.includeConversations {
                for conversation in conversations {
                    if searchMatches(text: conversation.title, terms: searchTerms) {
                        let result = SearchResult(
                            id: conversation.id,
                            type: .conversation,
                            title: conversation.title,
                            content: conversation.title,
                            snippet: generateSnippet(from: conversation.title, searchTerms: searchTerms),
                            conversation: conversation,
                            message: nil,
                            timestamp: conversation.updatedAt,
                            matchScore: calculateMatchScore(text: conversation.title, terms: searchTerms)
                        )
                        results.append(result)
                    }
                }
            }
            
            // Search in message content
            if filters.includeMessages {
                for message in messages {
                    if shouldIncludeMessage(message, filters: filters) &&
                       searchMatches(text: message.text, terms: searchTerms) {
                        
                        let result = SearchResult(
                            id: message.id,
                            type: .message,
                            title: message.conversation?.title ?? "Unknown Conversation",
                            content: message.text,
                            snippet: generateSnippet(from: message.text, searchTerms: searchTerms),
                            conversation: message.conversation,
                            message: message,
                            timestamp: message.createdAt,
                            matchScore: calculateMatchScore(text: message.text, terms: searchTerms)
                        )
                        results.append(result)
                    }
                }
            }
            
            // Search in attachment content (transcriptions, filenames)
            if filters.includeAttachments {
                for message in messages {
                    for attachment in message.attachments {
                        var searchableText = ""
                        
                        if let filename = attachment.originalFilename {
                            searchableText += filename + " "
                        }
                        
                        if let transcription = attachment.transcription {
                            searchableText += transcription + " "
                        }
                        
                        if !searchableText.isEmpty && searchMatches(text: searchableText, terms: searchTerms) {
                            let result = SearchResult(
                                id: attachment.id,
                                type: .attachment,
                                title: attachment.originalFilename ?? "Attachment",
                                content: searchableText,
                                snippet: generateSnippet(from: searchableText, searchTerms: searchTerms),
                                conversation: message.conversation,
                                message: message,
                                timestamp: attachment.createdAt,
                                matchScore: calculateMatchScore(text: searchableText, terms: searchTerms)
                            )
                            results.append(result)
                        }
                    }
                }
            }
            
            // Apply date filters
            if let startDate = filters.startDate {
                results = results.filter { $0.timestamp >= startDate }
            }
            
            if let endDate = filters.endDate {
                results = results.filter { $0.timestamp <= endDate }
            }
            
            // Sort by relevance and date
            results.sort { lhs, rhs in
                if lhs.matchScore == rhs.matchScore {
                    return lhs.timestamp > rhs.timestamp
                }
                return lhs.matchScore > rhs.matchScore
            }
            
            // Limit results
            return Array(results.prefix(filters.maxResults))
            
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func searchMatches(text: String, terms: [String]) -> Bool {
        let lowercasedText = text.lowercased()
        return terms.allSatisfy { term in
            lowercasedText.contains(term)
        }
    }
    
    private func shouldIncludeMessage(_ message: Message, filters: SearchFilters) -> Bool {
        if !filters.roles.isEmpty && !filters.roles.contains(message.role) {
            return false
        }
        
        if !filters.states.isEmpty && !filters.states.contains(message.state) {
            return false
        }
        
        return true
    }
    
    private func calculateMatchScore(text: String, terms: [String]) -> Double {
        let lowercasedText = text.lowercased()
        var score: Double = 0
        
        for term in terms {
            // Exact phrase bonus
            if lowercasedText.contains(term) {
                score += 10
            }
            
            // Word boundary bonus
            let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines)
            if words.contains(term) {
                score += 20
            }
            
            // Beginning of text bonus
            if lowercasedText.hasPrefix(term) {
                score += 15
            }
        }
        
        // Length penalty (shorter texts with matches are more relevant)
        score *= (1000.0 / max(text.count, 100))
        
        return score
    }
    
    private func generateSnippet(from text: String, searchTerms: [String], maxLength: Int = 150) -> String {
        let lowercasedText = text.lowercased()
        
        // Find the first occurrence of any search term
        var bestRange: Range<String.Index>?
        var bestTerm = ""
        
        for term in searchTerms {
            if let range = lowercasedText.range(of: term) {
                if bestRange == nil || range.lowerBound < bestRange!.lowerBound {
                    bestRange = range
                    bestTerm = term
                }
            }
        }
        
        guard let range = bestRange else {
            return String(text.prefix(maxLength)) + (text.count > maxLength ? "..." : "")
        }
        
        // Calculate snippet bounds
        let termStart = range.lowerBound
        let termEnd = range.upperBound
        
        let contextLength = (maxLength - bestTerm.count) / 2
        
        let snippetStart = text.index(termStart, offsetBy: -min(contextLength, text.distance(from: text.startIndex, to: termStart)))
        let snippetEnd = text.index(termEnd, offsetBy: min(contextLength, text.distance(from: termEnd, to: text.endIndex)))
        
        var snippet = String(text[snippetStart..<snippetEnd])
        
        // Add ellipsis if needed
        if snippetStart > text.startIndex {
            snippet = "..." + snippet
        }
        if snippetEnd < text.endIndex {
            snippet = snippet + "..."
        }
        
        return snippet
    }
    
    // MARK: - Search History
    
    private func addToSearchHistory(_ query: String) {
        // Remove if already exists
        searchHistory.removeAll { $0 == query }
        
        // Add to beginning
        searchHistory.insert(query, at: 0)
        
        // Limit history size
        if searchHistory.count > maxSearchHistoryCount {
            searchHistory.removeLast()
        }
        
        saveSearchHistory()
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "SearchHistory")
    }
    
    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "SearchHistory") ?? []
    }
    
    // MARK: - Suggestions
    
    func getSuggestions(for query: String) -> [String] {
        let lowercasedQuery = query.lowercased()
        
        var suggestions: [String] = []
        
        // Add from search history
        suggestions.append(contentsOf: searchHistory.filter { 
            $0.lowercased().contains(lowercasedQuery) && $0 != query 
        })
        
        // Add common search terms
        let commonTerms = ["error", "code", "help", "how to", "what is", "explain", "example"]
        suggestions.append(contentsOf: commonTerms.filter { 
            $0.lowercased().contains(lowercasedQuery) && !suggestions.contains($0)
        })
        
        return Array(suggestions.prefix(5))
    }
}

// MARK: - Search Data Models

struct SearchResult: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let content: String
    let snippet: String
    let conversation: Conversation?
    let message: Message?
    let timestamp: Date
    let matchScore: Double
}

enum SearchResultType {
    case conversation
    case message
    case attachment
}

struct SearchFilters {
    var includeConversations: Bool = true
    var includeMessages: Bool = true
    var includeAttachments: Bool = true
    var roles: Set<MessageRole> = []
    var states: Set<MessageState> = []
    var startDate: Date?
    var endDate: Date?
    var maxResults: Int = 100
    
    var isDefault: Bool {
        return includeConversations && includeMessages && includeAttachments && 
               roles.isEmpty && states.isEmpty && 
               startDate == nil && endDate == nil && 
               maxResults == 100
    }
}

// MARK: - Advanced Search Query Parser

struct SearchQueryParser {
    static func parse(_ query: String) -> ParsedSearchQuery {
        var parsedQuery = ParsedSearchQuery()
        var remainingQuery = query
        
        // Parse special operators
        let patterns: [(String, (String, inout ParsedSearchQuery) -> Void)] = [
            (#"from:(\w+)"#, { match, query in
                if let role = MessageRole(rawValue: String(match.dropFirst(5))) {
                    query.roles.insert(role)
                }
            }),
            (#"before:(\d{4}-\d{2}-\d{2})"#, { match, query in
                let dateString = String(match.dropFirst(7))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                query.endDate = formatter.date(from: dateString)
            }),
            (#"after:(\d{4}-\d{2}-\d{2})"#, { match, query in
                let dateString = String(match.dropFirst(6))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                query.startDate = formatter.date(from: dateString)
            }),
            (#"type:(conversation|message|attachment)"#, { match, query in
                let type = String(match.dropFirst(5))
                switch type {
                case "conversation":
                    query.includeMessages = false
                    query.includeAttachments = false
                case "message":
                    query.includeConversations = false
                    query.includeAttachments = false
                case "attachment":
                    query.includeConversations = false
                    query.includeMessages = false
                default:
                    break
                }
            })
        ]
        
        for (pattern, handler) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: remainingQuery, range: NSRange(remainingQuery.startIndex..., in: remainingQuery))
                
                for match in matches.reversed() {
                    if let range = Range(match.range, in: remainingQuery) {
                        let matchText = String(remainingQuery[range])
                        handler(matchText, &parsedQuery)
                        remainingQuery.removeSubrange(range)
                    }
                }
            }
        }
        
        // Clean up remaining query
        parsedQuery.terms = remainingQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        return parsedQuery
    }
}

struct ParsedSearchQuery {
    var terms: [String] = []
    var roles: Set<MessageRole> = []
    var startDate: Date?
    var endDate: Date?
    var includeConversations: Bool = true
    var includeMessages: Bool = true
    var includeAttachments: Bool = true
}

extension MessageRole: CaseIterable {}
extension MessageState: CaseIterable {}