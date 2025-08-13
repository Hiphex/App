import SwiftUI

struct ToolManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toolRegistry = ToolRegistry.shared
    @State private var showingToolDetails: Tool?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Tools allow the AI to perform specific actions like calculations, date/time operations, and text analysis. Enable the tools you want the AI to have access to.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
                
                Section("Available Tools") {
                    ForEach(toolRegistry.allTools, id: \.name) { tool in
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
        default:
            return .gray
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: toolIcon)
                .font(.title2)
                .foregroundColor(toolColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                
                Text(tool.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: onToggle
                ))
                .labelsHidden()
                
                Button(action: onShowDetails) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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