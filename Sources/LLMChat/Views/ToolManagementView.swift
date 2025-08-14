import SwiftUI

struct ToolManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toolRegistry = ToolRegistry.shared
    @State private var showingToolDetails: Tool?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("AI Tool Arsenal")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("Empower your AI assistant with specialized tools for calculations, web search, news, finance, and more. Enable the tools you want the AI to have access to.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
                // Core Tools Section
                Section("🔧 Core Tools") {
                    ForEach(getCoreTools(), id: \.name) { tool in
                        ToolRowView(
                            tool: tool,
                            isEnabled: toolRegistry.isToolEnabled(tool.name),
                            onToggle: { isEnabled in
                                if isEnabled {
                                    toolRegistry.enableTool(tool.name)
                                } else {
                                    toolRegistry.disableTool(tool.name)
                                }
                            },
                            onShowDetails: {
                                showingToolDetails = tool
                            }
                        )
                    }
                }
                
                // Internet & Data Tools Section
                Section("🌐 Internet & Data") {
                    ForEach(getInternetTools(), id: \.name) { tool in
                        ToolRowView(
                            tool: tool,
                            isEnabled: toolRegistry.isToolEnabled(tool.name),
                            onToggle: { isEnabled in
                                if isEnabled {
                                    toolRegistry.enableTool(tool.name)
                                } else {
                                    toolRegistry.disableTool(tool.name)
                                }
                            },
                            onShowDetails: {
                                showingToolDetails = tool
                            }
                        )
                    }
                }
                
                // Finance Tools Section
                Section("💰 Finance & Markets") {
                    ForEach(getFinanceTools(), id: \.name) { tool in
                        ToolRowView(
                            tool: tool,
                            isEnabled: toolRegistry.isToolEnabled(tool.name),
                            onToggle: { isEnabled in
                                if isEnabled {
                                    toolRegistry.enableTool(tool.name)
                                } else {
                                    toolRegistry.disableTool(tool.name)
                                }
                            },
                            onShowDetails: {
                                showingToolDetails = tool
                            }
                        )
                    }
                }
                
                // Quick Stats Section
                Section("📊 Tool Statistics") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Tools")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(toolRegistry.allTools.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(toolRegistry.availableTools.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Tool Management")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
        .sheet(item: Binding<ToolDetailItem?>(
            get: { showingToolDetails.map(ToolDetailItem.init) },
            set: { _ in showingToolDetails = nil }
        )) { item in
            ToolDetailView(tool: item.tool)
        }
    }
    
    // MARK: - Tool Categorization
    
    private func getCoreTools() -> [Tool] {
        return toolRegistry.allTools.filter { tool in
            ["calculator", "datetime", "text_analysis", "unit_converter"].contains(tool.name)
        }
    }
    
    private func getInternetTools() -> [Tool] {
        return toolRegistry.allTools.filter { tool in
            ["web_search", "weather", "news"].contains(tool.name)
        }
    }
    
    private func getFinanceTools() -> [Tool] {
        return toolRegistry.allTools.filter { tool in
            ["stocks", "crypto"].contains(tool.name)
        }
    }
}

struct ToolRowView: View {
    let tool: Tool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    let onShowDetails: () -> Void
    
    private var toolIcon: String {
        switch tool.name {
        case "calculator":
            return "plusminus.circle"
        case "datetime":
            return "calendar.circle"
        case "weather":
            return "cloud.sun.circle"
        case "web_search":
            return "magnifyingglass.circle"
        case "text_analysis":
            return "text.magnifyingglass"
        case "unit_converter":
            return "arrow.triangle.2.circlepath.circle"
        case "news":
            return "newspaper.circle"
        case "stocks":
            return "chart.line.uptrend.xyaxis.circle"
        case "crypto":
            return "bitcoinsign.circle"
        default:
            return "gear.circle"
        }
    }
    
    private var toolColor: Color {
        switch tool.name {
        case "calculator":
            return .blue
        case "datetime":
            return .orange
        case "weather":
            return .cyan
        case "web_search":
            return .green
        case "text_analysis":
            return .purple
        case "unit_converter":
            return .red
        case "news":
            return .indigo
        case "stocks":
            return .mint
        case "crypto":
            return .yellow
        default:
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Tool Icon with Background
            ZStack {
                Circle()
                    .fill(toolColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: toolIcon)
                    .font(.title2)
                    .foregroundColor(toolColor)
            }
            
            // Tool Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tool.name.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(tool.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Controls
            VStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: onToggle
                ))
                .labelsHidden()
                .scaleEffect(0.9)
                
                Button(action: onShowDetails) {
                    Image(systemName: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEnabled ? toolColor.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled ? toolColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct ToolDetailView: View {
    let tool: Tool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tool.name.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(tool.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Parameters
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parameters")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if tool.parameters.properties.isEmpty {
                            Text("No parameters required")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(tool.parameters.properties.keys.sorted()), id: \.self) { key in
                                    if let property = tool.parameters.properties[key] {
                                        ParameterView(
                                            name: key,
                                            property: property,
                                            isRequired: tool.parameters.required.contains(key)
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Usage Examples
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Usage Examples")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(getUsageExamples(), id: \.self) { example in
                                Text("• \(example)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tool Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
    
    private func getUsageExamples() -> [String] {
        switch tool.name {
        case "calculator":
            return [
                "Calculate 25 * 4 + 10",
                "What's the square root of 144?",
                "Solve 2^8"
            ]
        case "datetime":
            return [
                "What's the current date and time?",
                "What time is it in Tokyo?",
                "Format today's date as MM/dd/yyyy"
            ]
        case "text_analysis":
            return [
                "Count the words in this text",
                "How many characters are in this sentence?",
                "Analyze this paragraph for word and sentence count"
            ]
        case "unit_converter":
            return [
                "Convert 100 fahrenheit to celsius",
                "How many meters is 5 feet?",
                "Convert 2 cups to liters"
            ]
        case "weather":
            return [
                "What's the weather in New York?",
                "Check the weather in London",
                "Current weather conditions in San Francisco"
            ]
        case "web_search":
            return [
                "Search for latest iPhone news",
                "Find information about climate change",
                "Look up Swift programming tutorials"
            ]
        case "news":
            return [
                "Get the latest technology news",
                "Show me today's business headlines",
                "What's happening in sports today?"
            ]
        case "stocks":
            return [
                "Get Apple stock price",
                "Show me Tesla's company overview",
                "Search for companies in the tech sector"
            ]
        case "crypto":
            return [
                "What's the current Bitcoin price?",
                "Show me trending cryptocurrencies",
                "Get market data for Ethereum"
            ]
        default:
            return ["Ask the AI to use this tool in your conversation"]
        }
    }
}

struct ParameterView: View {
    let name: String
    let property: ParameterProperty
    let isRequired: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("required")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                } else {
                    Text("optional")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Text(property.type)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(property.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let enumValues = property.enum {
                HStack {
                    Text("Options:")
                        .font(.caption2)
                        .fontWeight(.medium)
                    
                    Text(enumValues.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Helper wrapper for sheet presentation
struct ToolDetailItem: Identifiable {
    let id = UUID()
    let tool: Tool
}

#Preview {
    ToolManagementView()
}