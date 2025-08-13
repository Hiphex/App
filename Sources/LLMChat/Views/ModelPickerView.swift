import SwiftUI
import SwiftData

struct ModelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    
    @Binding var selectedModel: String
    
    @State private var availableModels: [ModelResponse] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedPreset: ModelPreset?
    
    @Query private var cachedModels: [ModelInfo]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading models...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ErrorView(error: error, onRetry: loadModels)
                } else {
                    modelsList
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadModels()
        }
    }
    
    private var modelsList: some View {
        List {
            // Model Presets Section
            Section("Quick Select") {
                ForEach(ModelPreset.allCases, id: \.self) { preset in
                    PresetRowView(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        onSelect: {
                            selectedPreset = preset
                            if let firstModel = preset.defaultModelIds.first,
                               availableModels.contains(where: { $0.id == firstModel }) {
                                selectedModel = firstModel
                            }
                        }
                    )
                }
            }
            
            // All Models Section
            Section("All Models") {
                ForEach(groupedModels.keys.sorted(), id: \.self) { provider in
                    DisclosureGroup(provider.capitalized) {
                        ForEach(groupedModels[provider] ?? []) { model in
                            ModelRowView(
                                model: model,
                                isSelected: selectedModel == model.id,
                                onSelect: {
                                    selectedModel = model.id
                                    selectedPreset = nil
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var groupedModels: [String: [ModelResponse]] {
        Dictionary(grouping: availableModels) { model in
            model.id.components(separatedBy: "/").first ?? "Unknown"
        }
    }
    
    private func loadModels() {
        guard let apiKey = appState.currentAPIKey else {
            error = "No API key available"
            isLoading = false
            return
        }
        
        Task {
            do {
                let models = try await OpenRouterAPI.shared.fetchModels(apiKey: apiKey)
                
                await MainActor.run {
                    self.availableModels = models.sorted { $0.name < $1.name }
                    self.isLoading = false
                    
                    // Cache models in SwiftData
                    updateCachedModels(models)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func updateCachedModels(_ models: [ModelResponse]) {
        // Clear existing cached models
        for cachedModel in cachedModels {
            modelContext.delete(cachedModel)
        }
        
        // Add new models
        for model in models {
            let modelInfo = ModelInfo(
                id: model.id,
                name: model.name,
                description: model.description,
                contextWindow: model.contextLength,
                pricePrompt: Double(model.pricing.prompt) ?? 0.0,
                priceCompletion: Double(model.pricing.completion) ?? 0.0,
                providers: [model.topProvider?.name ?? "Unknown"],
                capabilities: inferCapabilities(from: model)
            )
            modelContext.insert(modelInfo)
        }
        
        try? modelContext.save()
    }
    
    private func inferCapabilities(from model: ModelResponse) -> ModelCapabilities {
        let name = model.name.lowercased()
        let id = model.id.lowercased()
        
        return ModelCapabilities(
            supportsVision: name.contains("vision") || id.contains("vision") || name.contains("gpt-4") || name.contains("claude-3"),
            supportsTools: !name.contains("instruct") && !name.contains("chat"),
            supportsReasoning: name.contains("o1") || name.contains("reasoning"),
            supportsAudio: false, // Would need more specific detection
            maxInputTokens: model.contextLength,
            maxOutputTokens: nil
        )
    }
}

struct PresetRowView: View {
    let preset: ModelPreset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.rawValue)
                            .font(.headline)
                        
                        if isSelected {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !isSelected {
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ModelRowView: View {
    let model: ModelResponse
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isSelected {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let description = model.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("Context: \(formatContextLength(model.contextLength))")
                        
                        Spacer()
                        
                        if let provider = model.topProvider {
                            Text(provider.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                if !isSelected {
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatContextLength(_ length: Int) -> String {
        if length >= 1_000_000 {
            return "\(length / 1_000_000)M tokens"
        } else if length >= 1_000 {
            return "\(length / 1_000)K tokens"
        } else {
            return "\(length) tokens"
        }
    }
}

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Failed to load models")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ModelPickerView(selectedModel: .constant("anthropic/claude-3.5-sonnet"))
        .environmentObject(AppState())
        .modelContainer(for: [
            Conversation.self,
            Message.self,
            Attachment.self,
            ModelInfo.self
        ])
}