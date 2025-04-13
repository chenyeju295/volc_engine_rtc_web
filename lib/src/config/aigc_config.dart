import 'dart:convert';

/// AppId : "67f3871435d851017835d866"
/// RoomId : "room1"
/// TaskId : "user1"
/// AgentConfig : {"UserId":"RobotMan_","WelcomeMessage":"你好，我是你的AI小助手，有什么可以帮你的吗？","EnableConversationStateCallback":true,"ServerMessageSignatureForRTS":"conversation","TargetUserId":["user1"]}
/// Config : {"LLMConfig":{"Mode":"ArkV3","EndPointId":"ep-20250401160533-rr59m","MaxTokens":1024,"Temperature":0.1,"TopP":0.3,"SystemMessages":["##人设\n你是一个全能智能体，拥有丰富的百科知识，可以为人们答疑解惑，解决问题。\n你性格很温暖，喜欢帮助别人，非常热心。\n\n##技能\n1. 当用户询问某一问题时，利用你的知识进行准确回答。回答内容应简洁明了，易于理解。\n2. 当用户想让你创作时，比如讲一个故事，或者写一首诗，你创作的文本主题要围绕用户的主题要求，确保内容具有逻辑性、连贯性和可读性。除非用户对创作内容有特殊要求，否则字数不用太长。\n3. 当用户想让你对于某一事件发表看法，你要有一定的见解和建议，但是也要符合普世的价值观。"],"Prefill":true,"ModelName":"Doubao-pro-32k","ModelVersion":"1.0","WelcomeSpeech":"你好，我是你的AI小助手，有什么可以帮你的吗？","ModeSourceType":"Available","APIKey":"","Url":"","Feature":"{\"Http\":true}"},"TTSConfig":{"Provider":"volcano","ProviderParams":{"app":{"AppId":"4799544484","Cluster":"volcano_tts"},"audio":{"voice_type":"BV001_streaming","speed_ratio":1}},"IgnoreBracketText":[1,2,3,4,5]},"ASRConfig":{"Provider":"volcano","ProviderParams":{"Mode":"smallmodel","AppId":"4799544484","Cluster":"volcengine_streaming_common"},"VADConfig":{"SilenceTime":600,"SilenceThreshold":200},"VolumeGain":0.3},"InterruptMode":0,"SubtitleConfig":{"SubtitleMode":0}}

AigcConfig aigcConfigFromJson(String str) =>
    AigcConfig.fromJson(json.decode(str));
String aigcConfigToJson(AigcConfig data) => json.encode(data.toJson());

class AigcConfig {
  AigcConfig({
    this.appId,
    this.roomId,
    this.taskId,
    this.agentConfig,
    this.serverUrl,
    this.token,
    this.config,
  });

  AigcConfig.fromJson(dynamic json) {
    appId = json['AppId'];
    roomId = json['RoomId'];
    taskId = json['TaskId'];
    serverUrl = json['ServerUrl'];
    token = json['Token'];
    agentConfig = json['AgentConfig'] != null
        ? AgentConfig.fromJson(json['AgentConfig'])
        : null;
    config = json['Config'] != null ? Config.fromJson(json['Config']) : null;
  }
  String? appId;
  String? roomId;
  String? taskId;
  String? serverUrl;
  AgentConfig? agentConfig;
  Config? config;
  String? token;
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['AppId'] = appId;
    map['RoomId'] = roomId;
    map['TaskId'] = taskId;
    map['Token'] = token;
    map['ServerUrl'] = serverUrl;
    if (agentConfig != null) {
      map['AgentConfig'] = agentConfig?.toJson();
    }
    if (config != null) {
      map['Config'] = config?.toJson();
    }
    return map;
  }
}

/// LLMConfig : {"Mode":"ArkV3","EndPointId":"ep-20250401160533-rr59m","MaxTokens":1024,"Temperature":0.1,"TopP":0.3,"SystemMessages":["##人设\n你是一个全能智能体，拥有丰富的百科知识，可以为人们答疑解惑，解决问题。\n你性格很温暖，喜欢帮助别人，非常热心。\n\n##技能\n1. 当用户询问某一问题时，利用你的知识进行准确回答。回答内容应简洁明了，易于理解。\n2. 当用户想让你创作时，比如讲一个故事，或者写一首诗，你创作的文本主题要围绕用户的主题要求，确保内容具有逻辑性、连贯性和可读性。除非用户对创作内容有特殊要求，否则字数不用太长。\n3. 当用户想让你对于某一事件发表看法，你要有一定的见解和建议，但是也要符合普世的价值观。"],"Prefill":true,"ModelName":"Doubao-pro-32k","ModelVersion":"1.0","WelcomeSpeech":"你好，我是你的AI小助手，有什么可以帮你的吗？","ModeSourceType":"Available","APIKey":"","Url":"","Feature":"{\"Http\":true}"}
/// TTSConfig : {"Provider":"volcano","ProviderParams":{"app":{"AppId":"4799544484","Cluster":"volcano_tts"},"audio":{"voice_type":"BV001_streaming","speed_ratio":1}},"IgnoreBracketText":[1,2,3,4,5]}
/// ASRConfig : {"Provider":"volcano","ProviderParams":{"Mode":"smallmodel","AppId":"4799544484","Cluster":"volcengine_streaming_common"},"VADConfig":{"SilenceTime":600,"SilenceThreshold":200},"VolumeGain":0.3}
/// InterruptMode : 0
/// SubtitleConfig : {"SubtitleMode":0}

Config configFromJson(String str) => Config.fromJson(json.decode(str));
String configToJson(Config data) => json.encode(data.toJson());

class Config {
  Config({
    this.lLMConfig,
    this.tTSConfig,
    this.aSRConfig,
    this.interruptMode,
    this.subtitleConfig,
  });

  Config.fromJson(dynamic json) {
    lLMConfig = json['LLMConfig'] != null
        ? LlmConfig.fromJson(json['LLMConfig'])
        : null;
    tTSConfig = json['TTSConfig'] != null
        ? TtsConfig.fromJson(json['TTSConfig'])
        : null;
    aSRConfig = json['ASRConfig'] != null
        ? AsrConfig.fromJson(json['ASRConfig'])
        : null;
    interruptMode = json['InterruptMode'];
    subtitleConfig = json['SubtitleConfig'] != null
        ? SubtitleConfig.fromJson(json['SubtitleConfig'])
        : null;
  }
  LlmConfig? lLMConfig;
  TtsConfig? tTSConfig;
  AsrConfig? aSRConfig;
  num? interruptMode;
  SubtitleConfig? subtitleConfig;
  Config copyWith({
    LlmConfig? lLMConfig,
    TtsConfig? tTSConfig,
    AsrConfig? aSRConfig,
    num? interruptMode,
    SubtitleConfig? subtitleConfig,
  }) =>
      Config(
        lLMConfig: lLMConfig ?? this.lLMConfig,
        tTSConfig: tTSConfig ?? this.tTSConfig,
        aSRConfig: aSRConfig ?? this.aSRConfig,
        interruptMode: interruptMode ?? this.interruptMode,
        subtitleConfig: subtitleConfig ?? this.subtitleConfig,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (lLMConfig != null) {
      map['LLMConfig'] = lLMConfig?.toJson();
    }
    if (tTSConfig != null) {
      map['TTSConfig'] = tTSConfig?.toJson();
    }
    if (aSRConfig != null) {
      map['ASRConfig'] = aSRConfig?.toJson();
    }
    map['InterruptMode'] = interruptMode;
    if (subtitleConfig != null) {
      map['SubtitleConfig'] = subtitleConfig?.toJson();
    }
    return map;
  }
}

/// SubtitleMode : 0

SubtitleConfig subtitleConfigFromJson(String str) =>
    SubtitleConfig.fromJson(json.decode(str));
String subtitleConfigToJson(SubtitleConfig data) => json.encode(data.toJson());

class SubtitleConfig {
  SubtitleConfig({
    this.subtitleMode,
  });

  SubtitleConfig.fromJson(dynamic json) {
    subtitleMode = json['SubtitleMode'];
  }
  num? subtitleMode;
  SubtitleConfig copyWith({
    num? subtitleMode,
  }) =>
      SubtitleConfig(
        subtitleMode: subtitleMode ?? this.subtitleMode,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['SubtitleMode'] = subtitleMode;
    return map;
  }
}

/// Provider : "volcano"
/// ProviderParams : {"Mode":"smallmodel","AppId":"4799544484","Cluster":"volcengine_streaming_common"}
/// VADConfig : {"SilenceTime":600,"SilenceThreshold":200}
/// VolumeGain : 0.3

AsrConfig asrConfigFromJson(String str) => AsrConfig.fromJson(json.decode(str));
String asrConfigToJson(AsrConfig data) => json.encode(data.toJson());

class AsrConfig {
  AsrConfig({
    this.provider,
    this.providerParams,
    this.vADConfig,
    this.volumeGain,
  });

  AsrConfig.fromJson(dynamic json) {
    provider = json['Provider'];
    providerParams = json['ProviderParams'] != null
        ? ProviderParams.fromJson(json['ProviderParams'])
        : null;
    vADConfig = json['VADConfig'] != null
        ? VadConfig.fromJson(json['VADConfig'])
        : null;
    volumeGain = json['VolumeGain'];
  }
  String? provider;
  ProviderParams? providerParams;
  VadConfig? vADConfig;
  num? volumeGain;
  AsrConfig copyWith({
    String? provider,
    ProviderParams? providerParams,
    VadConfig? vADConfig,
    num? volumeGain,
  }) =>
      AsrConfig(
        provider: provider ?? this.provider,
        providerParams: providerParams ?? this.providerParams,
        vADConfig: vADConfig ?? this.vADConfig,
        volumeGain: volumeGain ?? this.volumeGain,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Provider'] = provider;
    if (providerParams != null) {
      map['ProviderParams'] = providerParams?.toJson();
    }
    if (vADConfig != null) {
      map['VADConfig'] = vADConfig?.toJson();
    }
    map['VolumeGain'] = volumeGain;
    return map;
  }
}

/// SilenceTime : 600
/// SilenceThreshold : 200

VadConfig vadConfigFromJson(String str) => VadConfig.fromJson(json.decode(str));
String vadConfigToJson(VadConfig data) => json.encode(data.toJson());

class VadConfig {
  VadConfig({
    this.silenceTime,
    this.silenceThreshold,
  });

  VadConfig.fromJson(dynamic json) {
    silenceTime = json['SilenceTime'];
    silenceThreshold = json['SilenceThreshold'];
  }
  num? silenceTime;
  num? silenceThreshold;
  VadConfig copyWith({
    num? silenceTime,
    num? silenceThreshold,
  }) =>
      VadConfig(
        silenceTime: silenceTime ?? this.silenceTime,
        silenceThreshold: silenceThreshold ?? this.silenceThreshold,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['SilenceTime'] = silenceTime;
    map['SilenceThreshold'] = silenceThreshold;
    return map;
  }
}

/// Mode : "smallmodel"
/// AppId : "4799544484"
/// Cluster : "volcengine_streaming_common"

ProviderParams providerParamsFromJson(String str) =>
    ProviderParams.fromJson(json.decode(str));
String providerParamsToJson(ProviderParams data) => json.encode(data.toJson());

class ProviderParams {
  ProviderParams({
    this.mode,
    this.appId,
    this.cluster,
  });

  ProviderParams.fromJson(dynamic json) {
    mode = json['Mode'];
    appId = json['AppId'];
    cluster = json['Cluster'];
  }
  String? mode;
  String? appId;
  String? cluster;
  ProviderParams copyWith({
    String? mode,
    String? appId,
    String? cluster,
  }) =>
      ProviderParams(
        mode: mode ?? this.mode,
        appId: appId ?? this.appId,
        cluster: cluster ?? this.cluster,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Mode'] = mode;
    map['AppId'] = appId;
    map['Cluster'] = cluster;
    return map;
  }
}

/// Provider : "volcano"
/// ProviderParams : {"app":{"AppId":"4799544484","Cluster":"volcano_tts"},"audio":{"voice_type":"BV001_streaming","speed_ratio":1}}
/// IgnoreBracketText : [1,2,3,4,5]
/// Provider : "volcano"
/// ProviderParams : {"app":{"AppId":"4799544484","Cluster":"volcano_tts"}}
/// IgnoreBracketText : [1,2,3,4,5]
/// audio : {"voice_type":"BV001_streaming","speed_ratio":1}
TtsConfig ttsConfigFromJson(String str) => TtsConfig.fromJson(json.decode(str));
String ttsConfigToJson(TtsConfig data) => json.encode(data.toJson());

class TtsConfig {
  TtsConfig({
    this.provider,
    this.providerParams,
    this.ignoreBracketText,
    this.audio,
  });

  TtsConfig.fromJson(dynamic json) {
    provider = json['Provider'];
    providerParams = json['ProviderParams'] != null
        ? ProviderParams.fromJson(json['ProviderParams'])
        : null;
    ignoreBracketText = json['IgnoreBracketText'] != null
        ? json['IgnoreBracketText'].cast<num>()
        : [];
    audio = json['audio'] != null ? Audio.fromJson(json['audio']) : null;
  }
  String? provider;
  ProviderParams? providerParams;
  List<num>? ignoreBracketText;
  Audio? audio;
  TtsConfig copyWith({
    String? provider,
    ProviderParams? providerParams,
    List<num>? ignoreBracketText,
    Audio? audio,
  }) =>
      TtsConfig(
        provider: provider ?? this.provider,
        providerParams: providerParams ?? this.providerParams,
        ignoreBracketText: ignoreBracketText ?? this.ignoreBracketText,
        audio: audio ?? this.audio,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Provider'] = provider;
    if (providerParams != null) {
      map['ProviderParams'] = providerParams?.toJson();
    }
    map['audio'] = audio?.toJson();
    map['IgnoreBracketText'] = ignoreBracketText;
    return map;
  }
}

/// voice_type : "BV001_streaming"
/// speed_ratio : 1

Audio audioFromJson(String str) => Audio.fromJson(json.decode(str));
String audioToJson(Audio data) => json.encode(data.toJson());

class Audio {
  Audio({
    this.voiceType,
    this.speedRatio,
  });

  Audio.fromJson(dynamic json) {
    voiceType = json['voice_type'];
    speedRatio = json['speed_ratio'];
  }
  String? voiceType;
  num? speedRatio;
  Audio copyWith({
    String? voiceType,
    num? speedRatio,
  }) =>
      Audio(
        voiceType: voiceType ?? this.voiceType,
        speedRatio: speedRatio ?? this.speedRatio,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['voice_type'] = voiceType;
    map['speed_ratio'] = speedRatio;
    return map;
  }
}

/// AppId : "4799544484"
/// Cluster : "volcano_tts"

App appFromJson(String str) => App.fromJson(json.decode(str));
String appToJson(App data) => json.encode(data.toJson());

class App {
  App({
    this.appId,
    this.cluster,
  });

  App.fromJson(dynamic json) {
    appId = json['AppId'];
    cluster = json['Cluster'];
  }
  String? appId;
  String? cluster;
  App copyWith({
    String? appId,
    String? cluster,
  }) =>
      App(
        appId: appId ?? this.appId,
        cluster: cluster ?? this.cluster,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['AppId'] = appId;
    map['Cluster'] = cluster;
    return map;
  }
}

/// Mode : "ArkV3"
/// EndPointId : "ep-20250401160533-rr59m"
/// MaxTokens : 1024
/// Temperature : 0.1
/// TopP : 0.3
/// SystemMessages : ["##人设\n你是一个全能智能体，拥有丰富的百科知识，可以为人们答疑解惑，解决问题。\n你性格很温暖，喜欢帮助别人，非常热心。\n\n##技能\n1. 当用户询问某一问题时，利用你的知识进行准确回答。回答内容应简洁明了，易于理解。\n2. 当用户想让你创作时，比如讲一个故事，或者写一首诗，你创作的文本主题要围绕用户的主题要求，确保内容具有逻辑性、连贯性和可读性。除非用户对创作内容有特殊要求，否则字数不用太长。\n3. 当用户想让你对于某一事件发表看法，你要有一定的见解和建议，但是也要符合普世的价值观。"]
/// Prefill : true
/// ModelName : "Doubao-pro-32k"
/// ModelVersion : "1.0"
/// WelcomeSpeech : "你好，我是你的AI小助手，有什么可以帮你的吗？"
/// ModeSourceType : "Available"
/// APIKey : ""
/// Url : ""
/// Feature : "{\"Http\":true}"

LlmConfig llmConfigFromJson(String str) => LlmConfig.fromJson(json.decode(str));
String llmConfigToJson(LlmConfig data) => json.encode(data.toJson());

class LlmConfig {
  LlmConfig({
    this.mode,
    this.endPointId,
    this.maxTokens,
    this.temperature,
    this.topP,
    this.systemMessages,
    this.prefill,
    this.modelName,
    this.modelVersion,
    this.welcomeSpeech,
    this.modeSourceType,
    this.aPIKey,
    this.url,
    this.feature,
  });

  LlmConfig.fromJson(dynamic json) {
    mode = json['Mode'];
    endPointId = json['EndPointId'];
    maxTokens = json['MaxTokens'];
    temperature = json['Temperature'];
    topP = json['TopP'];
    systemMessages = json['SystemMessages'] != null
        ? json['SystemMessages'].cast<String>()
        : [];
    prefill = json['Prefill'];
    modelName = json['ModelName'];
    modelVersion = json['ModelVersion'];
    welcomeSpeech = json['WelcomeSpeech'];
    modeSourceType = json['ModeSourceType'];
    aPIKey = json['APIKey'];
    url = json['Url'];
    feature = json['Feature'];
  }
  String? mode;
  String? endPointId;
  num? maxTokens;
  num? temperature;
  num? topP;
  List<String>? systemMessages;
  bool? prefill;
  String? modelName;
  String? modelVersion;
  String? welcomeSpeech;
  String? modeSourceType;
  String? aPIKey;
  String? url;
  String? feature;
  LlmConfig copyWith({
    String? mode,
    String? endPointId,
    num? maxTokens,
    num? temperature,
    num? topP,
    List<String>? systemMessages,
    bool? prefill,
    String? modelName,
    String? modelVersion,
    String? welcomeSpeech,
    String? modeSourceType,
    String? aPIKey,
    String? url,
    String? feature,
  }) =>
      LlmConfig(
        mode: mode ?? this.mode,
        endPointId: endPointId ?? this.endPointId,
        maxTokens: maxTokens ?? this.maxTokens,
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        systemMessages: systemMessages ?? this.systemMessages,
        prefill: prefill ?? this.prefill,
        modelName: modelName ?? this.modelName,
        modelVersion: modelVersion ?? this.modelVersion,
        welcomeSpeech: welcomeSpeech ?? this.welcomeSpeech,
        modeSourceType: modeSourceType ?? this.modeSourceType,
        aPIKey: aPIKey ?? this.aPIKey,
        url: url ?? this.url,
        feature: feature ?? this.feature,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Mode'] = mode;
    map['EndPointId'] = endPointId;
    map['MaxTokens'] = maxTokens;
    map['Temperature'] = temperature;
    map['TopP'] = topP;
    map['SystemMessages'] = systemMessages;
    map['Prefill'] = prefill;
    map['ModelName'] = modelName;
    map['ModelVersion'] = modelVersion;
    map['WelcomeSpeech'] = welcomeSpeech;
    map['ModeSourceType'] = modeSourceType;
    map['APIKey'] = aPIKey;
    map['Url'] = url;
    map['Feature'] = feature;
    return map;
  }
}

/// UserId : "RobotMan_"
/// WelcomeMessage : "你好，我是你的AI小助手，有什么可以帮你的吗？"
/// EnableConversationStateCallback : true
/// ServerMessageSignatureForRTS : "conversation"
/// TargetUserId : ["user1"]

AgentConfig agentConfigFromJson(String str) =>
    AgentConfig.fromJson(json.decode(str));
String agentConfigToJson(AgentConfig data) => json.encode(data.toJson());

class AgentConfig {
  AgentConfig({
    this.userId,
    this.welcomeMessage,
    this.enableConversationStateCallback,
    this.serverMessageSignatureForRTS,
    this.targetUserId,
  });

  AgentConfig.fromJson(dynamic json) {
    userId = json['UserId'];
    welcomeMessage = json['WelcomeMessage'];
    enableConversationStateCallback = json['EnableConversationStateCallback'];
    serverMessageSignatureForRTS = json['ServerMessageSignatureForRTS'];
    targetUserId =
        json['TargetUserId'] != null ? json['TargetUserId'].cast<String>() : [];
  }
  String? userId;
  String? welcomeMessage;
  bool? enableConversationStateCallback;
  String? serverMessageSignatureForRTS;
  List<String>? targetUserId;
  AgentConfig copyWith({
    String? userId,
    String? welcomeMessage,
    bool? enableConversationStateCallback,
    String? serverMessageSignatureForRTS,
    List<String>? targetUserId,
  }) =>
      AgentConfig(
        userId: userId ?? this.userId,
        welcomeMessage: welcomeMessage ?? this.welcomeMessage,
        enableConversationStateCallback: enableConversationStateCallback ??
            this.enableConversationStateCallback,
        serverMessageSignatureForRTS:
            serverMessageSignatureForRTS ?? this.serverMessageSignatureForRTS,
        targetUserId: targetUserId ?? this.targetUserId,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['UserId'] = userId;
    map['WelcomeMessage'] = welcomeMessage;
    map['EnableConversationStateCallback'] = enableConversationStateCallback;
    map['ServerMessageSignatureForRTS'] = serverMessageSignatureForRTS;
    map['TargetUserId'] = targetUserId;
    return map;
  }
}
