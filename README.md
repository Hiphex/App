# LLMChat - iOS AI Chat App

A fast, privacy-respecting iOS chat app that connects to hundreds of AI models through OpenRouter. Built with SwiftUI and SwiftData for iOS 17+.

## 🌟 Features

### Core Chat Experience
- **Native iOS Design**: Follows Human Interface Guidelines with subtle, tasteful theming
- **Real-time Streaming**: Live token streaming with typing indicators and smooth animations
- **Message Management**: Edit, delete, copy, share, multi-select, and reactions
- **Smart Search**: Full-text search across all conversations with filters
- **Conversation Management**: Pin favorites, archive old chats, swipe actions

### AI Model Access
- **Unified API**: Access 100+ models through OpenRouter's single API
- **Model Presets**: Quick selection with Speed, Balanced, Reasoning, and Vision presets
- **Smart Fallbacks**: Automatic failover if a provider is down
- **Usage Tracking**: Token count and cost estimation per message
- **Model Picker**: Browse and select from all available models with real-time metadata

### Multimodal Support
- **Vision**: Send images and PDFs to supported models
- **Voice**: Push-to-talk recording and TTS playback
- **Documents**: Support for photos, PDFs, and various file types
- **Media Preview**: Inline previews and thumbnails

### Privacy & Security
- **Keychain Storage**: Secure API key storage in iOS Keychain
- **No Data Collection**: Direct connection to OpenRouter, no intermediary servers
- **Privacy Manifest**: Full App Store compliance with required reason APIs
- **BYOK (Bring Your Own Key)**: Use your own OpenRouter API key

### Advanced Features
- **Tool Calling**: Extensible tool registry for calculator, web lookup, etc.
- **Export Options**: Export chats as Markdown or JSON
- **Share Extension**: "Ask AI about this" from Safari/Photos (planned)
- **Background Processing**: Continue long generations when app is backgrounded (planned)

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- OpenRouter API key ([get one here](https://openrouter.ai/keys))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/LLMChat.git
   cd LLMChat
   ```

2. **Open in Xcode**
   ```bash
   open LLMChat.xcodeproj
   ```

3. **Build and Run**
   - Select your target device or simulator
   - Press Cmd+R to build and run

4. **Setup API Key**
   - Launch the app
   - Enter your OpenRouter API key when prompted
   - The key is securely stored in iOS Keychain

### Configuration

The app uses SwiftData for local storage and requires no additional setup. All configuration is done through the Settings screen within the app.

## 🏗️ Architecture

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Local persistence and data modeling
- **URLSession**: Direct HTTP streaming to OpenRouter
- **Keychain Services**: Secure API key storage
- **Speech Framework**: Voice input and recognition
- **AVSpeechSynthesizer**: Text-to-speech output

### Project Structure
```
Sources/LLMChat/
├── App/                    # App entry point
├── Models/                 # SwiftData models
│   ├── Conversation.swift
│   ├── Message.swift
│   ├── Attachment.swift
│   └── ModelInfo.swift
├── Networking/             # OpenRouter API client
│   └── OpenRouterAPI.swift
├── Services/               # Core services
│   ├── AppState.swift
│   └── KeychainService.swift
├── Views/                  # SwiftUI views
│   ├── ContentView.swift
│   ├── OnboardingView.swift
│   ├── ChatsListView.swift
│   ├── ChatView.swift
│   ├── ModelPickerView.swift
│   └── SettingsView.swift
└── Resources/              # App resources
    ├── Info.plist
    └── PrivacyInfo.xcprivacy
```

### Data Flow
1. **User Input**: Message composed in ChatView
2. **API Request**: OpenRouterAPI creates streaming request
3. **Token Streaming**: Real-time token processing and UI updates
4. **Persistence**: SwiftData automatically saves conversation state
5. **State Management**: AppState coordinates global app state

## 🔧 OpenRouter Integration

### Supported Endpoints
- `GET /models` - Fetch available models and capabilities
- `POST /chat/completions` - Send messages with streaming support

### Request Features
- **Streaming**: Real-time token delivery with Server-Sent Events
- **Multimodal**: Image and document attachments via `image_url` content
- **Tool Calling**: Function calling with local tool execution
- **Fallbacks**: Provider redundancy with `models` array
- **Attribution**: Proper headers for OpenRouter analytics

### Example Request
```json
{
  "model": "anthropic/claude-3.5-sonnet",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What's in this image?"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,..."
          }
        }
      ]
    }
  ],
  "stream": true,
  "temperature": 0.7,
  "allow_fallbacks": true
}
```

## 🛠️ Development

### Building
```bash
# Debug build
xcodebuild -scheme LLMChat -configuration Debug

# Release build
xcodebuild -scheme LLMChat -configuration Release
```

### Testing
```bash
# Run unit tests
xcodebuild test -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain clear separation of concerns
- Add documentation for public APIs

## 📱 Usage

### First Launch
1. Open LLMChat
2. Tap "Get Key" to visit OpenRouter
3. Create account and generate API key
4. Return to app and enter key
5. Start chatting!

### Creating Conversations
- Tap the compose button (square with pencil)
- Select a model or use preset
- Type your message and tap send
- Watch as the AI responds in real-time

### Model Selection
- Tap the model name in the navigation bar
- Choose from presets (Speed, Balanced, Reasoning, Vision)
- Or browse all available models by provider
- Models are cached locally for offline browsing

### Settings
- Tap the gear icon in chat list
- Configure default temperature and model
- Toggle features like token counts and fallbacks
- Manage your API key
- Customize appearance

## 🔐 Privacy

LLMChat is designed with privacy as a core principle:

- **No Data Collection**: We don't collect, store, or transmit any personal data
- **Direct API Calls**: Your messages go directly to OpenRouter, not through our servers
- **Secure Storage**: API keys are stored in iOS Keychain with device-only access
- **Local Processing**: All app logic runs locally on your device
- **No Analytics**: No tracking, telemetry, or usage analytics

## 🚧 Roadmap

### Phase 1 (MVP) ✅
- [x] Core chat functionality
- [x] OpenRouter API integration
- [x] Model selection and presets
- [x] Secure key storage
- [x] Real-time streaming

### Phase 2 (Enhanced)
- [ ] Multimodal attachments (images, PDFs, voice)
- [ ] Tool calling infrastructure
- [ ] Message reactions and formatting
- [ ] Search and export features

### Phase 3 (Advanced)
- [ ] Background processing and notifications
- [ ] Share extension
- [ ] CloudKit sync across devices
- [ ] Advanced tool ecosystem

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 💬 Support

- **Documentation**: [OpenRouter Docs](https://openrouter.ai/docs)
- **Issues**: [GitHub Issues](https://github.com/yourusername/LLMChat/issues)
- **OpenRouter Support**: [OpenRouter Discord](https://discord.gg/openrouter)

## 🙏 Acknowledgments

- [OpenRouter](https://openrouter.ai) for providing unified AI model access
- The Swift and SwiftUI communities for excellent documentation and examples
- Apple for the robust iOS development platform

---

**Built with ❤️ for the iOS and AI communities**