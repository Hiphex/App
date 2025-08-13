import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var apiKey = ""
    @State private var showingHelp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to LLMChat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Connect to hundreds of AI models through OpenRouter")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // API Key Section
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("OpenRouter API Key")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Get Key") {
                                if let url = URL(string: "https://openrouter.ai/keys") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        SecureField("sk-or-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    if let error = appState.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        Task {
                            await appState.setAPIKey(apiKey)
                        }
                    }) {
                        HStack {
                            if appState.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(appState.isLoading ? "Validating..." : "Continue")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(apiKey.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(apiKey.isEmpty || appState.isLoading)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Help Section
                VStack(spacing: 12) {
                    Button("Why do I need an API key?") {
                        showingHelp = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    
                    Text("Your key is stored securely in iOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About OpenRouter")
                            .font(.headline)
                        
                        Text("OpenRouter provides unified access to hundreds of AI models from providers like OpenAI, Anthropic, Google, and many others through a single API.")
                        
                        Text("Benefits:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Access to the latest models without multiple API keys")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Automatic fallbacks if a provider is down")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Competitive pricing and pay-per-use")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("No subscriptions required")
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy & Security")
                            .font(.headline)
                        
                        Text("Your API key is stored securely in iOS Keychain and never leaves your device. LLMChat connects directly to OpenRouter without any intermediary servers.")
                        
                        Text("All conversations are processed by OpenRouter and the AI providers according to their respective privacy policies.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting Started")
                            .font(.headline)
                        
                        Text("1. Visit openrouter.ai/keys to create an account and generate an API key")
                        Text("2. Add some credits to your account (usually $5-10 is plenty to start)")
                        Text("3. Copy your API key and paste it in the app")
                        Text("4. Start chatting with any AI model!")
                    }
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}