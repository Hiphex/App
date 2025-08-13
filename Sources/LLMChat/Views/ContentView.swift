import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var showingOnboarding = false
    
    var body: some View {
        Group {
            if appState.hasValidAPIKey {
                ChatsListView()
                    .environmentObject(appState)
            } else {
                OnboardingView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            appState.checkAPIKey()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Conversation.self,
            Message.self,
            Attachment.self,
            ModelInfo.self
        ])
}