import Foundation
import Combine

// MARK: - Request/Response Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool
    let tools: [Tool]?
    let toolChoice: String?
    let providerOrder: [String]?
    let allowFallbacks: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream, tools
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
        case providerOrder = "provider_order"
        case allowFallbacks = "allow_fallbacks"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: [ContentItem]
    let toolCallId: String?
    let toolCalls: [ToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }
    
    init(role: String, text: String) {
        self.role = role
        self.content = [ContentItem(type: "text", text: text)]
        self.toolCallId = nil
        self.toolCalls = nil
    }
    
    init(role: String, content: [ContentItem], toolCalls: [ToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = nil
        self.toolCalls = toolCalls
    }
}

struct ContentItem: Codable {
    let type: String
    let text: String?
    let imageUrl: ImageUrl?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.imageUrl = nil
    }
    
    init(type: String, imageUrl: String) {
        self.type = type
        self.text = nil
        self.imageUrl = ImageUrl(url: imageUrl)
    }
}

struct ImageUrl: Codable {
    let url: String
    let detail: String?
    
    init(url: String, detail: String = "auto") {
        self.url = url
        self.detail = detail
    }
}

struct Tool: Codable {
    let type: String
    let function: ToolFunction
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
}

struct ChatCompletionStreamResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    let usage: Usage?
}

struct Choice: Codable {
    let index: Int
    let message: ChatMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct StreamChoice: Codable {
    let index: Int
    let delta: ChatMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct ModelsResponse: Codable {
    let data: [ModelResponse]
}

struct ModelResponse: Codable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int
    let pricing: Pricing
    let topProvider: Provider?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, pricing
        case contextLength = "context_length"
        case topProvider = "top_provider"
    }
}

struct Pricing: Codable {
    let prompt: String
    let completion: String
}

struct Provider: Codable {
    let id: String
    let name: String
}

// MARK: - OpenRouter API Client

@MainActor
class OpenRouterAPI: ObservableObject {
    static let shared = OpenRouterAPI()
    
    private let baseURL = "https://openrouter.ai/api/v1"
    private let session: URLSession
    private var streamingTasks: [UUID: URLSessionDataTask] = [:]
    private var streamBuffers: [UUID: String] = [:]
    
    @Published var isLoading = false
    @Published var error: OpenRouterError?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication
    
    private func createRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LLMChat/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("LLMChat iOS", forHTTPHeaderField: "X-Title")
        return request
    }
    
    // MARK: - Models API
    
    func fetchModels(apiKey: String) async throws -> [ModelResponse] {
        guard let url = URL(string: "\(baseURL)/models") else {
            throw OpenRouterError.invalidURL
        }
        
        let request = createRequest(url: url, apiKey: apiKey)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenRouterError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = try? extractErrorMessage(from: data)
                
                // Handle specific status codes
                switch httpResponse.statusCode {
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    throw OpenRouterError.rateLimited(retryAfter: retryAfter)
                case 402:
                    throw OpenRouterError.insufficientCredits
                case 404:
                    throw OpenRouterError.modelNotFound
                default:
                    throw OpenRouterError.httpError(httpResponse.statusCode, errorMessage)
                }
            }
            
            let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
            return modelsResponse.data
        } catch {
            if error is OpenRouterError {
                throw error
            }
            throw OpenRouterError.networkError(error)
        }
    }
    
    // MARK: - Chat Completions
    
    func sendMessage(
        request: ChatCompletionRequest,
        apiKey: String
    ) async throws -> ChatCompletionResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenRouterError.invalidURL
        }
        
        var urlRequest = createRequest(url: url, apiKey: apiKey)
        urlRequest.httpMethod = "POST"
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenRouterError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = try? extractErrorMessage(from: data)
                
                // Handle specific status codes
                switch httpResponse.statusCode {
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    throw OpenRouterError.rateLimited(retryAfter: retryAfter)
                case 402:
                    throw OpenRouterError.insufficientCredits
                case 404:
                    throw OpenRouterError.modelNotFound
                case 413:
                    throw OpenRouterError.contextLengthExceeded
                default:
                    throw OpenRouterError.httpError(httpResponse.statusCode, errorMessage)
                }
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(ChatCompletionResponse.self, from: data)
        } catch {
            if error is OpenRouterError {
                throw error
            }
            throw OpenRouterError.networkError(error)
        }
    }
    
    // MARK: - Streaming Chat
    
    func streamMessage(
        request: ChatCompletionRequest,
        apiKey: String,
        messageId: UUID,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Usage?) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onError(OpenRouterError.invalidURL)
            return
        }
        
        var urlRequest = createRequest(url: url, apiKey: apiKey)
        urlRequest.httpMethod = "POST"
        
        var streamRequest = request
        streamRequest = ChatCompletionRequest(
            model: request.model,
            messages: request.messages,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: true,
            tools: request.tools,
            toolChoice: request.toolChoice,
            providerOrder: request.providerOrder,
            allowFallbacks: request.allowFallbacks
        )
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(streamRequest)
        } catch {
            onError(error)
            return
        }
        
        // Initialize buffer for this stream
        streamBuffers[messageId] = ""
        
        let task = session.dataTask(with: urlRequest) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.streamBuffers.removeValue(forKey: messageId)
                    onError(OpenRouterError.networkError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.streamBuffers.removeValue(forKey: messageId)
                    onError(OpenRouterError.invalidResponse)
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    self?.streamBuffers.removeValue(forKey: messageId)
                    
                    // Handle specific error codes for streaming
                    let error: OpenRouterError
                    switch httpResponse.statusCode {
                    case 429:
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                        error = OpenRouterError.rateLimited(retryAfter: retryAfter)
                    case 402:
                        error = OpenRouterError.insufficientCredits
                    case 404:
                        error = OpenRouterError.modelNotFound
                    case 413:
                        error = OpenRouterError.contextLengthExceeded
                    default:
                        error = OpenRouterError.httpError(httpResponse.statusCode, nil)
                    }
                    
                    onError(error)
                    return
                }
                
                guard let data = data else { return }
                
                self?.processStreamDataIncremental(
                    data: data,
                    messageId: messageId,
                    onToken: onToken,
                    onComplete: onComplete,
                    onError: onError
                )
            }
        }
        
        streamingTasks[messageId] = task
        task.resume()
    }
    
    private func processStreamDataIncremental(
        data: Data,
        messageId: UUID,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Usage?) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard let newString = String(data: data, encoding: .utf8) else { return }
        
        // Append new data to buffer for this message
        streamBuffers[messageId, default: ""] += newString
        
        // Process complete lines from the buffer
        var buffer = streamBuffers[messageId] ?? ""
        let lines = buffer.components(separatedBy: .newlines)
        
        // Keep the last line in buffer if it doesn't end with newline (incomplete)
        let incompleteLastLine = !buffer.hasSuffix("\n") && !buffer.hasSuffix("\r\n")
        let linesToProcess = incompleteLastLine ? Array(lines.dropLast()) : lines
        
        // Update buffer with remaining incomplete line
        streamBuffers[messageId] = incompleteLastLine ? lines.last ?? "" : ""
        
        for line in linesToProcess {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and non-data lines
            guard trimmed.hasPrefix("data: ") else { continue }
            
            let jsonString = String(trimmed.dropFirst(6))
            
            // Check for completion
            if jsonString == "[DONE]" {
                streamBuffers.removeValue(forKey: messageId)
                onComplete(nil)
                return
            }
            
            // Parse streaming response
            guard let jsonData = jsonString.data(using: .utf8) else { continue }
            
            do {
                let streamResponse = try JSONDecoder().decode(ChatCompletionStreamResponse.self, from: jsonData)
                
                if let choice = streamResponse.choices.first {
                    if let content = choice.delta.content.first?.text {
                        onToken(content)
                    }
                    
                    if choice.finishReason != nil {
                        streamBuffers.removeValue(forKey: messageId)
                        onComplete(streamResponse.usage)
                        return
                    }
                }
            } catch {
                // Continue processing other chunks even if one fails
                print("Failed to decode streaming response: \(error)")
                continue
            }
        }
    }
    
    // MARK: - Task Management
    
    func cancelStream(for messageId: UUID) {
        Task { @MainActor in
            streamingTasks[messageId]?.cancel()
            streamingTasks.removeValue(forKey: messageId)
            streamBuffers.removeValue(forKey: messageId)
        }
    }
    
    func cancelAllStreams() {
        Task { @MainActor in
            streamingTasks.values.forEach { $0.cancel() }
            streamingTasks.removeAll()
            streamBuffers.removeAll()
        }
    }
    
    // MARK: - Error Parsing
    
    private func extractErrorMessage(from data: Data) throws -> String {
        struct ErrorResponse: Codable {
            let error: ErrorDetail?
            let message: String?
            
            struct ErrorDetail: Codable {
                let message: String?
                let type: String?
                let code: String?
            }
        }
        
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
        return errorResponse.error?.message ?? errorResponse.message ?? "Unknown error"
    }
}

// MARK: - Error Handling

enum OpenRouterError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case networkError(Error)
    case decodingError(Error)
    case missingAPIKey
    case rateLimited(retryAfter: Int?)
    case insufficientCredits
    case modelNotFound
    case contextLengthExceeded
    case streamingInterrupted
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            switch code {
            case 400:
                return "Bad request: \(message ?? "Invalid request parameters")"
            case 401:
                return "Authentication failed: Please check your API key"
            case 403:
                return "Access forbidden: \(message ?? "Insufficient permissions")"
            case 404:
                return "Model not found: \(message ?? "The requested model is not available")"
            case 429:
                return "Rate limit exceeded: \(message ?? "Please try again later")"
            case 500:
                return "Server error: \(message ?? "OpenRouter is experiencing issues")"
            case 502, 503, 504:
                return "Service unavailable: \(message ?? "OpenRouter is temporarily unavailable")"
            default:
                return "HTTP error \(code): \(message ?? "Unknown error")"
            }
        case .networkError(let error):
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return "No internet connection. Please check your network and try again."
            } else if (error as NSError).code == NSURLErrorTimedOut {
                return "Request timed out. Please try again."
            } else {
                return "Network error: \(error.localizedDescription)"
            }
        case .decodingError(let error):
            return "Response parsing error: \(error.localizedDescription)"
        case .missingAPIKey:
            return "API key is required. Please add your OpenRouter API key in settings."
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Please wait \(retryAfter) seconds before trying again."
            } else {
                return "Rate limited. Please try again in a few moments."
            }
        case .insufficientCredits:
            return "Insufficient credits. Please add credits to your OpenRouter account."
        case .modelNotFound:
            return "The selected model is not available. Please choose a different model."
        case .contextLengthExceeded:
            return "Message too long for this model. Please shorten your message or choose a model with a larger context window."
        case .streamingInterrupted:
            return "Connection was interrupted during streaming."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .httpError(let code, _):
            switch code {
            case 401:
                return "Check your API key in Settings and make sure it's valid."
            case 429:
                return "Wait a moment and try again, or upgrade your OpenRouter plan."
            case 500, 502, 503, 504:
                return "This is a temporary server issue. Please try again in a few minutes."
            default:
                return nil
            }
        case .networkError:
            return "Check your internet connection and try again."
        case .rateLimited:
            return "Wait for the rate limit to reset, or upgrade your plan for higher limits."
        case .insufficientCredits:
            return "Add credits to your OpenRouter account to continue using the service."
        case .modelNotFound:
            return "Choose a different model from the model picker."
        case .contextLengthExceeded:
            return "Try shortening your message or selecting a model with a larger context window."
        case .streamingInterrupted:
            return "Check your internet connection and try sending the message again."
        default:
            return nil
        }
    }
}