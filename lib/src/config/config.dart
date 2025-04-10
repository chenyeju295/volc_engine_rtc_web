import 'dart:math';

//{
//     "AppId": "67f3871435d851017835d866",
//     "RoomId": "room1",
//     "TaskId": "user1",
//     "AgentConfig": {
//         "UserId": "RobotMan_",
//         "WelcomeMessage": "你好，我是你的AI小助手，有什么可以帮你的吗？",
//         "EnableConversationStateCallback": true,
//         "ServerMessageSignatureForRTS": "conversation",
//         "TargetUserId": [
//             "user1"
//         ]
//     },
//     "Config": {
//         "LLMConfig": {
//             "Mode": "ArkV3",
//             "EndPointId": "ep-20250401160533-rr59m",
//             "MaxTokens": 1024,
//             "Temperature": 0.1,
//             "TopP": 0.3,
//             "SystemMessages": [
//                 "##人设\n你是一个全能智能体，拥有丰富的百科知识，可以为人们答疑解惑，解决问题。\n你性格很温暖，喜欢帮助别人，非常热心。\n\n##技能\n1. 当用户询问某一问题时，利用你的知识进行准确回答。回答内容应简洁明了，易于理解。\n2. 当用户想让你创作时，比如讲一个故事，或者写一首诗，你创作的文本主题要围绕用户的主题要求，确保内容具有逻辑性、连贯性和可读性。除非用户对创作内容有特殊要求，否则字数不用太长。\n3. 当用户想让你对于某一事件发表看法，你要有一定的见解和建议，但是也要符合普世的价值观。"
//             ],
//             "Prefill": true,
//             "ModelName": "Doubao-pro-32k",
//             "ModelVersion": "1.0",
//             "WelcomeSpeech": "你好，我是你的AI小助手，有什么可以帮你的吗？",
//             "ModeSourceType": "Available",
//             "APIKey": "",
//             "Url": "",
//             "Feature": "{\"Http\":true}"
//         },
//         "TTSConfig": {
//             "Provider": "volcano",
//             "ProviderParams": {
//                 "app": {
//                     "AppId": "4799544484",
//                     "Cluster": "volcano_tts"
//                 },
//                 "audio": {
//                     "voice_type": "BV001_streaming",
//                     "speed_ratio": 1
//                 }
//             },
//             "IgnoreBracketText": [
//                 1,
//                 2,
//                 3,
//                 4,
//                 5
//             ]
//         },
//         "ASRConfig": {
//             "Provider": "volcano",
//             "ProviderParams": {
//                 "Mode": "smallmodel",
//                 "AppId": "4799544484",
//                 "Cluster": "volcengine_streaming_common"
//             },
//             "VADConfig": {
//                 "SilenceTime": 600,
//                 "SilenceThreshold": 200
//             },
//             "VolumeGain": 0.3
//         },
//         "InterruptMode": 0,
//         "SubtitleConfig": {
//             "SubtitleMode": 0
//         }
//     }
// }
/// ASR (Automatic Speech Recognition) configuration
class AsrConfig {
  /// Application ID for ASR
  final String appId;

  /// Cluster for ASR service
  final String? cluster;

  /// WebSocket endpoint for ASR service
  final String? wsEndpoint;

  /// ASR configuration
  const AsrConfig({
    this.appId = "default_asr_app_id",
    this.cluster,
    this.wsEndpoint,
  });

  /// Convert configuration to map
  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      if (cluster != null) 'cluster': cluster,
      if (wsEndpoint != null) 'wsEndpoint': wsEndpoint,
    };
  }

  /// Create from map
  factory AsrConfig.fromMap(Map<String, dynamic> map) {
    return AsrConfig(
      appId: map['appId'] ?? "default_asr_app_id",
      cluster: map['cluster'],
      wsEndpoint: map['wsEndpoint'],
    );
  }
}

/// TTS (Text-to-Speech) configuration
class TtsConfig {
  /// Application ID for TTS
  final String appId;

  /// Voice type for TTS (e.g., male, female)
  final String? voiceType;

  /// Cluster for TTS service
  final String? cluster;

  /// Whether to ignore text in brackets
  final bool? ignoreBracketText;

  /// TTS configuration
  const TtsConfig({
    this.appId = "default_tts_app_id",
    this.voiceType,
    this.cluster,
    this.ignoreBracketText,
  });

  /// Convert configuration to map
  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      if (voiceType != null) 'voiceType': voiceType,
      if (cluster != null) 'cluster': cluster,
      if (ignoreBracketText != null) 'ignoreBracketText': ignoreBracketText,
    };
  }

  /// Create from map
  factory TtsConfig.fromMap(Map<String, dynamic> map) {
    return TtsConfig(
      appId: map['appId'] ?? "default_tts_app_id",
      voiceType: map['voiceType'],
      cluster: map['cluster'],
      ignoreBracketText: map['ignoreBracketText'],
    );
  }
}

/// LLM (Large Language Model) configuration
class LlmConfig {
  /// Model name
  final String? modelName;

  /// Model version
  final String? modelVersion;

  /// Mode (e.g., chat, completion)
  final String? mode;

  /// Host for LLM API
  final String? host;

  /// Region for LLM API
  final String? region;

  /// Maximum tokens to generate
  final int? maxTokens;

  /// Minimum tokens to generate
  final int? minTokens;

  /// Temperature for sampling
  final double? temperature;

  /// Top-p for sampling
  final double? topP;

  /// Top-k for sampling
  final int? topK;

  /// Maximum prompt tokens
  final int? maxPromptTokens;

  /// System messages for chat
  final List<String>? systemMessages;

  /// User messages for chat
  final List<String>? userMessages;

  /// History length to consider
  final int? historyLength;

  /// Welcome speech
  final String? welcomeSpeech;

  /// Endpoint ID
  final String? endPointId;

  /// Bot ID
  final String? botId;

  /// LLM configuration
  const LlmConfig({
    this.modelName,
    this.modelVersion,
    this.mode,
    this.host,
    this.region,
    this.maxTokens,
    this.minTokens,
    this.temperature,
    this.topP,
    this.topK,
    this.maxPromptTokens,
    this.systemMessages,
    this.userMessages,
    this.historyLength,
    this.welcomeSpeech,
    this.endPointId,
    this.botId,
  });

  /// Convert configuration to map
  Map<String, dynamic> toMap() {
    return {
      if (modelName != null) 'modelName': modelName,
      if (modelVersion != null) 'modelVersion': modelVersion,
      if (mode != null) 'mode': mode,
      if (host != null) 'host': host,
      if (region != null) 'region': region,
      if (maxTokens != null) 'maxTokens': maxTokens,
      if (minTokens != null) 'minTokens': minTokens,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (topK != null) 'topK': topK,
      if (maxPromptTokens != null) 'maxPromptTokens': maxPromptTokens,
      if (systemMessages != null) 'systemMessages': systemMessages,
      if (userMessages != null) 'userMessages': userMessages,
      if (historyLength != null) 'historyLength': historyLength,
      if (welcomeSpeech != null) 'welcomeSpeech': welcomeSpeech,
      if (endPointId != null) 'endPointId': endPointId,
      if (botId != null) 'botId': botId,
    };
  }

  /// Create from map
  factory LlmConfig.fromMap(Map<String, dynamic> map) {
    return LlmConfig(
      modelName: map['modelName'],
      modelVersion: map['modelVersion'],
      mode: map['mode'],
      host: map['host'],
      region: map['region'],
      maxTokens: map['maxTokens'],
      minTokens: map['minTokens'],
      temperature: map['temperature'],
      topP: map['topP'],
      topK: map['topK'],
      maxPromptTokens: map['maxPromptTokens'],
      systemMessages: map['systemMessages'] != null
          ? List<String>.from(map['systemMessages'])
          : null,
      userMessages: map['userMessages'] != null
          ? List<String>.from(map['userMessages'])
          : null,
      historyLength: map['historyLength'],
      welcomeSpeech: map['welcomeSpeech'],
      endPointId: map['endPointId'],
      botId: map['botId'],
    );
  }
}

/// Configuration for RTC service
class RtcConfig {
  /// Application ID
  final String appId;

  /// Business ID (optional)
  final String? businessId;

  /// Room ID
  final String roomId;

  /// User ID
  final String userId;

  /// Token
  final String token;

  /// Task ID
  final String taskId;

  /// Server URL for HTTP API
  final String serverUrl;

  final AsrConfig asrConfig;

  final TtsConfig ttsConfig;

  final LlmConfig llmConfig;

  /// Welcome message
  final String? welcomeMessage;

  /// Whether to process all messages, including non-AI messages
  final bool? processAllMessages;

  /// RTC configuration for real-time communications
  const RtcConfig({
    required this.appId,
    required this.roomId,
    required this.userId,
    required this.token,
    required this.asrConfig,
    required this.ttsConfig,
    required this.llmConfig,
    required this.taskId,
    required this.serverUrl,
    this.businessId,
    this.welcomeMessage = "你好，我是AI助手，有什么我可以帮您的吗？",
    this.processAllMessages = false,
  });

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      'roomId': roomId,
      'userId': userId,
      'token': token,
      'asrConfig': asrConfig.toMap(),
      'ttsConfig': ttsConfig.toMap(),
      'llmConfig': llmConfig.toMap(),
      'taskId': taskId,
      if (serverUrl != null) 'serverUrl': serverUrl,
      if (businessId != null) 'businessId': businessId,
      if (welcomeMessage != null) 'welcomeMessage': welcomeMessage,
      if (processAllMessages != null) 'processAllMessages': processAllMessages,
    };
  }

  /// Create from map
  factory RtcConfig.fromMap(Map<String, dynamic> map) {
    return RtcConfig(
      appId: map['appId'],
      roomId: map['roomId'],
      userId: map['userId'],
      token: map['token'],
      taskId: map['taskId'],
      serverUrl: map['serverUrl'],
      asrConfig: AsrConfig.fromMap(map['asrConfig']),
      ttsConfig: TtsConfig.fromMap(map['ttsConfig']),
      llmConfig: LlmConfig.fromMap(map['llmConfig']),
      businessId: map['businessId'],
      welcomeMessage: map['welcomeMessage'],
      processAllMessages: map['processAllMessages'],
    );
  }

  /// Clone with updates
  RtcConfig copyWith({
    String? appId,
    String? roomId,
    String? userId,
    String? token,
    String? taskId,
    String? serverUrl,
    AsrConfig? asrConfig,
    TtsConfig? ttsConfig,
    LlmConfig? llmConfig,
    String? businessId,
    String? welcomeMessage,
    bool? processAllMessages,
  }) {
    return RtcConfig(
      appId: appId ?? this.appId,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      taskId: taskId ?? this.taskId,
      serverUrl: serverUrl ?? this.serverUrl,
      asrConfig: asrConfig ?? this.asrConfig,
      ttsConfig: ttsConfig ?? this.ttsConfig,
      llmConfig: llmConfig ?? this.llmConfig,
      businessId: businessId ?? this.businessId,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      processAllMessages: processAllMessages ?? this.processAllMessages,
    );
  }
}

/// Main configuration for AIGC RTC services
class AigcRtcConfig {
  /// Application ID
  final String appId;

  /// RTC configuration
  final RtcConfig rtcConfig;

  /// ASR configuration
  final AsrConfig asrConfig;

  /// TTS configuration
  final TtsConfig ttsConfig;

  /// WebSocket URL (可选，仅在使用WebSocket服务时指定)
  final String? websocketUrl;

  /// Server URL for HTTP API (推荐使用HTTP服务)
  final String? serverUrl;

  /// AIGC RTC configuration
  const AigcRtcConfig({
    required this.appId,
    required this.rtcConfig,
    required this.asrConfig,
    required this.ttsConfig,
    this.websocketUrl,
    this.serverUrl,
  });

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      'rtcConfig': rtcConfig.toMap(),
      'asrConfig': asrConfig.toMap(),
      'ttsConfig': ttsConfig.toMap(),
      if (websocketUrl != null) 'websocketUrl': websocketUrl,
      if (serverUrl != null) 'serverUrl': serverUrl,
    };
  }

  /// Create from map
  factory AigcRtcConfig.fromMap(Map<String, dynamic> map) {
    return AigcRtcConfig(
      appId: map['appId'],
      rtcConfig: RtcConfig.fromMap(map['rtcConfig']),
      asrConfig: AsrConfig.fromMap(map['asrConfig']),
      ttsConfig: TtsConfig.fromMap(map['ttsConfig']),
      websocketUrl: map['websocketUrl'],
      serverUrl: map['serverUrl'],
    );
  }

  /// Clone with updates
  AigcRtcConfig copyWith({
    String? appId,
    RtcConfig? rtcConfig,
    AsrConfig? asrConfig,
    TtsConfig? ttsConfig,
    String? websocketUrl,
    String? serverUrl,
  }) {
    return AigcRtcConfig(
      appId: appId ?? this.appId,
      rtcConfig: rtcConfig ?? this.rtcConfig,
      asrConfig: asrConfig ?? this.asrConfig,
      ttsConfig: ttsConfig ?? this.ttsConfig,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

/// Server authentication configuration
class ServerAuthConfig {
  /// Access key for server authentication
  final String accessKey;

  /// Secret key for server authentication
  final String secretKey;

  /// Session token (required for sub-accounts)
  final String? sessionToken;

  /// Server authentication configuration
  const ServerAuthConfig({
    required this.accessKey,
    required this.secretKey,
    this.sessionToken,
  });
}
