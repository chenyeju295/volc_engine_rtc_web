# Volc Engine RTC Web Plugin for Flutter

A Flutter plugin for integrating Volc Engine RTC with AIGC capabilities, enabling interactive real-time voice conversations with AI assistants in Flutter Web applications.

[![pub package](https://img.shields.io/pub/v/volc_engine_rtc_web.svg)](https://pub.dev/packages/volc_engine_rtc_web)

## Features

- Real-time voice recognition (ASR)
- AI conversation using large language models (LLM)
- Text-to-speech synthesis (TTS)
- Two-way conversation capabilities
- Integration with Volcano Engine RTC SDK

## Installation

Add the package to your pubspec.yaml:

```yaml
dependencies:
  volc_engine_rtc_web: ^0.1.0
```

## Configuration

This plugin requires configuration for RTC, ASR, TTS, and LLM services. For security purposes, sensitive configuration values should be stored in a separate config.json file that is not committed to your repository.

### Setting up config.json

1. Create a `config.json` file in your project's `lib` directory:

```json
{
  "appId": "YOUR_APP_ID",
  "baseUrl": "YOUR_BASE_URL",
  "appKey": "YOUR_APP_KEY",
  "llm": {
    "endPointId": "YOUR_ENDPOINT_ID"
  },
  "tts": {
    "appid": "YOUR_TTS_APP_ID"
  },
  "asr": {
    "appId": "YOUR_ASR_APP_ID"
  }
}
```

2. Add this file to your `.gitignore` to prevent it from being committed:

```
# Configuration files containing sensitive information
lib/config.json
```

3. Add the file to your assets in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - lib/config.json
```

4. Create a `config.template.json` file with placeholder values as a reference for other developers.

## Basic Usage

### Initialize the Plugin

Load the configuration from the config.json file and initialize the plugin:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

Future<void> initializeRtcAigc() async {
  try {
    // Load configuration from JSON file
    final String configString = await rootBundle.loadString('lib/config.json');
    final config = json.decode(configString);
    
    // Set up the AIGC configuration
    final aigcConfig = AigcConfig(
      appId: config['appId'],
      roomId: 'room1',  // Can be dynamically generated or from config
      taskId: 'user1',  // Should be user-specific
      agentConfig: AgentConfig(
        userId: 'ChatBot01',
        welcomeMessage: 'Hello, how can I help you today?',
        targetUserId: ['user1'],
      ),
      config: Config(
        lLMConfig: LlmConfig(
          mode: 'ArkV3',
          endPointId: config['llm']['endPointId'],
        ),
        tTSConfig: TtsConfig(
          provider: 'volcano',
          providerParams: ProviderParams(
            app: App(
              appid: config['tts']['appid'], 
              cluster: 'volcano_tts'
            ),
            audio: Audio(
              voiceType: 'BV001_streaming'
            ),
          ),
        ),
        aSRConfig: AsrConfig(
          provider: 'volcano',
          providerParams: AsrProviderParams(
            mode: 'smallmodel',
            appId: config['asr']['appId'],
            cluster: 'volcengine_streaming_common',
          ),
        ),
      ),
    );

    // Initialize the plugin
    final success = await RtcAigcPlugin.initialize(
      baseUrl: config['baseUrl'],
      config: aigcConfig,
      appKey: config['appKey'],
    );
    
    if (success) {
      print('RTC AIGC Plugin initialized successfully');
    } else {
      print('Failed to initialize RTC AIGC Plugin');
    }
  } catch (e) {
    print('Error initializing RTC AIGC Plugin: $e');
  }
}
```

### Join a Room

```dart
final success = await RtcAigcPlugin.joinRoom();
if (success) {
  print('Joined room successfully');
} else {
  print('Failed to join room');
}
```

### Start a Conversation

```dart
final success = await RtcAigcPlugin.startConversation();
if (success) {
  print('Conversation started successfully');
} else {
  print('Failed to start conversation');
}
```

### Send a Text Message

```dart
await RtcAigcPlugin.sendTextMessage('Hello AI assistant');
```

### Listening to Subtitles

```dart
RtcAigcPlugin.subtitleStream.listen((subtitle) {
  print('Subtitle: ${subtitle.text}, Final: ${subtitle.definite}');
}, onError: (error) {
  print('Subtitle stream error: $error');
});
```

### Managing Microphone

```dart
// Check for device permissions
final permissionResult = await RtcAigcPlugin.enableDevices(audio: true);
if (permissionResult['audio'] == true) {
  print('Microphone access granted');
} else {
  print('Microphone access denied');
}

// Mute/unmute
final muteResult = await RtcAigcPlugin.muteAudio(true); // Mute
final unmuteResult = await RtcAigcPlugin.muteAudio(false); // Unmute
```

### End Session

```dart
// Stop conversation
await RtcAigcPlugin.stopConversation();

// Leave room
await RtcAigcPlugin.leaveRoom();

// Clean up resources
RtcAigcPlugin.dispose();
```

## Example App

See the [example](./example) directory for a complete Flutter app that demonstrates all features.

## API Reference

For a complete list of available methods and classes, see the [API documentation](https://pub.dev/documentation/volc_engine_rtc_web/latest/).

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 