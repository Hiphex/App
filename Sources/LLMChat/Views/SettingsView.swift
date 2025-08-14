import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var hapticService = HapticService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var backgroundTaskService = BackgroundTaskService.shared
    @StateObject private var searchModelService = SearchModelConfigurationService.shared
    
    @State private var showingAPIKeyAlert = false
    @State private var newAPIKey = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingAdvancedSettings = false
    @State private var selectedSettingsTab: SettingsTab = .general
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Settings Category", selection: $selectedSettingsTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedSettingsTab) {
                    generalSettingsView()
                        .tag(SettingsTab.general)
                    
                    modelsSettingsView()
                        .tag(SettingsTab.models)
                    
                    searchSettingsView()
                        .tag(SettingsTab.search)
                    
                    syncSettingsView()
                        .tag(SettingsTab.sync)
                    
                    notificationsSettingsView()
                        .tag(SettingsTab.notifications)
                    
                    privacySettingsView()
                        .tag(SettingsTab.privacy)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset All") {
                        resetAllSettings()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        hapticService.triggerButtonTapFeedback()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Settings Views
    
    @ViewBuilder
    private func generalSettingsView() -> some View {
        List {
            // API Key Section
            Section("API Key") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenRouter API Key")
                            .font(.headline)
                        
                        if appState.hasValidAPIKey {
                            Text("••••••••••••••••")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No API key configured")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                    
                    Button(appState.hasValidAPIKey ? "Change" : "Add") {
                        hapticService.triggerButtonTapFeedback()
                        showingAPIKeyAlert = true
                    }
                    .foregroundColor(.blue)
                }
                
                if appState.hasValidAPIKey {
                    Button("Remove API Key", role: .destructive) {
                        hapticService.triggerButtonTapFeedback()
                        showingDeleteConfirmation = true
                    }
                }
            }
            
            // Display Settings
            Section("Display") {
                Toggle("Show Token Count", isOn: $appState.showTokenCount)
                    .onChange(of: appState.showTokenCount) { _ in
                        hapticService.triggerToggleFeedback()
                    }
                
                Toggle("Show Cost Estimates", isOn: $appState.showCostEstimates)
                    .onChange(of: appState.showCostEstimates) { _ in
                        hapticService.triggerToggleFeedback()
                    }
            }
            
            // Theme Settings
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $appState.isDarkMode)
                    .onChange(of: appState.isDarkMode) { _ in
                        hapticService.triggerToggleFeedback()
                    }
                
                ColorPicker("Accent Color", selection: $appState.accentColor)
            }
            
            // Haptic Settings
            Section("Haptic Feedback") {
                Toggle("Enable Haptics", isOn: $hapticService.isHapticsEnabled)
                    .onChange(of: hapticService.isHapticsEnabled) { newValue in
                        hapticService.setHapticsEnabled(newValue)
                    }
                
                if hapticService.isHapticsEnabled {
                    Picker("Intensity", selection: $hapticService.hapticIntensity) {
                        ForEach(HapticIntensity.allCases, id: \.self) { intensity in
                            Text(intensity.displayName).tag(intensity)
                        }
                    }
                    .onChange(of: hapticService.hapticIntensity) { newValue in
                        hapticService.setHapticIntensity(newValue)
                        hapticService.triggerImpactFeedback(.medium)
                    }
                    
                    Button("Test Haptics") {
                        hapticService.triggerMessageSentFeedback()
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link("OpenRouter Website", destination: URL(string: "https://openrouter.ai")!)
                Link("Privacy Policy", destination: URL(string: "https://openrouter.ai/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://openrouter.ai/terms")!)
            }
            
            // Support Section
            Section("Support") {
                Link("Help & Documentation", destination: URL(string: "https://openrouter.ai/docs")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/openrouter/openrouter/issues")!)
            }
        }
    }
    
    @ViewBuilder
    private func modelsSettingsView() -> some View {
        List {
            Section("Default Model Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Temperature: \(appState.defaultTemperature, specifier: "%.1f")")
                    Slider(value: $appState.defaultTemperature, in: 0...2, step: 0.1)
                        .onChange(of: appState.defaultTemperature) { _ in
                            hapticService.triggerSelectionFeedback()
                        }
                }
                
                Toggle("Allow Fallbacks", isOn: $appState.allowFallbacks)
                    .onChange(of: appState.allowFallbacks) { _ in
                        hapticService.triggerToggleFeedback()
                    }
            }
            
            Section("Advanced Model Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Cache Size: \(appState.maxCacheSize) MB")
                    Slider(value: Binding(
                        get: { Double(appState.maxCacheSize) },
                        set: { appState.maxCacheSize = Int($0) }
                    ), in: 50...500, step: 10)
                        .onChange(of: appState.maxCacheSize) { _ in
                            hapticService.triggerSelectionFeedback()
                        }
                }
                
                Toggle("Advanced Logging", isOn: $appState.enableAdvancedLogging)
                    .onChange(of: appState.enableAdvancedLogging) { _ in
                        hapticService.triggerToggleFeedback()
                    }
            }
        }
    }
    
    @ViewBuilder
    private func searchSettingsView() -> some View {
        List {
            Section("Search Model Configuration") {
                if let currentModel = searchModelService.currentSearchModel {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current Model")
                                .font(.headline)
                            Spacer()
                            Text(currentModel.name)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(currentModel.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label(currentModel.formattedPrice, systemImage: "dollarsign.circle")
                                .font(.caption)
                            Spacer()
                            Label(currentModel.contextWindowFormatted, systemImage: "doc.text")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                NavigationLink("Select Search Model") {
                    SearchModelSelectionView()
                        .environmentObject(searchModelService)
                }
            }
            
            Section("Smart Selection") {
                Toggle("Enable Smart Model Selection", isOn: $searchModelService.enableSmartModelSelection)
                    .onChange(of: searchModelService.enableSmartModelSelection) { newValue in
                        searchModelService.toggleSmartModelSelection(newValue)
                        hapticService.triggerToggleFeedback()
                    }
                
                if searchModelService.enableSmartModelSelection {
                    Toggle("Prefer Speed Over Quality", isOn: $searchModelService.preferSpeedOverQuality)
                        .onChange(of: searchModelService.preferSpeedOverQuality) { newValue in
                            searchModelService.setSpeedPreference(newValue)
                            hapticService.triggerToggleFeedback()
                        }
                    
                    Toggle("Auto-Switch Based on Content", isOn: $searchModelService.autoSwitchBasedOnContent)
                        .onChange(of: searchModelService.autoSwitchBasedOnContent) { _ in
                            hapticService.triggerToggleFeedback()
                        }
                }
            }
            
            Section("Search Behavior") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Temperature: \(appState.searchTemperature, specifier: "%.1f")")
                    Slider(value: $appState.searchTemperature, in: 0...1, step: 0.1)
                        .onChange(of: appState.searchTemperature) { _ in
                            hapticService.triggerSelectionFeedback()
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Results: \(appState.maxSearchResults)")
                    Slider(value: Binding(
                        get: { Double(appState.maxSearchResults) },
                        set: { appState.maxSearchResults = Int($0) }
                    ), in: 10...100, step: 10)
                        .onChange(of: appState.maxSearchResults) { _ in
                            hapticService.triggerSelectionFeedback()
                        }
                }
                
                Toggle("Enable Semantic Search", isOn: $appState.enableSemanticSearch)
                    .onChange(of: appState.enableSemanticSearch) { _ in
                        hapticService.triggerToggleFeedback()
                    }
                
                Picker("Results Grouping", selection: $appState.searchResultsGrouping) {
                    Text("By Conversation").tag("conversation")
                    Text("By Date").tag("date")
                    Text("By Relevance").tag("relevance")
                }
                .onChange(of: appState.searchResultsGrouping) { _ in
                    hapticService.triggerSelectionFeedback()
                }
            }
            
            Section("Performance Metrics") {
                if searchModelService.isLoadingMetrics {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Updating metrics...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    if let lastUpdate = searchModelService.lastMetricsUpdate {
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(lastUpdate, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Update Performance Metrics") {
                        hapticService.triggerButtonTapFeedback()
                        Task {
                            await searchModelService.updatePerformanceMetrics()
                        }
                    }
                    .disabled(searchModelService.isLoadingMetrics)
                }
            }
        }
    }
    
    @ViewBuilder
    private func syncSettingsView() -> some View {
        List {
            Section("CloudKit Sync") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("iCloud Sync")
                            .font(.headline)
                        
                        if cloudKitService.isCloudKitAvailable {
                            Text("Available")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Unavailable")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { cloudKitService.isCloudKitEnabled },
                        set: { cloudKitService.setCloudKitEnabled($0) }
                    ))
                    .disabled(!cloudKitService.isCloudKitAvailable)
                    .onChange(of: cloudKitService.isCloudKitEnabled) { _ in
                        hapticService.triggerToggleFeedback()
                    }
                }
                
                if cloudKitService.isCloudKitEnabled && cloudKitService.isCloudKitAvailable {
                    if cloudKitService.isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(cloudKitService.syncProgress * 100))%")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        if let lastSync = cloudKitService.lastSyncDate {
                            HStack {
                                Text("Last Sync")
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Sync Now") {
                            hapticService.triggerButtonTapFeedback()
                            Task {
                                await cloudKitService.forceSyncNow()
                            }
                        }
                        .disabled(cloudKitService.isSyncing)
                    }
                    
                    if let error = cloudKitService.syncError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button("Reset Sync", role: .destructive) {
                        hapticService.triggerButtonTapFeedback()
                        cloudKitService.resetSync()
                    }
                }
            }
            
            Section("Background Sync") {
                Toggle("Enable Auto Sync", isOn: $appState.enableAutoSync)
                    .onChange(of: appState.enableAutoSync) { _ in
                        hapticService.triggerToggleFeedback()
                    }
                
                Toggle("Enable Background Sync", isOn: $appState.enableBackgroundSync)
                    .onChange(of: appState.enableBackgroundSync) { _ in
                        hapticService.triggerToggleFeedback()
                    }
                
                if appState.enableBackgroundSync {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Frequency: \(appState.syncFrequency) minutes")
                        Slider(value: Binding(
                            get: { Double(appState.syncFrequency) },
                            set: { appState.syncFrequency = Int($0) }
                        ), in: 5...60, step: 5)
                            .onChange(of: appState.syncFrequency) { _ in
                                hapticService.triggerSelectionFeedback()
                            }
                    }
                }
                
                if backgroundTaskService.isProcessingBackground {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Background processing...")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastSync = backgroundTaskService.lastBackgroundSync {
                    HStack {
                        Text("Last Background Sync")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func notificationsSettingsView() -> some View {
        List {
            Section("Notification Permissions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Push Notifications")
                            .font(.headline)
                        
                        switch notificationService.authorizationStatus {
                        case .authorized:
                            Text("Authorized")
                                .font(.caption)
                                .foregroundColor(.green)
                        case .denied:
                            Text("Denied")
                                .font(.caption)
                                .foregroundColor(.red)
                        case .notDetermined:
                            Text("Not Requested")
                                .font(.caption)
                                .foregroundColor(.orange)
                        default:
                            Text("Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if notificationService.authorizationStatus == .notDetermined {
                        Button("Request Permission") {
                            hapticService.triggerButtonTapFeedback()
                            Task {
                                await notificationService.requestNotificationPermission()
                            }
                        }
                    } else if notificationService.authorizationStatus == .denied {
                        Button("Open Settings") {
                            hapticService.triggerButtonTapFeedback()
                            notificationService.openNotificationSettings()
                        }
                    }
                }
            }
            
            if notificationService.isNotificationsEnabled {
                Section("Notification Types") {
                    Toggle("Message Notifications", isOn: $appState.messageNotifications)
                        .onChange(of: appState.messageNotifications) { _ in
                            hapticService.triggerToggleFeedback()
                        }
                    
                    Toggle("System Notifications", isOn: $appState.systemNotifications)
                        .onChange(of: appState.systemNotifications) { _ in
                            hapticService.triggerToggleFeedback()
                        }
                    
                    Toggle("Notification Sounds", isOn: $appState.notificationSounds)
                        .onChange(of: appState.notificationSounds) { _ in
                            hapticService.triggerToggleFeedback()
                        }
                }
                
                Section("Notification Management") {
                    HStack {
                        Text("Pending Notifications")
                        Spacer()
                        Text("\(notificationService.pendingNotifications.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if !notificationService.pendingNotifications.isEmpty {
                        Button("Clear All Notifications") {
                            hapticService.triggerButtonTapFeedback()
                            Task {
                                await notificationService.cancelAllNotifications()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    
                    Button("Test Notification") {
                        hapticService.triggerButtonTapFeedback()
                        Task {
                            await notificationService.scheduleSystemNotification(
                                title: "Test Notification",
                                body: "This is a test notification from LLM Chat"
                            )
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func privacySettingsView() -> some View {
        List {
            Section("Data & Privacy") {
                NavigationLink("Export Data") {
                    DataExportView()
                }
                
                NavigationLink("Privacy Policy") {
                    WebView(url: URL(string: "https://openrouter.ai/privacy")!)
                }
                
                NavigationLink("Terms of Service") {
                    WebView(url: URL(string: "https://openrouter.ai/terms")!)
                }
            }
            
            Section("Data Management") {
                Button("Clear Cache") {
                    hapticService.triggerButtonTapFeedback()
                    clearCache()
                }
                
                Button("Clear Search History") {
                    hapticService.triggerButtonTapFeedback()
                    clearSearchHistory()
                }
                
                Button("Reset All Settings", role: .destructive) {
                    hapticService.triggerWarningFeedback()
                    showingAdvancedSettings = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetAllSettings() {
        appState.defaultModel = "anthropic/claude-3.5-sonnet"
        appState.defaultTemperature = 0.7
        appState.allowFallbacks = true
        appState.showTokenCount = true
        appState.showCostEstimates = true
        appState.isDarkMode = false
        
        hapticService.resetToDefaults()
        searchModelService.resetToDefaults()
        
        hapticService.triggerSuccessFeedback()
    }
    
    private func clearCache() {
        // Implementation for clearing cache
        hapticService.triggerSuccessFeedback()
    }
    
    private func clearSearchHistory() {
        // Implementation for clearing search history
        hapticService.triggerSuccessFeedback()
    }
    
    // MARK: - Alerts
    
    var alertsView: some View {
        EmptyView()
        .alert("API Key", isPresented: $showingAPIKeyAlert) {
            SecureField("sk-or-...", text: $newAPIKey)
            
            Button("Cancel", role: .cancel) {
                newAPIKey = ""
            }
            
            Button("Save") {
                Task {
                    await appState.setAPIKey(newAPIKey)
                    newAPIKey = ""
                }
            }
            .disabled(newAPIKey.isEmpty)
        } message: {
            Text("Enter your OpenRouter API key. You can get one from openrouter.ai/keys")
        }
        .alert("Remove API Key", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            
            Button("Remove", role: .destructive) {
                appState.removeAPIKey()
            }
        } message: {
            Text("Are you sure you want to remove your API key? You'll need to enter it again to use the app.")
        }
        .alert("Reset Settings", isPresented: $showingAdvancedSettings) {
            Button("Cancel", role: .cancel) {}
            
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
}

// MARK: - Supporting Types

enum SettingsTab: String, CaseIterable {
    case general = "general"
    case models = "models"
    case search = "search"
    case sync = "sync"
    case notifications = "notifications"
    case privacy = "privacy"
    
    var title: String {
        switch self {
        case .general: return "General"
        case .models: return "Models"
        case .search: return "Search"
        case .sync: return "Sync"
        case .notifications: return "Notifications"
        case .privacy: return "Privacy"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .models: return "cpu"
        case .search: return "magnifyingglass"
        case .sync: return "arrow.triangle.2.circlepath"
        case .notifications: return "bell"
        case .privacy: return "lock.shield"
        }
    }
}

// MARK: - Placeholder Views

struct SearchModelSelectionView: View {
    @EnvironmentObject var searchModelService: SearchModelConfigurationService
    
    var body: some View {
        List(searchModelService.availableSearchModels) { model in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    if model.id == searchModelService.currentSearchModel?.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(model.formattedPrice, systemImage: "dollarsign.circle")
                        .font(.caption)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        ForEach(model.strengths.prefix(3), id: \.self) { strength in
                            Image(systemName: strength.icon)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                searchModelService.setCurrentSearchModel(model)
            }
        }
        .navigationTitle("Search Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataExportView: View {
    var body: some View {
        VStack {
            Text("Data Export")
                .font(.title)
            Text("Export functionality will be implemented here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Export Data")
    }
}

struct WebView: View {
    let url: URL
    
    var body: some View {
        VStack {
            Text("Web View")
                .font(.title)
            Text("Web view for \(url.absoluteString) will be implemented here")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Web View")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}