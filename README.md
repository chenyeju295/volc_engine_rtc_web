 

# 火山引擎 RTC Web Flutter 插件

一个用于集成火山引擎实时音视频（RTC）与 AIGC 能力的 Flutter 插件，可在 Flutter Web 应用中实现与 AI 助手的实时语音对话。

[![pub package](https://img.shields.io/pub/v/volc_engine_rtc_web.svg)](https://pub.dev/packages/volc_engine_rtc_web)

### 官方 web demo : https://github.com/volcengine/rtc-aigc-demo/tree/main

#### SDK 版本：4.66.1
 cdn:  https://lf-unpkg.volccdn.com/obj/vcloudfe/sdk/@volcengine/rtc/4.66.1/1741254642340/volengine_Web_4.66.1.js

## 功能特点

- 实时语音识别 (ASR)
- 基于大型语言模型的 AI 对话能力 (LLM)
- 文本转语音合成 (TTS)
- 双向对话功能
- 与火山引擎 RTC SDK 集成

## 安装方法

在 pubspec.yaml 中添加依赖：

```yaml
dependencies:
  volc_engine_rtc_web: ^0.1.0
```

## 配置说明

本插件需要为 RTC、ASR、TTS 和 LLM 服务配置相关参数。为了安全起见，敏感配置信息应存储在单独的 config.json 文件中，并且不应提交到代码仓库。

### 配置 config.json

1. 在项目的 `lib` 目录中创建 `config.json` 文件 或者直接写入配置：

```json
{
  "appId": "您的应用ID",
  "baseUrl": "您的基础URL",
  "appKey": "您的应用密钥",
  "llm": {
    "endPointId": "您的LLM终端点ID"
  },
  "tts": {
    "appid": "您的TTS应用ID"
  },
  "asr": {
    "appId": "您的ASR应用ID"
  }
}
```


## 基本用法

### 初始化插件

从 config.json 文件加载配置并初始化插件：

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

Future<void> initializeRtcAigc() async {
  try {
    // 从JSON文件加载配置
    final String configString = await rootBundle.loadString('lib/config.json');
    final config = json.decode(configString);
    final String userId = 'user1';// 可以动态生成或从配置中获取
    // 设置AIGC配置
    final aigcConfig = AigcConfig(
      appId: config['appId'],
      roomId: 'room1',  // 可以动态生成或从配置中获取
      taskId: userId,  
      agentConfig: AgentConfig(
        userId: 'ChatBot01',
        welcomeMessage: '您好，我是AI助手，有什么可以帮助您的？',
        targetUserId: [userId],
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

    // 初始化插件
    final success = await RtcAigcPlugin.initialize(
      baseUrl: config['baseUrl'], // 服务端部署地址
      config: aigcConfig,
      appKey: config['appKey'], //  用于生成进房间 token
    );
    
    if (success) {
      print('RTC AIGC 插件初始化成功');
    } else {
      print('RTC AIGC 插件初始化失败');
    }
  } catch (e) {
    print('初始化 RTC AIGC 插件出错: $e');
  }
}
```

### 加入房间

```dart
final success = await RtcAigcPlugin.joinRoom();
if (success) {
  print('成功加入房间');
} else {
  print('加入房间失败');
}
```

### 开始对话

```dart
final success = await RtcAigcPlugin.startConversation();
if (success) {
  print('成功开始对话');
} else {
  print('开始对话失败');
}
```
 

### 监听字幕

```dart
RtcAigcPlugin.subtitleStream.listen((subtitle) {
  print('字幕: ${subtitle.text}, 是否最终字幕: ${subtitle.definite}');
}, onError: (error) {
  print('字幕流错误: $error');
});
```

### 管理麦克风

```dart
// 检查设备权限
final permissionResult = await RtcAigcPlugin.enableDevices(audio: true);
if (permissionResult['audio'] == true) {
  print('麦克风访问权限已获取');
} else {
  print('麦克风访问权限被拒绝');
}

// 静音/取消静音
final muteResult = await RtcAigcPlugin.muteAudio(true); // 静音
final unmuteResult = await RtcAigcPlugin.muteAudio(false); // 取消静音
```

### 结束会话

```dart
// 停止对话
await RtcAigcPlugin.stopConversation();

// 离开房间
await RtcAigcPlugin.leaveRoom();

// 清理资源
RtcAigcPlugin.dispose();
```

## 示例应用

查看 [example](./example) 目录获取展示所有功能的完整 Flutter 应用。

## API 参考

有关可用方法和类的完整列表，请参阅 [API 文档](https://pub.dev/documentation/volc_engine_rtc_web/latest/)。

## 许可证

本项目基于 MIT 许可证 - 详情请参阅 LICENSE 文件。

## 贡献指南

欢迎贡献！请随时提交 Pull Request。 