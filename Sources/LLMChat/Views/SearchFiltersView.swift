import SwiftUI

struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    @Environment(\.dismiss) private var dismiss
    @State private var tempFilters: SearchFilters
    
    init(filters: Binding<SearchFilters>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Search In") {
                    Toggle("Conversations", isOn: $tempFilters.includeConversations)
                    Toggle("Messages", isOn: $tempFilters.includeMessages)
                    Toggle("Attachments", isOn: $tempFilters.includeAttachments)
                }
                
                Section("Message Role") {
                    ForEach(MessageRole.allCases, id: \.self) { role in
                        Toggle(role.rawValue.capitalized, isOn: Binding(
                            get: { tempFilters.roles.contains(role) },
                            set: { isOn in
                                if isOn {
                                    tempFilters.roles.insert(role)
                                } else {
                                    tempFilters.roles.remove(role)
                                }
                            }
                        ))
                    }
                }
                
                Section("Message State") {
                    ForEach(MessageState.allCases, id: \.self) { state in
                        Toggle(state.displayName, isOn: Binding(
                            get: { tempFilters.states.contains(state) },
                            set: { isOn in
                                if isOn {
                                    tempFilters.states.insert(state)
                                } else {
                                    tempFilters.states.remove(state)
                                }
                            }
                        ))
                    }
                }
                
                Section("Date Range") {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { tempFilters.startDate ?? Date().addingTimeInterval(-30 * 24 * 60 * 60) },
                            set: { tempFilters.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .disabled(tempFilters.startDate == nil)
                    
                    Toggle("Enable Start Date", isOn: Binding(
                        get: { tempFilters.startDate != nil },
                        set: { isOn in
                            if isOn {
                                tempFilters.startDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                            } else {
                                tempFilters.startDate = nil
                            }
                        }
                    ))
                    
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { tempFilters.endDate ?? Date() },
                            set: { tempFilters.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .disabled(tempFilters.endDate == nil)
                    
                    Toggle("Enable End Date", isOn: Binding(
                        get: { tempFilters.endDate != nil },
                        set: { isOn in
                            if isOn {
                                tempFilters.endDate = Date()
                            } else {
                                tempFilters.endDate = nil
                            }
                        }
                    ))
                }
                
                Section("Results") {
                    Stepper("Max Results: \(tempFilters.maxResults)", 
                           value: $tempFilters.maxResults, 
                           in: 10...500, 
                           step: 10)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Apply") {
                    filters = tempFilters
                    dismiss()
                }
            )
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to Default") {
                        tempFilters = SearchFilters()
                    }
                }
            }
        }
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    let conversations: [Conversation]
    let onExport: (ExportService.ExportFormat, ExportService.ExportOptions) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportService.ExportFormat = .markdown
    @State private var exportOptions = ExportService.ExportOptions()
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    ForEach(ExportService.ExportFormat.allCases, id: \.self) { format in
                        HStack {
                            Button(action: {
                                selectedFormat = format
                            }) {
                                HStack {
                                    Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedFormat == format ? .blue : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(format.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(formatDescription(format))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section("Include") {
                    Toggle("Attachments", isOn: $exportOptions.includeAttachments)
                    Toggle("Timestamps", isOn: $exportOptions.includeTimestamps)
                    Toggle("Metadata", isOn: $exportOptions.includeMetadata)
                    Toggle("Reactions", isOn: $exportOptions.includeReactions)
                    Toggle("Tool Calls", isOn: $exportOptions.includeToolCalls)
                    Toggle("System Messages", isOn: $exportOptions.includeSystemMessages)
                }
                
                Section("Date Format") {
                    Picker("Format", selection: $exportOptions.dateFormat) {
                        Text("2024-01-15 14:30:00").tag("yyyy-MM-dd HH:mm:ss")
                        Text("Jan 15, 2024 2:30 PM").tag("MMM dd, yyyy h:mm a")
                        Text("15/01/2024 14:30").tag("dd/MM/yyyy HH:mm")
                        Text("01/15/2024 2:30 PM").tag("MM/dd/yyyy h:mm a")
                    }
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exporting \(conversations.count) conversation\(conversations.count == 1 ? "" : "s")")
                            .font(.headline)
                        
                        Text("Format: \(selectedFormat.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let firstConversation = conversations.first {
                            Text("Example: \(firstConversation.title)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Export") {
                    performExport()
                }
                .disabled(isExporting)
            )
            .overlay(
                Group {
                    if isExporting {
                        ProgressView("Exporting...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground).opacity(0.9))
                    }
                }
            )
        }
    }
    
    private func formatDescription(_ format: ExportService.ExportFormat) -> String {
        switch format {
        case .markdown:
            return "Rich text format with formatting preserved"
        case .json:
            return "Structured data format for developers"
        case .plainText:
            return "Simple text format compatible everywhere"
        case .pdf:
            return "Formatted document ready for printing"
        }
    }
    
    private func performExport() {
        isExporting = true
        
        // Add small delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onExport(selectedFormat, exportOptions)
            isExporting = false
            dismiss()
        }
    }
}

// MARK: - Quick Export View

struct QuickExportView: View {
    let conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportService.ExportFormat = .markdown
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Export Conversation")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(conversation.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    ForEach(ExportService.ExportFormat.allCases, id: \.self) { format in
                        Button(action: {
                            selectedFormat = format
                            performQuickExport()
                        }) {
                            HStack {
                                Image(systemName: formatIcon(format))
                                    .font(.title2)
                                    .foregroundColor(formatColor(format))
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(format.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(formatDescription(format))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isExporting)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .overlay(
                Group {
                    if isExporting {
                        ProgressView("Exporting...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground).opacity(0.9))
                    }
                }
            )
        }
    }
    
    private func formatIcon(_ format: ExportService.ExportFormat) -> String {
        switch format {
        case .markdown: return "text.alignleft"
        case .json: return "curlybraces"
        case .plainText: return "doc.text"
        case .pdf: return "doc.richtext"
        }
    }
    
    private func formatColor(_ format: ExportService.ExportFormat) -> Color {
        switch format {
        case .markdown: return .blue
        case .json: return .green
        case .plainText: return .orange
        case .pdf: return .red
        }
    }
    
    private func formatDescription(_ format: ExportService.ExportFormat) -> String {
        switch format {
        case .markdown:
            return "Formatted text with rich styling"
        case .json:
            return "Structured data format"
        case .plainText:
            return "Simple text file"
        case .pdf:
            return "Printable document"
        }
    }
    
    private func performQuickExport() {
        isExporting = true
        
        Task {
            do {
                let result = try await ExportService.shared.exportConversation(
                    conversation,
                    format: selectedFormat
                )
                
                await MainActor.run {
                    ExportService.shared.shareExport(result)
                    isExporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Export failed: \(error)")
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Extensions

extension MessageState {
    var displayName: String {
        switch self {
        case .sending: return "Sending"
        case .streaming: return "Streaming"
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }
}

#Preview("Search Filters") {
    SearchFiltersView(filters: .constant(SearchFilters()))
}

#Preview("Export Options") {
    ExportOptionsView(
        conversations: [Conversation()],
        onExport: { _, _ in }
    )
}

#Preview("Quick Export") {
    QuickExportView(conversation: Conversation())
}