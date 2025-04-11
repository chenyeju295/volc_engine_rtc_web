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

Initialize the plugin with your credentials and register callbacks for events:

```dart
await RtcAigcPlugin.initialize(
  appId: 'your_app_id',
  roomId: 'test_room',
  userId: 'test_user',
  token: 'your_rtc_token',
  asrAppId: 'your_asr_app_id',
  ttsAppId: 'your_tts_app_id',
  serverUrl: 'https://your-server.com',
  arkModelId: 'your_ark_model_id',
  onUserSpeechRecognized: (text) {
    print('User said: $text');
  },
  onAiResponseReceived: (text) {
    print('AI responded: $text');
  },
  onSpeechStateChanged: (isActive) {
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