/// Options class for voice chat functionality
class VoiceChatOptions {
  /// Application ID
  final String appId;
  
  /// Business ID (optional)
  final String? businessId;
  
  /// Room ID
  final String roomId;
  
  /// Task ID
  final String taskId;
  
  /// Agent configuration
  final AgentConfig agentConfig;
  
  /// Voice chat configuration (optional)
  final VoiceChatConfig? config;
  
  /// Constructor
  VoiceChatOptions({
    required this.appId,
    this.businessId,
    required this.roomId,
    required this.taskId,
    required this.agentConfig,
    this.config,
  });
  
  /// Convert options to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'AppId': appId,
      'RoomId': roomId,
      'TaskId': taskId,
      'AgentConfig': agentConfig.toMap(),
    };
    
    if (businessId != null) {
      map['BusinessId'] = businessId;
    }
    
    if (config != null) {
      map['Config'] = config!.toMap();
    }
    
    return map;
  }
}

/// Configuration for voice chat agent
class AgentConfig {
  /// Target user IDs
  final List<String> targetUserIds;
  
  /// Welcome message
  final String welcomeMessage;
  
  /// User ID
  final String userId;
  
  /// Enable conversation state callback
  final bool? enableConversationStateCallback;
  
  /// Server message signature for RTS
  final String? serverMessageSignatureForRTS;
  
  /// Server message URL for RTS
  final String? serverMessageURLForRTS;
  
  /// Constructor
  AgentConfig({
    required this.targetUserIds,
    required this.welcomeMessage,
    required this.userId,
    this.enableConversationStateCallback,
    this.serverMessageSignatureForRTS,
    this.serverMessageURLForRTS,
  });
  
  /// Convert agent config to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'TargetUserId': targetUserIds,
      'WelcomeMessage': welcomeMessage,
      'UserId': userId,
    };
    
    if (enableConversationStateCallback != null) {
      map['EnableConversationStateCallback'] = enableConversationStateCallback;
    }
    
    if (serverMessageSignatureForRTS != null) {
      map['ServerMessageSignatureForRTS'] = serverMessageSignatureForRTS;
    }
    
    if (serverMessageURLForRTS != null) {
      map['ServerMessageURLForRTS'] = serverMessageURLForRTS;
    }
    
    return map;
  }
}

/// Configuration for voice chat
class VoiceChatConfig {
  /// Bot name (optional)
  final String? botName;
  
  /// ASR configuration (optional)
  final AsrConfig? asrConfig;
  
  /// TTS configuration (optional)
  final TtsConfig? ttsConfig;
  
  /// LLM configuration (optional)
  final LlmConfig? llmConfig;
  
  /// Constructor
  VoiceChatConfig({
    this.botName,
    this.asrConfig,
    this.ttsConfig,
    this.llmConfig,
  });
  
  /// Convert config to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {};
    
    if (botName != null) {
      map['BotName'] = botName;
    }
    
    if (asrConfig != null) {
      map['ASRConfig'] = asrConfig!.toMap();
    }
    
    if (ttsConfig != null) {
      map['TTSConfig'] = ttsConfig!.toMap();
    }
    
    if (llmConfig != null) {
      map['LLMConfig'] = llmConfig!.toMap();
    }
    
    return map;
  }
}

/// ASR (Automatic Speech Recognition) configuration
class AsrConfig {
  /// Application ID
  final String appId;
  
  /// Cluster (optional)
  final String? cluster;
  
  /// Constructor
  AsrConfig({
    required this.appId,
    this.cluster,
  });
  
  /// Convert ASR config to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'AppId': appId,
    };
    
    if (cluster != null) {
      map['Cluster'] = cluster;
    }
    
    return map;
  }
}

/// TTS (Text-to-Speech) configuration
class TtsConfig {
  /// Application ID
  final String appId;
  
  /// Voice type
  final String voiceType;
  
  /// Cluster (optional)
  final String? cluster;
  
  /// Ignore bracket text (optional)
  final List<int>? ignoreBracketText;
  
  /// Constructor
  TtsConfig({
    required this.appId,
    required this.voiceType,
    this.cluster,
    this.ignoreBracketText,
  });
  
  /// Convert TTS config to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'AppId': appId,
      'VoiceType': voiceType,
    };
    
    if (cluster != null) {
      map['Cluster'] = cluster;
    }
    
    if (ignoreBracketText != null) {
      map['IgnoreBracketText'] = ignoreBracketText;
    }
    
    return map;
  }
}

/// LLM (Large Language Model) configuration
class LlmConfig {
  /// Application ID
  final String appId;
  
  /// Model name (optional)
  final String? modelName;
  
  /// Model version
  final String modelVersion;
  
  /// Mode (optional)
  final String? mode;
  
  /// Host (optional)
  final String? host;
  
  /// Region (optional)
  final String? region;
  
  /// Maximum tokens (optional)
  final int? maxTokens;
  
  /// Minimum tokens (optional)
  final int? minTokens;
  
  /// Temperature (optional)
  final double? temperature;
  
  /// Top P (optional)
  final double? topP;
  
  /// Top K (optional)
  final int? topK;
  
  /// Maximum prompt tokens (optional)
  final int? maxPromptTokens;
  
  /// System messages (optional)
  final List<String>? systemMessages;
  
  /// User messages (optional)
  final List<String>? userMessages;
  
  /// History length (optional)
  final int? historyLength;
  
  /// Welcome speech (optional)
  final String? welcomeSpeech;
  
  /// Endpoint ID (optional)
  final String? endPointId;
  
  /// Bot ID (optional)
  final String? botId;
  
  /// Constructor
  LlmConfig({
    required this.appId,
    this.modelName,
    required this.modelVersion,
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
  
  /// Convert LLM config to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'AppId': appId,
      'ModelVersion': modelVersion,
    };
    
    if (modelName != null) {
      map['ModelName'] = modelName;
    }
    
    if (mode != null) {
      map['Mode'] = mode;
    }
    
    if (host != null) {
      map['Host'] = host;
    }
    
    if (region != null) {
      map['Region'] = region;
    }
    
    if (maxTokens != null) {
      map['MaxTokens'] = maxTokens;
    }
    
    if (minTokens != null) {
      map['MinTokens'] = minTokens;
    }
    
    if (temperature != null) {
      map['Temperature'] = temperature;
    }
    
    if (topP != null) {
      map['TopP'] = topP;
    }
    
    if (topK != null) {
      map['TopK'] = topK;
    }
    
    if (maxPromptTokens != null) {
      map['MaxPromptTokens'] = maxPromptTokens;
    }
    
    if (systemMessages != null) {
      map['SystemMessages'] = systemMessages;
    }
    
    if (userMessages != null) {
      map['UserMessages'] = userMessages;
    }
    
    if (historyLength != null) {
      map['HistoryLength'] = historyLength;
    }
    
    if (welcomeSpeech != null) {
      map['WelcomeSpeech'] = welcomeSpeech;
    }
    
    if (endPointId != null) {
      map['EndPointId'] = endPointId;
    }
    
    if (botId != null) {
      map['BotId'] = botId;
    }
    
    return map;
  }
}

/// Command options for updating voice chat
class VoiceChatCommandOptions {
  /// Application ID
  final String appId;
  
  /// Business ID (optional)
  final String? businessId;
  
  /// Room ID
  final String roomId;
  
  /// Task ID
  final String taskId;
  
  /// Command
  final String command;
  
  /// Message (optional)
  final String? message;
  
  /// Constructor
  VoiceChatCommandOptions({
    required this.appId,
    this.businessId,
    required this.roomId,
    required this.taskId,
    required this.command,
    this.message,
  });
  
  /// Convert command options to Map for JS interoperability
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'AppId': appId,
      'RoomId': roomId,
      'TaskId': taskId,
      'Command': command,
    };
    
    if (businessId != null) {
      map['BusinessId'] = businessId;
    }
    
    if (message != null) {
      map['Message'] = message;
    }
    
    return map;
  }
} 