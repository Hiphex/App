import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Group {
            if appState.hasValidAPIKey {
                ChatsListView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            appState.checkAPIKey()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .modelContainer(for: [
            Conversation.self,
            Message.self,
            Attachment.self,
            ModelInfo.self
        ])
}