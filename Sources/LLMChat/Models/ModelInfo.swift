import Foundation
import SwiftData

@Model
final class ModelInfo {
    @Attribute(.unique) var id: String
    var name: String
    var description: String?
    var contextWindow: Int
    var pricePrompt: Double
    var priceCompletion: Double
    var providers: [String]
    var capabilities: ModelCapabilities
    var lastUpdated: Date
    
    init(
        id: String,
        name: String,
        description: String? = nil,
        contextWindow: Int,
        pricePrompt: Double,
        priceCompletion: Double,
        providers: [String] = [],
        capabilities: ModelCapabilities = ModelCapabilities()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contextWindow = contextWindow
        self.pricePrompt = pricePrompt
        self.priceCompletion = priceCompletion
        self.providers = providers
        self.capabilities = capabilities
        self.lastUpdated = Date()
    }
    
    var formattedPricePrompt: String {
        String(format: "$%.4f/1K tokens", pricePrompt * 1000)
    }
    
    var formattedPriceCompletion: String {
        String(format: "$%.4f/1K tokens", priceCompletion * 1000)
    }
}

struct ModelCapabilities: Codable {
    var supportsVision: Bool
    var supportsTools: Bool
    var supportsReasoning: Bool
    var supportsAudio: Bool
    var maxInputTokens: Int?
    var maxOutputTokens: Int?
    
    init(
        supportsVision: Bool = false,
        supportsTools: Bool = false,
        supportsReasoning: Bool = false,
        supportsAudio: Bool = false,
        maxInputTokens: Int? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsReasoning = supportsReasoning
        self.supportsAudio = supportsAudio
        self.maxInputTokens = maxInputTokens
        self.maxOutputTokens = maxOutputTokens
    }
}

// Model presets for quick selection
enum ModelPreset: String, CaseIterable {
    case speed = "Speed"
    case balanced = "Balanced"
    case reasoning = "Reasoning"
    case vision = "Vision"
    
    var description: String {
        switch self {
        case .speed:
            return "Fast responses, good for quick tasks"
        case .balanced:
            return "Good balance of speed and quality"
        case .reasoning:
            return "Best for complex reasoning tasks"
        case .vision:
            return "Optimized for image understanding"
        }
    }
    
    var defaultModelIds: [String] {
        switch self {
        case .speed:
            return ["anthropic/claude-3-haiku", "openai/gpt-3.5-turbo"]
        case .balanced:
            return ["anthropic/claude-3.5-sonnet", "openai/gpt-4o"]
        case .reasoning:
            return ["openai/o1-preview", "anthropic/claude-3-opus"]
        case .vision:
            return ["anthropic/claude-3.5-sonnet", "openai/gpt-4o", "google/gemini-pro-vision"]
        }
    }
}