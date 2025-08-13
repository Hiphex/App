# Example Usage - OpenRouter API Integration

This document shows how to integrate the OpenRouter API for different use cases covered in the LLMChat app.

## 1. Basic Chat Completion

```swift
import Foundation

// Basic chat with streaming
let request = ChatCompletionRequest(
    model: "anthropic/claude-3.5-sonnet",
    messages: [
        ChatMessage(role: "user", text: "Hello! How are you today?")
    ],
    temperature: 0.7,
    maxTokens: nil,
    stream: true,
    tools: nil,
    toolChoice: nil,
    providerOrder: nil,
    allowFallbacks: true
)

await OpenRouterAPI.shared.streamMessage(
    request: request,
    apiKey: "sk-or-your-api-key",
    messageId: UUID(),
    onToken: { token in
        print("Received token: \(token)")
    },
    onComplete: { usage in
        print("Completed! Tokens used: \(usage?.totalTokens ?? 0)")
    },
    onError: { error in
        print("Error: \(error)")
    }
)
```

## 2. Multimodal with Images

```swift
// Send an image with text
let imageData = UIImage(named: "photo")?.jpegData(compressionQuality: 0.8)
let base64Image = imageData?.base64EncodedString()

let content = [
    ContentItem(type: "text", text: "What's in this image?"),
    ContentItem(type: "image_url", imageUrl: "data:image/jpeg;base64,\(base64Image!)")
]

let request = ChatCompletionRequest(
    model: "anthropic/claude-3.5-sonnet",
    messages: [
        ChatMessage(role: "user", content: content)
    ],
    temperature: 0.7,
    maxTokens: nil,
    stream: true,
    tools: nil,
    toolChoice: nil,
    providerOrder: nil,
    allowFallbacks: true
)
```

## 3. Tool Calling Example

```swift
// Define a calculator tool
let calculatorTool = Tool(
    type: "function",
    function: ToolFunction(
        name: "calculate",
        description: "Perform basic arithmetic calculations",
        parameters: [
            "type": "object",
            "properties": [
                "expression": [
                    "type": "string",
                    "description": "Mathematical expression to evaluate"
                ]
            ],
            "required": ["expression"]
        ]
    )
)

let request = ChatCompletionRequest(
    model: "anthropic/claude-3.5-sonnet",
    messages: [
        ChatMessage(role: "user", text: "What's 15 * 23?")
    ],
    temperature: 0.7,
    maxTokens: nil,
    stream: false,
    tools: [calculatorTool],
    toolChoice: "auto",
    providerOrder: nil,
    allowFallbacks: true
)

// Handle tool calls in response
let response = try await OpenRouterAPI.shared.sendMessage(request: request, apiKey: apiKey)
if let toolCalls = response.choices.first?.message.toolCalls {
    for toolCall in toolCalls {
        if toolCall.function.name == "calculate" {
            // Execute calculation locally
            let result = evaluateExpression(toolCall.function.arguments)
            
            // Send result back to model
            let toolMessage = ChatMessage(
                role: "tool",
                content: [ContentItem(type: "text", text: result)],
                toolCallId: toolCall.id
            )
            // Continue conversation with tool result...
        }
    }
}
```

## 4. Model Fallbacks

```swift
// Use fallback models for reliability
let request = ChatCompletionRequest(
    model: "anthropic/claude-3.5-sonnet",
    messages: messages,
    temperature: 0.7,
    maxTokens: nil,
    stream: true,
    tools: nil,
    toolChoice: nil,
    providerOrder: [
        "anthropic/claude-3.5-sonnet",
        "openai/gpt-4o",
        "anthropic/claude-3-haiku"
    ],
    allowFallbacks: true
)
```

## 5. Fetching Available Models

```swift
// Get all available models
let models = try await OpenRouterAPI.shared.fetchModels(apiKey: apiKey)

// Filter by capabilities
let visionModels = models.filter { model in
    let capabilities = inferCapabilities(from: model)
    return capabilities.supportsVision
}

// Group by provider
let groupedModels = Dictionary(grouping: models) { model in
    model.id.components(separatedBy: "/").first ?? "Unknown"
}
```

## 6. Cost Estimation

```swift
// Calculate estimated cost
func estimateCost(prompt: String, completion: String, model: ModelInfo) -> Double {
    let promptTokens = estimateTokens(prompt)
    let completionTokens = estimateTokens(completion)
    
    let promptCost = Double(promptTokens) * model.pricePrompt / 1000.0
    let completionCost = Double(completionTokens) * model.priceCompletion / 1000.0
    
    return promptCost + completionCost
}

// Show in UI
Text("Cost: $\(cost, specifier: "%.4f")")
    .font(.caption)
    .foregroundColor(.secondary)
```

## 7. Error Handling

```swift
do {
    let response = try await OpenRouterAPI.shared.sendMessage(
        request: request,
        apiKey: apiKey
    )
    // Handle success
} catch OpenRouterError.httpError(let code) {
    switch code {
    case 401:
        // Invalid API key
        showError("Invalid API key")
    case 429:
        // Rate limited
        showError("Too many requests. Please try again later.")
    case 402:
        // Insufficient credits
        showError("Insufficient credits. Please add funds to your OpenRouter account.")
    default:
        showError("Server error: \(code)")
    }
} catch OpenRouterError.networkError(let error) {
    // Network connectivity issues
    showError("Network error: \(error.localizedDescription)")
} catch {
    // Other errors
    showError("Unexpected error: \(error.localizedDescription)")
}
```

## 8. Streaming with Cancellation

```swift
// Start streaming
let messageId = UUID()
OpenRouterAPI.shared.streamMessage(
    request: request,
    apiKey: apiKey,
    messageId: messageId,
    onToken: { token in
        // Update UI
    },
    onComplete: { usage in
        // Finalize message
    },
    onError: { error in
        // Handle error
    }
)

// Cancel if needed
OpenRouterAPI.shared.cancelStream(for: messageId)
```

## 9. Custom Request Headers

```swift
// The OpenRouterAPI automatically includes these headers:
// - Authorization: Bearer {apiKey}
// - Content-Type: application/json  
// - HTTP-Referer: LLMChat/1.0
// - X-Title: LLMChat iOS

// For attribution in OpenRouter analytics
```

## 10. Background Task Handling

```swift
// For longer requests, use background tasks
func sendLongRequest() {
    let taskId = UIApplication.shared.beginBackgroundTask { 
        // Task expired
        OpenRouterAPI.shared.cancelAllStreams()
    }
    
    OpenRouterAPI.shared.streamMessage(
        request: request,
        apiKey: apiKey,
        messageId: messageId,
        onToken: { token in
            // Process token
        },
        onComplete: { usage in
            UIApplication.shared.endBackgroundTask(taskId)
        },
        onError: { error in
            UIApplication.shared.endBackgroundTask(taskId)
        }
    )
}
```

## Model-Specific Examples

### Claude 3.5 Sonnet (Best for general use)
```swift
let request = ChatCompletionRequest(
    model: "anthropic/claude-3.5-sonnet",
    messages: messages,
    temperature: 0.7,
    stream: true,
    allowFallbacks: true
)
```

### GPT-4o (Great for vision tasks)
```swift
let request = ChatCompletionRequest(
    model: "openai/gpt-4o",
    messages: messagesWithImages,
    temperature: 0.3,
    stream: true,
    allowFallbacks: true
)
```

### Claude 3 Haiku (Fast and economical)
```swift
let request = ChatCompletionRequest(
    model: "anthropic/claude-3-haiku",
    messages: messages,
    temperature: 0.5,
    maxTokens: 1000,
    stream: true,
    allowFallbacks: false // Fast model, no fallback needed
)
```

### OpenAI o1-preview (For complex reasoning)
```swift
let request = ChatCompletionRequest(
    model: "openai/o1-preview",
    messages: [
        ChatMessage(role: "user", text: "Solve this complex math problem step by step...")
    ],
    temperature: 0.1, // Lower temperature for reasoning
    stream: false, // o1 models may not support streaming
    allowFallbacks: false
)
```

This covers the main integration patterns used throughout the LLMChat app. The OpenRouter API provides a consistent interface across all these different model providers and capabilities.