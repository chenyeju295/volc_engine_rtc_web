# RTC-AIGC 功能与参数文档

## 1. 项目概述
该项目是一个结合实时通信(RTC)和人工智能生成内容(AIGC)的演示应用，使用火山引擎的RTC服务和豆包大模型，提供AI语音助手功能。项目允许用户通过语音与AI进行实时对话，并支持视觉模型进行多模态交互。

## 2. 核心功能与参数

### 2.1 基础配置（BaseConfig）

| 参数名 | 说明 | 默认值示例 | 是否必填 |
|------|------|---------|-------|
| AppId | RTC应用ID，可在火山引擎控制台获取 | '67f3871435d851017835d866' | 是 |
| BusinessId | 业务ID | undefined | 否 |
| RoomId | 房间ID，建议使用有特定规则的不重复房间号 | 'room1' | 是 |
| UserId | 当前和AI对话的用户ID | 'user1' | 是 |
| Token | RTC Token，用于RTC通信进房鉴权校验 | '00167f3871435d...' | 是 |
| TTSAppId | 语音合成服务的应用ID | '4799544484' | 是 | 
| ASRAppId | 语音识别服务的应用ID | '4799544484' | 是 | 

### 2.2 启动引擎

**功能**：创建和初始化RTC引擎

**主要参数**：
{
    "appId": "67f3871435d851017835d866",
    "roomId": "room1",
    "uid": "user1"
}
```typescript
interface EngineOptions {
  appId: string;    // RTC应用ID
  uid: string;      // 用户ID
  roomId: string;   // 房间ID
}
```

**代码示例**：
```typescript
const engineParams = {
  appId: aigcConfig.BaseConfig.AppId,
  roomId,
  uid: username,
};
await RtcClient.createEngine(engineParams);
 createEngine = async (props: EngineOptions) => {
    this.config = props;
    this.basicInfo = {
      room_id: props.roomId,
      user_id: props.uid,
      login_token: aigcConfig.BaseConfig.Token,
    };
    console.log('[RTC_CREATE_ENGINE] 开始创建引擎，参数:', this.config);
    this.engine = VERTC.createEngine(this.config.appId);
    try {
      const AIAnsExtension = new RTCAIAnsExtension();
      await this.engine.registerExtension(AIAnsExtension);
      AIAnsExtension.enable();
    } catch (error) {
      console.warn(
        `当前环境不支持 AI 降噪, 此错误可忽略, 不影响实际使用, e: ${(error as any).message}`
      );
    }
  };
```

### 2.3 加入房间

**功能**：用户加入RTC房间

**主要参数**：
{
    "token": "00167f3871435d851017835d866QACv+voARofzZ8bB/GcFAHJvb20xBQB1c2VyMQYAAADGwfxnAQDGwfxnAgDGwfxnAwDGwfxnBADGwfxnBQDGwfxnIAB62o3pw6yAxUY16+TUQE5b3zmBf8mKl1zTnaaEFhHeLg==",
    "roomId": "room1",
    "userId": "user1",
    "extraInfo": {
        "userId": "user1",
        "extraInfo": "{"call_scene":"RTC-AIGC","user_name":"user1","user_id":"user1"}"
    },
    "config": {
        "isAutoPublish": true,
        "isAutoSubscribeAudio": true,
        "roomProfileType": 5
    }
}
**加入房间实现**：

```typescript
// 调用RTC引擎的joinRoom方法
return this.engine.joinRoom(
  token,
  roomId,
  {
    userId: uid,
    extraInfo: JSON.stringify({
      call_scene: 'RTC-AIGC',
      user_name: username,
      user_id: uid,
    })
  },
  {
    isAutoPublish: true,
    isAutoSubscribeAudio: true,
    roomProfileType: RoomProfileType.chat,
  }
);

```

### 2.4 AI模型配置

#### 2.4.1 LLM配置（大语言模型）

| 参数名 | 说明 | 默认值 |
|------|------|-------|
| Mode | AI模式 | AI_MODE_MAP[Model] |
| EndPointId | 模型端点ID | ARK_V3_MODEL_ID[Model] |
| MaxTokens | 生成最大token数 | 1024 |
| Temperature | 温度参数（控制随机性） | 0.1 |
| TopP | 核采样参数 | 0.3 |
| SystemMessages | 系统预设指令 | [Prompt] |
| Prefill | 是否预填充 | true |
| ModelName | 模型名称 | Model |
| ModelVersion | 模型版本 | '1.0' |
| WelcomeSpeech | 欢迎语 | WelcomeSpeech |
| ModeSourceType | 模型源类型 | ModelSourceType.Available |
| APIKey | API密钥（第三方模型使用） | undefined |
| Url | 模型URL（第三方模型使用） | undefined |
| Feature | 特性 | JSON.stringify({ Http: true }) |

#### 2.4.2 视觉模型配置

视觉模式下额外参数：
```typescript
VisionConfig: {
  Enable: true,
  SnapshotConfig: {
    StreamType: VisionSourceType, // 流类型（摄像头或屏幕共享）
    Height: 640,                 // 图像高度
    ImagesLimit: 1,              // 图像数量限制
  },
}
```

#### 2.4.3 TTS配置（语音合成）

| 参数名 | 说明 | 默认值 |
|------|------|-------|
| Provider | 提供商 | 'volcano' |
| AppId | TTS应用ID | BaseConfig.TTSAppId |
| Cluster | TTS集群ID | TTS_CLUSTER.TTS |
| VoiceType | 音色ID | Voice[SCENE.INTELLIGENT_ASSISTANT] |
| SpeedRatio | 语速比例 | 1.0 |
| IgnoreBracketText | 忽略括号内文本 | [1, 2, 3, 4, 5] |

#### 2.4.4 ASR配置（语音识别）

**小模型配置**：
```typescript
{
  Provider: 'volcano',
  ProviderParams: {
    Mode: 'smallmodel',
    AppId: ASRAppId,
    Cluster: 'volcengine_streaming_common',
  },
  VADConfig: {
    SilenceTime: 600,         // 静音时间
    SilenceThreshold: 200,    // 静音阈值
  },
  VolumeGain: 0.3,            // 音量增益
}
```

**大模型配置**：
```typescript
{
  Provider: 'volcano',
  ProviderParams: {
    Mode: 'bigmodel',
    AppId: ASRAppId,
    AccessToken: ASRToken,
  },
}
```

### 2.5 启动AI助手

**功能**：开启AI语音助手服务

**代码示例**：
```typescript
 const options = {
      AppId: aigcConfig.BaseConfig.AppId,
      BusinessId: aigcConfig.BaseConfig.BusinessId,
      RoomId: roomId,
      TaskId: userId,
      AgentConfig: {
        ...agentConfig,
        TargetUserId: [userId],
      },
      Config: aigcConfig.aigcConfig.Config,
    };
    
    console.log('[AIGC_START] API调用参数:', options);
    
    try {
      const result = await StartVoiceChat(options);
     
```

**startAudioBot内部实现参数**：
```

{
    "AppId": "67f3871435d851017835d866",
    "RoomId": "room1",
    "TaskId": "user1",
    "AgentConfig": {
        "UserId": "RobotMan_",
        "WelcomeMessage": "你好，我是你的AI小助手，有什么可以帮你的吗？",
        "EnableConversationStateCallback": true,
        "ServerMessageSignatureForRTS": "conversation",
        "TargetUserId": [
            "user1"
        ]
    },
    "Config": {
        "LLMConfig": {
            "Mode": "ArkV3",
            "EndPointId": "ep-20250401160533-rr59m",
            "MaxTokens": 1024,
            "Temperature": 0.1,
            "TopP": 0.3,
            "SystemMessages": [
                "##人设\n你是一个全能智能体，拥有丰富的百科知识，可以为人们答疑解惑，解决问题。\n你性格很温暖，喜欢帮助别人，非常热心。\n\n##技能\n1. 当用户询问某一问题时，利用你的知识进行准确回答。回答内容应简洁明了，易于理解。\n2. 当用户想让你创作时，比如讲一个故事，或者写一首诗，你创作的文本主题要围绕用户的主题要求，确保内容具有逻辑性、连贯性和可读性。除非用户对创作内容有特殊要求，否则字数不用太长。\n3. 当用户想让你对于某一事件发表看法，你要有一定的见解和建议，但是也要符合普世的价值观。"
            ],
            "Prefill": true,
            "ModelName": "Doubao-pro-32k",
            "ModelVersion": "1.0",
            "WelcomeSpeech": "你好，我是你的AI小助手，有什么可以帮你的吗？",
            "ModeSourceType": "Available",
            "APIKey": "",
            "Url": "",
            "Feature": "{\"Http\":true}"
        },
        "TTSConfig": {
            "Provider": "volcano",
            "ProviderParams": {
                "app": {
                    "AppId": "4799544484",
                    "Cluster": "volcano_tts"
                },
                "audio": {
                    "voice_type": "BV001_streaming",
                    "speed_ratio": 1
                }
            },
            "IgnoreBracketText": [
                1,
                2,
                3,
                4,
                5
            ]
        },
        "ASRConfig": {
            "Provider": "volcano",
            "ProviderParams": {
                "Mode": "smallmodel",
                "AppId": "4799544484",
                "Cluster": "volcengine_streaming_common"
            },
            "VADConfig": {
                "SilenceTime": 600,
                "SilenceThreshold": 200
            },
            "VolumeGain": 0.3
        },
        "InterruptMode": 0,
        "SubtitleConfig": {
            "SubtitleMode": 0
        }
    }
}
```

```typescript
{
  Config: {
    LLMConfig: this.LLMConfig,        // 大模型配置
    TTSConfig: this.TTSConfig,        // 语音合成配置
    ASRConfig: this.ASRConfig,        // 语音识别配置
    InterruptMode: InterruptMode ? 0 : 1,  // 打断模式
    SubtitleConfig: {
      SubtitleMode: 0,                // 字幕模式
    },
  },
  AgentConfig: {
    UserId: BotName,                  // AI机器人ID
    WelcomeMessage: WelcomeSpeech,    // 欢迎消息
    EnableConversationStateCallback: true,  // 启用会话状态回调
    ServerMessageSignatureForRTS: CONVERSATION_SIGNATURE,  // 服务器消息签名
  },
}
```

### 2.6 聊天功能

#### 2.6.1 消息类型
```typescript
enum MESSAGE_TYPE {
  BRIEF = 'conv',      // 状态变化信息
  SUBTITLE = 'subv',   // 字幕信息
  FUNCTION_CALL = 'func',  // 函数调用
}
```

#### 2.6.2 对话状态
```typescript
enum AGENT_BRIEF {
  UNKNOWN,       // 未知状态
  LISTENING,     // 听取用户输入
  THINKING,      // 思考中
  SPEAKING,      // 正在说话
  INTERRUPTED,   // 被打断
  FINISHED,      // 完成
}
```

#### 2.6.3 指令类型
```typescript
enum COMMAND {
  INTERRUPT = 'interrupt',                // 打断指令
  EXTERNAL_TEXT_TO_SPEECH = 'ExternalTextToSpeech',  // 发送外部文本驱动TTS
  EXTERNAL_TEXT_TO_LLM = 'ExternalTextToLLM',        // 发送外部文本驱动LLM
}
```

#### 2.6.4 打断优先级
```typescript
enum INTERRUPT_PRIORITY {
  NONE,     // 占位
  HIGH,     // 高优先级，立即打断交互进行处理
  MEDIUM,   // 中优先级，等待当前交互结束后处理
  LOW,      // 低优先级，如当前正在交互则丢弃信息
}
```

**文本提问示例**：
```typescript
const handleQuestion = (que: string) => {
  RtcClient.commandAudioBot(COMMAND.EXTERNAL_TEXT_TO_LLM, INTERRUPT_PRIORITY.HIGH, que);
  setQuestion(que);
};
```

### 2.7 设备控制

**功能**：控制麦克风、摄像头和屏幕共享

**主要方法**：
- `switchMic(controlPublish?: boolean)`: 切换麦克风状态
- `switchCamera(controlPublish?: boolean)`: 切换摄像头状态
- `switchScreenCapture(controlPublish?: boolean)`: 切换屏幕共享状态

**相关参数**：
- `controlPublish`: 布尔值，是否控制发布流

**设备状态查询**：
```typescript
// 查询设备
const queryDevices = async (type: MediaType) => {
  const mediaDevices = await RtcClient.getDevices({
    audio: type === MediaType.AUDIO,
    video: type === MediaType.VIDEO,
  });
  // ...
};
```

### 2.8 退出房间

**功能**：离开RTC房间，停止AI助手

**代码示例**：
```typescript
const leaveRoom = () => {
  if (audioBotEnabled) {
    stopAudioBot();
  }
  audioBotEnabled = false;
  engine.leaveRoom();
  VERTC.destroyEngine(engine);
  _audioCaptureDevice = undefined;
};
```

## 3. 事件监听器

```typescript
interface IEventListener {
  handleError: (e: { errorCode: any }) => void;
  handleUserJoin: (e: onUserJoinedEvent) => void;
  handleUserLeave: (e: onUserLeaveEvent) => void;
  handleTrackEnded: (e: { kind: string; isScreen: boolean }) => void;
  handleUserPublishStream: (e: { userId: string; mediaType: MediaType }) => void;
  handleUserUnpublishStream: (e: {
    userId: string;
    mediaType: MediaType;
    reason: StreamRemoveReason;
  }) => void;
  handleRemoteStreamStats: (e: RemoteStreamStats) => void;
  handleLocalStreamStats: (e: LocalStreamStats) => void;
  handleLocalAudioPropertiesReport: (e: LocalAudioPropertiesInfo[]) => void;
  handleRemoteAudioPropertiesReport: (e: RemoteAudioPropertiesInfo[]) => void;
  handleAudioDeviceStateChanged: (e: DeviceInfo) => void;
  handleAutoPlayFail: (e: AutoPlayFailedEvent) => void;
  handlePlayerEvent: (e: PlayerEvent) => void;
  handleUserStartAudioCapture: (e: { userId: string }) => void;
  handleUserStopAudioCapture: (e: { userId: string }) => void;
  handleRoomBinaryMessageReceived: (e: { userId: string; message: ArrayBuffer }) => void;
  handleNetworkQuality: (
    uplinkNetworkQuality: NetworkQuality,
    downlinkNetworkQuality: NetworkQuality
  ) => void;
}
```

## 4. 使用流程

1. **初始化配置**：设置必要的AppId、Token等参数
2. **创建RTC引擎**：通过RtcClient.createEngine创建引擎
3. **设置事件监听**：添加必要的事件回调处理
4. **加入房间**：调用joinRoom方法加入RTC房间
5. **启动AI助手**：调用startAudioBot开启AI交互
6. **语音/文本交互**：通过麦克风或发送文本与AI进行对话
7. **控制设备**：根据需要开关麦克风、摄像头或屏幕共享
8. **退出房间**：结束时调用leaveRoom离开房间并释放资源

## 5. 注意事项

1. 使用前确保已获取必要的AppId和Token，可在火山引擎控制台获取
2. 大模型模式需要额外配置ASRToken和相关权限
3. 视觉模型需要确保摄像头或屏幕共享权限正常
4. 出现权限问题时会有相应提示，请检查浏览器权限设置
5. 打断功能可通过InterruptMode控制是否启用

## 6. 错误处理

项目包含基本的错误处理机制，主要包括：
- 设备权限检查和提示
- 浏览器兼容性检测
- RTC连接状态监控
- 网络质量检测

## 7. 项目依赖

- @volcengine/rtc: 火山引擎RTC SDK
- @volcengine/rtc/extension-ainr: AI降噪扩展
- React & Redux: 前端框架和状态管理
- @arco-design/web-react: UI组件库

## 8. 更多资源

相关文档链接：
- RTC文档: https://www.volcengine.com/docs/6348/1404673
- 语音合成服务: https://www.volcengine.com/docs/6348/1337284
- 语音识别服务: https://www.volcengine.com/docs/6348/70121 