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