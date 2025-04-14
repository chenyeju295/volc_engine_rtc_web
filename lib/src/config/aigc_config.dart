import 'dart:convert';

/// AppId : "67f3871435d851017835d866"
/// RoomId : "room1"
/// TaskId : "user1"
/// AgentConfig : {"TargetUserId":["user1"],"WelcomeMessage":"你好，我是火山引擎 RTC 语音助手，有什么需要帮忙的吗？","UserId":"ChatBot01"}
/// Config : {"LLMConfig":{"Mode":"ArkV3","EndPointId":"ep-20250401160533-rr59m","VisionConfig":{"Enable":false}},"ASRConfig":{"Provider":"volcano","ProviderParams":{"Mode":"smallmodel","AppId":"4799544484","Cluster":"volcengine_streaming_common"}},"TTSConfig":{"Provider":"volcano","ProviderParams":{"app":{"appid":"4799544484","cluster":"volcano_tts"},"audio":{"voice_type":"BV001_streaming"}}}}

AigcConfig aaFromJson(String str) => AigcConfig.fromJson(json.decode(str));
String aaToJson(AigcConfig data) => json.encode(data.toJson());

class AigcConfig {
  AigcConfig({
    this.appId,
    this.roomId,
    this.taskId,
    this.agentConfig,
    this.config,
  });

  AigcConfig.fromJson(dynamic json) {
    appId = json['AppId'];
    roomId = json['RoomId'];
    taskId = json['TaskId'];
    agentConfig = json['AgentConfig'] != null
        ? AgentConfig.fromJson(json['AgentConfig'])
        : null;
    config = json['Config'] != null ? Config.fromJson(json['Config']) : null;
  }
  String? appId;
  String? roomId;
  String? taskId;
  AgentConfig? agentConfig;
  Config? config;
  AigcConfig copyWith({
    String? appId,
    String? roomId,
    String? taskId,
    AgentConfig? agentConfig,
    Config? config,
  }) =>
      AigcConfig(
        appId: appId ?? this.appId,
        roomId: roomId ?? this.roomId,
        taskId: taskId ?? this.taskId,
        agentConfig: agentConfig ?? this.agentConfig,
        config: config ?? this.config,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['AppId'] = appId;
    map['RoomId'] = roomId;
    map['TaskId'] = taskId;
    if (agentConfig != null) {
      map['AgentConfig'] = agentConfig?.toJson();
    }
    if (config != null) {
      map['Config'] = config?.toJson();
    }
    return map;
  }
}

/// LLMConfig : {"Mode":"ArkV3","EndPointId":"ep-20250401160533-rr59m","VisionConfig":{"Enable":false}}
/// ASRConfig : {"Provider":"volcano","ProviderParams":{"Mode":"smallmodel","AppId":"4799544484","Cluster":"volcengine_streaming_common"}}
/// TTSConfig : {"Provider":"volcano","ProviderParams":{"app":{"appid":"4799544484","cluster":"volcano_tts"},"audio":{"voice_type":"BV001_streaming"}}}

Config configFromJson(String str) => Config.fromJson(json.decode(str));
String configToJson(Config data) => json.encode(data.toJson());

class Config {
  Config({
    this.lLMConfig,
    this.aSRConfig,
    this.tTSConfig,
  });

  Config.fromJson(dynamic json) {
    lLMConfig = json['LLMConfig'] != null
        ? LlmConfig.fromJson(json['LLMConfig'])
        : null;
    aSRConfig = json['ASRConfig'] != null
        ? AsrConfig.fromJson(json['ASRConfig'])
        : null;
    tTSConfig = json['TTSConfig'] != null
        ? TtsConfig.fromJson(json['TTSConfig'])
        : null;
  }
  LlmConfig? lLMConfig;
  AsrConfig? aSRConfig;
  TtsConfig? tTSConfig;
  Config copyWith({
    LlmConfig? lLMConfig,
    AsrConfig? aSRConfig,
    TtsConfig? tTSConfig,
  }) =>
      Config(
        lLMConfig: lLMConfig ?? this.lLMConfig,
        aSRConfig: aSRConfig ?? this.aSRConfig,
        tTSConfig: tTSConfig ?? this.tTSConfig,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (lLMConfig != null) {
      map['LLMConfig'] = lLMConfig?.toJson();
    }
    if (aSRConfig != null) {
      map['ASRConfig'] = aSRConfig?.toJson();
    }
    if (tTSConfig != null) {
      map['TTSConfig'] = tTSConfig?.toJson();
    }
    return map;
  }
}

/// Provider : "volcano"
/// ProviderParams : {"app":{"appid":"4799544484","cluster":"volcano_tts"},"audio":{"voice_type":"BV001_streaming"}}

TtsConfig ttsConfigFromJson(String str) => TtsConfig.fromJson(json.decode(str));
String ttsConfigToJson(TtsConfig data) => json.encode(data.toJson());

class TtsConfig {
  TtsConfig({
    this.provider,
    this.providerParams,
  });

  TtsConfig.fromJson(dynamic json) {
    provider = json['Provider'];
    providerParams = json['ProviderParams'] != null
        ? ProviderParams.fromJson(json['ProviderParams'])
        : null;
  }
  String? provider;
  ProviderParams? providerParams;
  TtsConfig copyWith({
    String? provider,
    ProviderParams? providerParams,
  }) =>
      TtsConfig(
        provider: provider ?? this.provider,
        providerParams: providerParams ?? this.providerParams,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Provider'] = provider;
    if (providerParams != null) {
      map['ProviderParams'] = providerParams?.toJson();
    }
    return map;
  }
}

/// app : {"appid":"4799544484","cluster":"volcano_tts"}
/// audio : {"voice_type":"BV001_streaming"}

ProviderParams providerParamsFromJson(String str) =>
    ProviderParams.fromJson(json.decode(str));
String providerParamsToJson(ProviderParams data) => json.encode(data.toJson());

class ProviderParams {
  ProviderParams({
    this.app,
    this.audio,
  });

  ProviderParams.fromJson(dynamic json) {
    app = json['app'] != null ? App.fromJson(json['app']) : null;
    audio = json['audio'] != null ? Audio.fromJson(json['audio']) : null;
  }
  App? app;
  Audio? audio;
  ProviderParams copyWith({
    App? app,
    Audio? audio,
  }) =>
      ProviderParams(
        app: app ?? this.app,
        audio: audio ?? this.audio,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (app != null) {
      map['app'] = app?.toJson();
    }
    if (audio != null) {
      map['audio'] = audio?.toJson();
    }
    return map;
  }
}

/// voice_type : "BV001_streaming"

Audio audioFromJson(String str) => Audio.fromJson(json.decode(str));
String audioToJson(Audio data) => json.encode(data.toJson());

class Audio {
  Audio({
    this.voiceType,
  });

  Audio.fromJson(dynamic json) {
    voiceType = json['voice_type'];
  }
  String? voiceType;
  Audio copyWith({
    String? voiceType,
  }) =>
      Audio(
        voiceType: voiceType ?? this.voiceType,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['voice_type'] = voiceType;
    return map;
  }
}

/// appid : "4799544484"
/// cluster : "volcano_tts"

App appFromJson(String str) => App.fromJson(json.decode(str));
String appToJson(App data) => json.encode(data.toJson());

class App {
  App({
    this.appid,
    this.cluster,
  });

  App.fromJson(dynamic json) {
    appid = json['appid'];
    cluster = json['cluster'];
  }
  String? appid;
  String? cluster;
  App copyWith({
    String? appid,
    String? cluster,
  }) =>
      App(
        appid: appid ?? this.appid,
        cluster: cluster ?? this.cluster,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['appid'] = appid;
    map['cluster'] = cluster;
    return map;
  }
}

/// Provider : "volcano"
/// ProviderParams : {"Mode":"smallmodel","AppId":"4799544484","Cluster":"volcengine_streaming_common"}

AsrConfig asrConfigFromJson(String str) => AsrConfig.fromJson(json.decode(str));
String asrConfigToJson(AsrConfig data) => json.encode(data.toJson());

class AsrConfig {
  AsrConfig({
    this.provider,
    this.providerParams,
  });

  AsrConfig.fromJson(dynamic json) {
    provider = json['Provider'];
    providerParams = json['ProviderParams'] != null
        ? AsrProviderParams.fromJson(json['ProviderParams'])
        : null;
  }
  String? provider;
  AsrProviderParams? providerParams;
  AsrConfig copyWith({
    String? provider,
    AsrProviderParams? providerParams,
  }) =>
      AsrConfig(
        provider: provider ?? this.provider,
        providerParams: providerParams ?? this.providerParams,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Provider'] = provider;
    if (providerParams != null) {
      map['ProviderParams'] = providerParams?.toJson();
    }
    return map;
  }
}

class AsrProviderParams {
  AsrProviderParams({
    this.mode,
    this.appId,
    this.cluster,
  });

  AsrProviderParams.fromJson(dynamic json) {
    mode = json['Mode'];
    appId = json['AppId'];
    cluster = json['Cluster'];
  }
  String? mode;
  String? appId;
  String? cluster;
  AsrProviderParams copyWith({
    String? mode,
    String? appId,
    String? cluster,
  }) =>
      AsrProviderParams(
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

/// Mode : "ArkV3"
/// EndPointId : "ep-20250401160533-rr59m"
/// VisionConfig : {"Enable":false}

LlmConfig llmConfigFromJson(String str) => LlmConfig.fromJson(json.decode(str));
String llmConfigToJson(LlmConfig data) => json.encode(data.toJson());

class LlmConfig {
  LlmConfig({
    this.mode,
    this.endPointId,
    this.visionConfig,
  });

  LlmConfig.fromJson(dynamic json) {
    mode = json['Mode'];
    endPointId = json['EndPointId'];
    visionConfig = json['VisionConfig'] != null
        ? VisionConfig.fromJson(json['VisionConfig'])
        : null;
  }
  String? mode;
  String? endPointId;
  VisionConfig? visionConfig;
  LlmConfig copyWith({
    String? mode,
    String? endPointId,
    VisionConfig? visionConfig,
  }) =>
      LlmConfig(
        mode: mode ?? this.mode,
        endPointId: endPointId ?? this.endPointId,
        visionConfig: visionConfig ?? this.visionConfig,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Mode'] = mode;
    map['EndPointId'] = endPointId;
    if (visionConfig != null) {
      map['VisionConfig'] = visionConfig?.toJson();
    }
    return map;
  }
}

/// Enable : false

VisionConfig visionConfigFromJson(String str) =>
    VisionConfig.fromJson(json.decode(str));
String visionConfigToJson(VisionConfig data) => json.encode(data.toJson());

class VisionConfig {
  VisionConfig({
    this.enable,
  });

  VisionConfig.fromJson(dynamic json) {
    enable = json['Enable'];
  }
  bool? enable;
  VisionConfig copyWith({
    bool? enable,
  }) =>
      VisionConfig(
        enable: enable ?? this.enable,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Enable'] = enable;
    return map;
  }
}

/// TargetUserId : ["user1"]
/// WelcomeMessage : "你好，我是火山引擎 RTC 语音助手，有什么需要帮忙的吗？"
/// UserId : "ChatBot01"

AgentConfig agentConfigFromJson(String str) =>
    AgentConfig.fromJson(json.decode(str));
String agentConfigToJson(AgentConfig data) => json.encode(data.toJson());

class AgentConfig {
  AgentConfig({
    this.targetUserId,
    this.welcomeMessage,
    this.userId,
  });

  AgentConfig.fromJson(dynamic json) {
    targetUserId =
        json['TargetUserId'] != null ? json['TargetUserId'].cast<String>() : [];
    welcomeMessage = json['WelcomeMessage'];
    userId = json['UserId'];
  }
  List<String>? targetUserId;
  String? welcomeMessage;
  String? userId;
  AgentConfig copyWith({
    List<String>? targetUserId,
    String? welcomeMessage,
    String? userId,
  }) =>
      AgentConfig(
        targetUserId: targetUserId ?? this.targetUserId,
        welcomeMessage: welcomeMessage ?? this.welcomeMessage,
        userId: userId ?? this.userId,
      );
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['TargetUserId'] = targetUserId;
    map['WelcomeMessage'] = welcomeMessage;
    map['UserId'] = userId;
    return map;
  }
}
