# RTC AIGC Plugin for Flutter Web

A Flutter plugin for integrating AIGC-RTC interactive conversation capabilities in web applications.

## Features

- Real-time voice recognition (ASR)
- AI conversation using large language models (LLM)
- Text-to-speech synthesis (TTS)
- Two-way conversation capabilities
- Integration with Volcano Engine RTC SDK

## Getting Started

### Installation

Add this package to your Flutter project by adding the following to your `pubspec.yaml`:

```yaml
dependencies:
  rtc_aigc_plugin: ^0.1.0
```

Or depend on the package from your Git repository:

```yaml
dependencies:
  rtc_aigc_plugin:
    git:
      url: https://github.com/your-username/rtc_aigc_plugin.git
```

### SDK Integration

This plugin automatically loads the Volcano Engine RTC SDK from CDN:
```
https://lf-unpkg.volccdn.com/obj/vcloudfe/sdk/@volcengine/rtc/4.66.1/1741254642340/volengine_Web_4.66.1.js
```

No additional setup is needed for the SDK integration.

### Prerequisites

Before using this plugin, you need to obtain the following credentials from the Volcano Engine:

1. RTC Application ID and Token
2. ASR Application ID
3. TTS Application ID
4. Ark Model ID from Volcano Engine Ark Online Inference

## Usage

### Initialize the Plugin

You can initialize the plugin using individual configuration parameters:

```dart
await RtcAigcPlugin.initialize(
  appId: 'your_app_id',
  roomId: 'test_room',
  userId: 'test_user',
  token: 'your_rtc_token',
  serverUrl: 'https://your-server.com',
  asrConfig: AsrConfig(
    appId: 'your_asr_app_id',
    cluster: 'volcengine_streaming_common',
  ),
  ttsConfig: TtsConfig(
    appId: 'your_tts_app_id',
    voiceType: 'volcano_tts',
  ),
  llmConfig: LlmConfig(
    modelName: 'ArkV3',
    endPointId: 'your_ark_model_id',
    maxTokens: 1024,
    temperature: 0.1,
    topP: 0.3,
    systemMessages: ["你是AI助手，善于帮助用户解决问题。"],
  ),
  onStateChange: (state, message) {
    print('State changed: $state, $message');
  },
  onMessage: (text, isUser) {
    print('${isUser ? "User" : "AI"} message: $text');
  },
  onAudioStatusChange: (isActive) {
    print('AI is speaking: $isActive');
  },
);
```

### Initialize with AigcConfig

Alternatively, you can use the `AigcConfig` class for more comprehensive configuration:

```dart
// Create AIGC configuration
final aigcConfig = AigcConfig(
  appId: 'your_app_id',
  roomId: 'room1',
  taskId: 'task1',
  agentConfig: AgentConfig(
    userId: 'RobotMan_',
    welcomeMessage: '你好，我是你的AI小助手，有什么可以帮你的吗？',
    enableConversationStateCallback: true,
    serverMessageSignatureForRTS: 'conversation',
    targetUserId: ['user1'],
  ),
  config: Config(
    lLMConfig: LlmConfig(
      mode: 'ArkV3',
      endPointId: 'your_endpoint_id',
      maxTokens: 1024,
      temperature: 0.1,
      topP: 0.3,
      systemMessages: ["你是AI助手，善于帮助用户解决问题。"],
      modelName: 'ArkV3',
    ),
    tTSConfig: TtsConfig(
      provider: 'volcano',
      providerParams: ProviderParams(
        appId: 'your_tts_app_id',
        cluster: 'volcano_tts',
      ),
    ),
    aSRConfig: AsrConfig(
      provider: 'volcano',
      providerParams: ProviderParams(
        mode: 'smallmodel',
        appId: 'your_asr_app_id',
        cluster: 'volcengine_streaming_common',
      ),
    ),
  ),
);

// Initialize with AigcConfig
await RtcAigcPlugin.initializeWithAigcConfig(
  aigcConfig: aigcConfig,
  userId: 'user1',  // Client-specific user ID
  token: 'your_rtc_token',  // Client-specific token
  serverUrl: 'https://your-server.com',
  onStateChange: (state, message) {
    print('State changed: $state, $message');
  },
  onMessage: (text, isUser) {
    print('${isUser ? "User" : "AI"} message: $text');
  },
  onAudioStatusChange: (isActive) {
    print('AI is speaking: $isActive');
  },
);
```

### Start a Conversation

To start a voice conversation (requires microphone access):

```dart
final success = await RtcAigcPlugin.startConversation();
if (success) {
  print('Conversation started successfully');
} else {
  print('Failed to start conversation');
}
```

### Send a Text Message

To send a text message without using voice:

```dart
await RtcAigcPlugin.sendTextMessage('Hello AI assistant');
```

### Stop a Conversation

To stop the current conversation:

```dart
await RtcAigcPlugin.stopConversation();
```

### Cleanup

When you're done using the plugin, release resources:

```dart
await RtcAigcPlugin.dispose();
```

## Complete Example

See the [example](./example) folder for a complete example application.

## Troubleshooting

### Common Issues

1. **Microphone Access Denied**
   
   Ensure your web application requests and receives permissions for microphone access.

2. **Token Error**

   Verify that your RTC token is valid and matches the roomId and userId used during initialization.

3. **Server Connection Failed**

   Check that your server URL is correct and the server is accessible from the client.

4. **SDK Loading Failed**

   If you encounter issues with SDK loading from CDN, check your network connection and make sure the CDN URL is accessible.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Recent Code Optimizations

The plugin has undergone several optimizations to improve code quality and maintainability:

### 1. Unified Stream Organization
- Streams are now organized into logical groups (messages, audio, status, RTC events)
- Eliminated redundant stream definitions
- Added clear section headers for better code readability

### 2. Standard Method Naming Conventions
- Replaced inconsistent method aliases with standardized names
- Updated method signatures for consistency
- Deprecated older method names with proper annotations

### 3. Removed Redundant Code
- Eliminated the redundant `content` parameter in `RtcAigcMessage` class
- Removed commented-out code
- Un-commented and properly named the `RtcConnectionState` enum

### 4. Enhanced Error Handling
- Added consistent error handling patterns
- Improved error reporting through dedicated helper methods
- Added descriptive debug logging

### 5. Code Documentation
- Updated method documentation to match implementation
- Added clear documentation for all public APIs
- Improved comments for better code understanding

## Architecture Refactoring

The plugin architecture has been completely refactored to improve performance and eliminate unnecessary complexity:

### 1. Eliminated Redundant Method Channel Communication
- Removed unnecessary method channel communication between Dart files
- Directly use the ServiceManager instead of going through method channels for web platform
- Preserved method channels only for native platform communication (iOS/Android)

### 2. Simplified Plugin Structure
- Removed the singleton pattern for more direct static method access
- Eliminated the separate web implementation file dependency
- Consolidated stream controllers and event handling in a single location

### 3. Improved API Design
- Created a cleaner, more intuitive API surface with named parameters
- Enhanced error handling with consistent patterns
- Added proper type safety to all stream definitions

### 4. Better Event Handling
- Added direct event listeners to service manager events
- Implemented unified event broadcasting for both web and native platforms
- Reduced latency by eliminating unnecessary serialization/deserialization

### 5. Enhanced Platform Detection
- Used proper platform checks for web-specific functionality
- Improved initialization process with appropriate bindings
- Added graceful fallbacks for cross-platform usage

This refactoring results in:
- More efficient communication between components
- Reduced code complexity and better maintainability
- Improved debugging experience with clearer code paths
- Better performance by eliminating unnecessary indirection 