import Foundation
import SwiftUI
import Combine

@MainActor
class SearchModelConfigurationService: ObservableObject {
    static let shared = SearchModelConfigurationService()
    
    @Published var availableSearchModels: [SearchModelConfiguration] = []
    @Published var currentSearchModel: SearchModelConfiguration?
    @Published var modelPerformanceMetrics: [String: ModelPerformanceMetrics] = [:]
    @Published var isLoadingMetrics = false
    @Published var lastMetricsUpdate: Date?
    
    // Smart selection settings
    @Published var enableSmartModelSelection = true
    @Published var preferSpeedOverQuality = false
    @Published var autoSwitchBasedOnContent = true
    
    private let networkService = OpenRouterAPI.shared
    private let metricsUpdateInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {
        setupDefaultSearchModels()
        loadPerformanceMetrics()
        loadSettings()
    }
    
    // MARK: - Model Configuration
    
    private func setupDefaultSearchModels() {
        availableSearchModels = [
            SearchModelConfiguration(
                id: "anthropic/claude-3-haiku",
                name: "Claude 3 Haiku",
                provider: "Anthropic",
                description: "Ultra-fast responses, optimized for search",
                contextWindow: 200_000,
                pricePerMillion: 0.25,
                strengths: [.speed, .efficiency, .lowCost],
                bestFor: [.quickSearch, .keywordMatching, .basicQuestions],
                averageResponseTime: 0.8,
                qualityScore: 0.85,
                isRecommendedForSearch: true
            ),
            
            SearchModelConfiguration(
                id: "anthropic/claude-3.5-sonnet",
                name: "Claude 3.5 Sonnet",
                provider: "Anthropic",
                description: "Balanced performance and intelligence",
                contextWindow: 200_000,
                pricePerMillion: 3.0,
                strengths: [.reasoning, .analysis, .accuracy],
                bestFor: [.complexSearch, .semanticAnalysis, .contentSummary],
                averageResponseTime: 1.5,
                qualityScore: 0.95,
                isRecommendedForSearch: false
            ),
            
            SearchModelConfiguration(
                id: "openai/gpt-4o-mini",
                name: "GPT-4o Mini",
                provider: "OpenAI",
                description: "Efficient and capable",
                contextWindow: 128_000,
                pricePerMillion: 0.15,
                strengths: [.speed, .efficiency, .multimodal],
                bestFor: [.quickSearch, .imageSearch, .generalQueries],
                averageResponseTime: 1.0,
                qualityScore: 0.88,
                isRecommendedForSearch: true
            ),
            
            SearchModelConfiguration(
                id: "google/gemini-pro",
                name: "Gemini Pro",
                provider: "Google",
                description: "Advanced reasoning and multimodal",
                contextWindow: 1_000_000,
                pricePerMillion: 2.5,
                strengths: [.multimodal, .reasoning, .largeContext],
                bestFor: [.complexSearch, .documentAnalysis, .multiModalSearch],
                averageResponseTime: 2.0,
                qualityScore: 0.92,
                isRecommendedForSearch: false
            ),
            
            SearchModelConfiguration(
                id: "meta-llama/llama-3.1-8b-instruct",
                name: "Llama 3.1 8B",
                provider: "Meta",
                description: "Open-source efficiency",
                contextWindow: 128_000,
                pricePerMillion: 0.18,
                strengths: [.speed, .openSource, .lowCost],
                bestFor: [.basicSearch, .keywordMatching, .generalQueries],
                averageResponseTime: 0.6,
                qualityScore: 0.80,
                isRecommendedForSearch: false
            )
        ]
        
        // Set default current model
        currentSearchModel = availableSearchModels.first { $0.isRecommendedForSearch }
    }
    
    // MARK: - Smart Model Selection
    
    func selectOptimalModelForSearch(
        query: String,
        contentType: SearchContentType,
        prioritizeSpeed: Bool = false
    ) -> SearchModelConfiguration {
        
        guard enableSmartModelSelection else {
            return currentSearchModel ?? availableSearchModels.first ?? defaultSearchModels.first!
        }
        
        let candidates = availableSearchModels.filter { model in
            switch contentType {
            case .text:
                return true
            case .images:
                return model.strengths.contains(.multimodal)
            case .documents:
                return model.strengths.contains(.largeContext) || model.contextWindow >= 100_000
            case .code:
                return model.strengths.contains(.reasoning)
            case .mixed:
                return model.strengths.contains(.multimodal) || model.qualityScore >= 0.90
            }
        }
        
        let scoredCandidates = candidates.map { model in
            (model, calculateModelScore(model, for: query, contentType: contentType, prioritizeSpeed: prioritizeSpeed))
        }.sorted { $0.1 > $1.1 }
        
        return scoredCandidates.first?.0 ?? currentSearchModel ?? availableSearchModels.first ?? defaultSearchModels.first!
    }
    
    private func calculateModelScore(
        _ model: SearchModelConfiguration,
        for query: String,
        contentType: SearchContentType,
        prioritizeSpeed: Bool
    ) -> Double {
        var score = model.qualityScore
        
        // Speed factor
        let speedScore = 1.0 / max(model.averageResponseTime, 0.1)
        let speedWeight = prioritizeSpeed ? 0.4 : 0.2
        score += speedScore * speedWeight
        
        // Cost factor
        let costScore = 1.0 / max(model.pricePerMillion, 0.01)
        score += costScore * 0.1
        
        // Content type alignment
        let contentAlignment = calculateContentTypeAlignment(model, contentType: contentType)
        score += contentAlignment * 0.3
        
        // Query complexity factor
        let complexity = estimateQueryComplexity(query)
        if complexity > 0.7 && model.strengths.contains(.reasoning) {
            score += 0.2
        }
        
        // Performance metrics factor
        if let metrics = modelPerformanceMetrics[model.id] {
            let performanceScore = (metrics.averageAccuracy + metrics.averageSpeed + metrics.averageReliability) / 3
            score += performanceScore * 0.2
        }
        
        return score
    }
    
    private func calculateContentTypeAlignment(_ model: SearchModelConfiguration, contentType: SearchContentType) -> Double {
        switch contentType {
        case .text:
            return model.bestFor.contains(.quickSearch) ? 1.0 : 0.8
        case .images:
            return model.strengths.contains(.multimodal) ? 1.0 : 0.3
        case .documents:
            return model.bestFor.contains(.documentAnalysis) ? 1.0 : 0.7
        case .code:
            return model.strengths.contains(.reasoning) ? 1.0 : 0.6
        case .mixed:
            return model.strengths.contains(.multimodal) ? 1.0 : 0.5
        }
    }
    
    private func estimateQueryComplexity(_ query: String) -> Double {
        let wordCount = query.split(separator: " ").count
        let hasQuestions = query.contains("?")
        let hasComplexWords = query.lowercased().contains("analyze") || 
                             query.lowercased().contains("compare") ||
                             query.lowercased().contains("explain") ||
                             query.lowercased().contains("why") ||
                             query.lowercased().contains("how")
        
        var complexity = Double(wordCount) / 50.0 // Normalize by word count
        
        if hasQuestions { complexity += 0.2 }
        if hasComplexWords { complexity += 0.3 }
        
        return min(complexity, 1.0)
    }
    
    // MARK: - Performance Metrics
    
    func updatePerformanceMetrics() async {
        guard !isLoadingMetrics else { return }
        
        isLoadingMetrics = true
        
        do {
            // Fetch latest model information from API
            let apiKey = try KeychainService.shared.getAPIKey()
            let models = try await networkService.fetchModels(apiKey: apiKey)
            
            // Update our configurations with latest data
            await updateModelConfigurations(with: models)
            
            // Run performance tests on a subset of models
            await runPerformanceBenchmarks()
            
            lastMetricsUpdate = Date()
            savePerformanceMetrics()
            
        } catch {
            print("Failed to update performance metrics: \(error)")
        }
        
        isLoadingMetrics = false
    }
    
    private func updateModelConfigurations(with apiModels: [OpenRouterModel]) async {
        for i in 0..<availableSearchModels.count {
            if let apiModel = apiModels.first(where: { $0.id == availableSearchModels[i].id }) {
                availableSearchModels[i].pricePerMillion = apiModel.pricing.prompt * 1_000_000
                availableSearchModels[i].contextWindow = apiModel.context_length
            }
        }
    }
    
    private func runPerformanceBenchmarks() async {
        let testQueries = [
            "What is artificial intelligence?",
            "Explain quantum computing in simple terms",
            "Compare React and Vue.js frameworks",
            "Analyze the causes of climate change"
        ]
        
        for model in availableSearchModels.prefix(3) { // Test top 3 models
            var totalTime: TimeInterval = 0
            var successCount = 0
            
            for query in testQueries {
                do {
                    let startTime = Date()
                    // Here you would make an actual API call to test the model
                    // For now, we'll simulate with a delay based on model characteristics
                    try await Task.sleep(nanoseconds: UInt64(model.averageResponseTime * 1_000_000_000))
                    totalTime += Date().timeIntervalSince(startTime)
                    successCount += 1
                } catch {
                    print("Benchmark failed for model \(model.id): \(error)")
                }
            }
            
            let averageTime = totalTime / Double(testQueries.count)
            let reliability = Double(successCount) / Double(testQueries.count)
            let speed = 1.0 / max(averageTime, 0.1) // Normalize speed score
            
            modelPerformanceMetrics[model.id] = ModelPerformanceMetrics(
                averageResponseTime: averageTime,
                averageAccuracy: model.qualityScore, // Use static quality for now
                averageSpeed: min(speed, 1.0),
                averageReliability: reliability,
                testCount: testQueries.count,
                lastTested: Date()
            )
        }
    }
    
    // MARK: - Settings Management
    
    func setCurrentSearchModel(_ model: SearchModelConfiguration) {
        currentSearchModel = model
        
        // Update AppState
        if let appState = AppState.shared {
            appState.searchModel = model.id
        }
        
        saveSettings()
        
        // Send haptic feedback
        HapticService.shared.triggerSelectionFeedback()
    }
    
    func toggleSmartModelSelection(_ enabled: Bool) {
        enableSmartModelSelection = enabled
        saveSettings()
    }
    
    func setSpeedPreference(_ preferSpeed: Bool) {
        preferSpeedOverQuality = preferSpeed
        saveSettings()
    }
    
    // MARK: - Persistence
    
    private func loadPerformanceMetrics() {
        if let data = UserDefaults.standard.data(forKey: "SearchModelPerformanceMetrics"),
           let metrics = try? JSONDecoder().decode([String: ModelPerformanceMetrics].self, from: data) {
            modelPerformanceMetrics = metrics
        }
        
        if let lastUpdate = UserDefaults.standard.object(forKey: "LastMetricsUpdate") as? Date {
            lastMetricsUpdate = lastUpdate
        }
    }
    
    private func savePerformanceMetrics() {
        if let data = try? JSONEncoder().encode(modelPerformanceMetrics) {
            UserDefaults.standard.set(data, forKey: "SearchModelPerformanceMetrics")
        }
        
        if let lastUpdate = lastMetricsUpdate {
            UserDefaults.standard.set(lastUpdate, forKey: "LastMetricsUpdate")
        }
    }
    
    private func loadSettings() {
        enableSmartModelSelection = UserDefaults.standard.object(forKey: "EnableSmartModelSelection") as? Bool ?? true
        preferSpeedOverQuality = UserDefaults.standard.object(forKey: "PreferSpeedOverQuality") as? Bool ?? false
        autoSwitchBasedOnContent = UserDefaults.standard.object(forKey: "AutoSwitchBasedOnContent") as? Bool ?? true
        
        // Load current model from AppState
        if let appState = AppState.shared,
           let model = availableSearchModels.first(where: { $0.id == appState.searchModel }) {
            currentSearchModel = model
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(enableSmartModelSelection, forKey: "EnableSmartModelSelection")
        UserDefaults.standard.set(preferSpeedOverQuality, forKey: "PreferSpeedOverQuality")
        UserDefaults.standard.set(autoSwitchBasedOnContent, forKey: "AutoSwitchBasedOnContent")
    }
    
    // MARK: - Public API
    
    func shouldUpdateMetrics() -> Bool {
        guard let lastUpdate = lastMetricsUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) > metricsUpdateInterval
    }
    
    func getRecommendedModelsFor(contentType: SearchContentType) -> [SearchModelConfiguration] {
        return availableSearchModels.filter { model in
            switch contentType {
            case .text:
                return model.bestFor.contains(.quickSearch) || model.bestFor.contains(.generalQueries)
            case .images:
                return model.strengths.contains(.multimodal)
            case .documents:
                return model.bestFor.contains(.documentAnalysis) || model.contextWindow >= 100_000
            case .code:
                return model.strengths.contains(.reasoning)
            case .mixed:
                return model.strengths.contains(.multimodal) || model.qualityScore >= 0.90
            }
        }.sorted { lhs, rhs in
            if preferSpeedOverQuality {
                return lhs.averageResponseTime < rhs.averageResponseTime
            } else {
                return lhs.qualityScore > rhs.qualityScore
            }
        }
    }
    
    func resetToDefaults() {
        setupDefaultSearchModels()
        enableSmartModelSelection = true
        preferSpeedOverQuality = false
        autoSwitchBasedOnContent = true
        saveSettings()
    }
}

// MARK: - Supporting Types

struct SearchModelConfiguration: Identifiable, Codable {
    let id: String
    let name: String
    let provider: String
    let description: String
    var contextWindow: Int
    var pricePerMillion: Double
    let strengths: [ModelStrength]
    let bestFor: [SearchUseCase]
    var averageResponseTime: TimeInterval
    var qualityScore: Double
    let isRecommendedForSearch: Bool
    
    var formattedPrice: String {
        String(format: "$%.2f/M tokens", pricePerMillion)
    }
    
    var contextWindowFormatted: String {
        if contextWindow >= 1_000_000 {
            return String(format: "%.1fM", Double(contextWindow) / 1_000_000)
        } else if contextWindow >= 1_000 {
            return String(format: "%.0fK", Double(contextWindow) / 1_000)
        } else {
            return "\(contextWindow)"
        }
    }
}

enum ModelStrength: String, CaseIterable, Codable {
    case speed = "speed"
    case efficiency = "efficiency"
    case reasoning = "reasoning"
    case analysis = "analysis"
    case accuracy = "accuracy"
    case multimodal = "multimodal"
    case largeContext = "largeContext"
    case lowCost = "lowCost"
    case openSource = "openSource"
    
    var displayName: String {
        switch self {
        case .speed: return "Speed"
        case .efficiency: return "Efficiency"
        case .reasoning: return "Reasoning"
        case .analysis: return "Analysis"
        case .accuracy: return "Accuracy"
        case .multimodal: return "Multimodal"
        case .largeContext: return "Large Context"
        case .lowCost: return "Low Cost"
        case .openSource: return "Open Source"
        }
    }
    
    var icon: String {
        switch self {
        case .speed: return "bolt.fill"
        case .efficiency: return "leaf.fill"
        case .reasoning: return "brain.head.profile"
        case .analysis: return "chart.bar.fill"
        case .accuracy: return "target"
        case .multimodal: return "photo.stack"
        case .largeContext: return "doc.text.fill"
        case .lowCost: return "dollarsign.circle.fill"
        case .openSource: return "globe"
        }
    }
}

enum SearchUseCase: String, CaseIterable, Codable {
    case quickSearch = "quickSearch"
    case complexSearch = "complexSearch"
    case keywordMatching = "keywordMatching"
    case semanticAnalysis = "semanticAnalysis"
    case contentSummary = "contentSummary"
    case documentAnalysis = "documentAnalysis"
    case imageSearch = "imageSearch"
    case multiModalSearch = "multiModalSearch"
    case basicQuestions = "basicQuestions"
    case generalQueries = "generalQueries"
    
    var displayName: String {
        switch self {
        case .quickSearch: return "Quick Search"
        case .complexSearch: return "Complex Search"
        case .keywordMatching: return "Keyword Matching"
        case .semanticAnalysis: return "Semantic Analysis"
        case .contentSummary: return "Content Summary"
        case .documentAnalysis: return "Document Analysis"
        case .imageSearch: return "Image Search"
        case .multiModalSearch: return "Multi-Modal Search"
        case .basicQuestions: return "Basic Questions"
        case .generalQueries: return "General Queries"
        }
    }
}

enum SearchContentType: String, CaseIterable {
    case text = "text"
    case images = "images"
    case documents = "documents"
    case code = "code"
    case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .images: return "Images"
        case .documents: return "Documents"
        case .code: return "Code"
        case .mixed: return "Mixed Content"
        }
    }
}

struct ModelPerformanceMetrics: Codable {
    let averageResponseTime: TimeInterval
    let averageAccuracy: Double
    let averageSpeed: Double
    let averageReliability: Double
    let testCount: Int
    let lastTested: Date
    
    var overallScore: Double {
        (averageAccuracy + averageSpeed + averageReliability) / 3.0
    }
}

// Extension to make AppState accessible
extension AppState {
    static var shared: AppState? {
        // This would need to be properly implemented with dependency injection
        // For now, this is a placeholder
        return nil
    }
}