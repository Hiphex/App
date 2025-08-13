import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var showingAPIKeyAlert = false
    @State private var newAPIKey = ""
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
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
                            showingAPIKeyAlert = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if appState.hasValidAPIKey {
                        Button("Remove API Key", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
                
                // Model Settings
                Section("Default Model Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temperature: \(appState.defaultTemperature, specifier: "%.1f")")
                        Slider(value: $appState.defaultTemperature, in: 0...2, step: 0.1)
                    }
                    
                    Toggle("Allow Fallbacks", isOn: $appState.allowFallbacks)
                }
                
                // Display Settings
                Section("Display") {
                    Toggle("Show Token Count", isOn: $appState.showTokenCount)
                    Toggle("Show Cost Estimates", isOn: $appState.showCostEstimates)
                }
                
                // Theme Settings
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $appState.isDarkMode)
                    
                    ColorPicker("Accent Color", selection: $appState.accentColor)
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}