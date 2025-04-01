# VolcEngine RTC Web Plugin

A Flutter plugin for integrating VolcEngine RTC Web SDK into Flutter web applications. This plugin enables audio and video communication features, as well as AI-powered voice chat functionality.

## Features

- Initialize VolcEngine RTC engine
- Join and leave voice/video rooms
- Control audio capture
- Publish and unpublish audio/video streams
- AI voice chat capabilities (start, update, stop)
- Event handling for various RTC events

## Getting Started

### Add Dependency

```yaml
dependencies:
  volc_engine_rtc_web: ^0.0.1
```

### Setup Web Integration

Add the VolcEngine RTC SDK script to your `web/index.html` file:

```html
<!-- VolcEngine RTC SDK -->
<script src="https://cdn.jsdelivr.net/npm/@volcengine/rtc@4.58.9/dist/index.min.js"></script>

<!-- Optional: VolcEngine RTC AIAns Extension -->
<script src="https://cdn.jsdelivr.net/npm/@volcengine/rtc/extension-ainr@latest/dist/index.min.js"></script>
```

For AI voice chat functionality, you need to add the OpenAPI client:

```html
<!-- OpenAPI Client Script -->
<script>
  // Define the openAPIs object for voice chat functionality
  window.openAPIs = {
    StartVoiceChat: async function(options) {
      // Implement your API call to the server
      console.log('StartVoiceChat called with options:', options);
      return 'session-id';
    },
    UpdateVoiceChat: async function(options) {
      // Implement your API call to the server
      console.log('UpdateVoiceChat called with options:', options);
      return 'update-result';
    },
    StopVoiceChat: async function(options) {
      // Implement your API call to the server
      console.log('StopVoiceChat called with options:', options);
      return 'stop-result';
    }
  };
</script>
```

## Basic Usage

```dart
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

// Initialize the plugin
final VolcEngineRtcWebPlatform plugin = VolcEngineRtcWebPlatform.instance;

// Initialize the engine
await plugin.initializeEngine('your_app_id');

// Join a room
await plugin.joinRoom('room_id', 'user_id', 'token'); // token is optional

// Start audio capture
await plugin.startAudioCapture();

// Publish audio stream
await plugin.publishStream(MediaType.AUDIO);

// Leave the room when done
await plugin.leaveRoom();
```

## AI Voice Chat

```dart
// Configure the agent
final agentConfig = AgentConfig(
  targetUserIds: ['user_id'],
  welcomeMessage: 'Hello, how can I help you?',
  userId: 'ai_assistant',
);

// Create options
final options = VoiceChatOptions(
  appId: 'your_app_id',
  roomId: 'room_id',
  taskId: 'user_id', // Task ID is typically user ID
  agentConfig: agentConfig,
);

// Start voice chat
final sessionId = await plugin.startVoiceChat(options.toMap());

// Update voice chat (send commands)
final commandOptions = VoiceChatCommandOptions(
  appId: 'your_app_id',
  roomId: 'room_id',
  taskId: 'user_id',
  command: VoiceChatCommands.INTERRUPT, // Available commands: STOP, RESUME, PAUSE, INTERRUPT
);
await plugin.updateVoiceChat(sessionId, commandOptions.toMap());

// Stop voice chat
await plugin.stopVoiceChat(sessionId);
```

## Event Handling

Create an event handler and register it with the engine:

```dart
final handler = RtcEventHandler(
  onUserJoined: (event) {
    print('User joined: ${event['userId']}');
  },
  onUserLeave: (event) {
    print('User left: ${event['userId']}');
  },
  // Add more handlers as needed
);

// Register with the engine (typically in a class that extends VolcEngineRtcWeb)
handler.registerWith(engine, vertc);
```

## Constants

The plugin provides various constants for use with the VolcEngine RTC SDK:

- `MediaType`: Constants for audio/video media types
- `StreamIndex`: Constants for stream indices
- `RoomProfileType`: Constants for room profile types
- `VoiceChatCommands`: Constants for voice chat commands
- And more...

## License

This plugin is released under the BSD-3-Clause license. See the LICENSE file for details.

[VolcEngine RTC  场景搭建（Web)](https://www.volcengine.com/docs/6348/1310560)

[VolcEngine RTC 快速入门（Web)](https://www.volcengine.com/docs/6348/77374)

[VolcEngine RTC  web SDK 文档)](https://www.volcengine.com/docs/6348/104477)

