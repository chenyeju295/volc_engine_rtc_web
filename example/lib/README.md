# Volc Engine RTC Web Demo

This example demonstrates how to use the `volc_engine_rtc_web` Flutter plugin to create an interactive voice conversation with an AI assistant.

## Getting Started

### Configuration

Before running the example, you need to set up your configuration:

1. Create a `config.json` file in the `lib` directory using the template below:

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

2. Replace the placeholder values with your actual API credentials.

### Running the App

```bash
cd example
flutter run -d chrome
```

This will launch the demo application in Chrome. The app demonstrates:

- Initializing the RTC AIGC plugin with configuration
- Joining/leaving a room
- Starting/stopping a conversation
- Sending text messages
- Displaying real-time subtitles
- Mute/unmute controls

## Features Demonstrated

- **Real-time Voice Recognition**: The app captures audio from your microphone and converts it to text
- **AI Conversation**: The text is processed by a large language model to generate responses
- **Text-to-Speech**: The AI responses are spoken back using text-to-speech technology
- **Subtitle Display**: All speech (both user and AI) is displayed as subtitles

## Implementation Details

The main implementation is in `main.dart`, which shows how to:

1. Load configuration from a JSON file
2. Initialize the plugin with the proper settings
3. Set up event listeners for various state changes
4. Handle user interactions with the AI assistant
5. Display real-time conversation data

This example follows best practices for security by keeping sensitive configuration in a separate file that is not committed to the repository. 