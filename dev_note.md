# VolcEngine RTC Flutter Web 插件实现指南

## 一、项目概述

### 核心组件
- **RTC SDK**: 火山引擎 RTC Web SDK (v4.58.9)
- **AI 扩展**: RTC AIAns 扩展模块

### 关键功能模块
- **音频处理链路**: RTC音频采集与传输、ASR语音识别、LLM大模型处理、TTS语音合成
- **事件处理系统**: 音频设备状态管理、语音聊天状态控制、AI消息处理、情绪分析

### 核心参数配置
```typescript
// RTC 配置
interface RTCConfig {
  appId: string;        // RTC 应用 ID
  userId: string;       // 用户 ID
  roomId: string;       // 房间 ID
  token: string;        // RTC Token
  businessId?: string;  // 业务 ID（可选）
}

// AI 配置
interface AIConfig {
  asrAppId: string;     // ASR 应用 ID
  ttsAppId: string;     // TTS 应用 ID
  arkModelId: string;   // 方舟模型 ID
  language: string;     // 语言设置
  voiceType: string;    // 语音类型
}
```

## 二、核心实现分析

### 1. RTC 引擎初始化

```dart
class RtcEngine {
  dynamic _engine;
  dynamic _aiExtension;
  bool _initialized = false;
  
  Future<void> initialize(String appId) async {
    if (_initialized) return;
    
    // 确保SDK已加载
    await _ensureSDKLoaded();
    
    
    try {
      // 调用JavaScript创建引擎
      final createEngine = js_util.getProperty(html.window, 'VERTC.createEngine');
      _engine = js_util.callMethod(createEngine, 'call', [null, appId]);
      
      // 注册AI扩展
      final extensionConstructor = js_util.getProperty(html.window, 'RTCAIAnsExtension');
      _aiExtension = js_util.callConstructor(extensionConstructor, []);
      
      await js_util.promiseToFuture(
        js_util.callMethod(_engine, 'registerExtension', [_aiExtension])
      );
      
      // 启用扩展
      js_util.callMethod(_aiExtension, 'enable', []);
      
      _initialized = true;
      debugPrint('RTC引擎初始化成功，appId: $appId');
    } catch (e, stack) {
      debugPrint('RTC引擎初始化失败: $e\n$stack');
      throw RTCError(RTCErrorType.initError, '引擎初始化失败: $e');
    }
  }
  
  Future<void> _ensureSDKLoaded() async {
    final sdkLoader = SDKLoader();
    if (!sdkLoader.isSDKLoaded()) {
      await sdkLoader.waitForSDKLoad();
    }
  }
}
```

### 2. 房间管理实现

```dart
/// 加入RTC房间
Future<void> joinRoom(String token, String roomId, String userId, String userName) async {
  if (!_initialized) {
    throw RTCError(RTCErrorType.notInitialized, '引擎未初始化');
  }
  
  try {
    // 启用音频属性报告（音量显示等功能）
    final reportConfig = js_util.jsify({'interval': 1000});
    js_util.callMethod(_engine, 'enableAudioPropertiesReport', [reportConfig]);
    
    // 构建用户信息参数
    final userInfo = js_util.jsify({
      'userId': userId,
      'extraInfo': jsonEncode({
        'user_name': userName,
        'user_id': userId,
      }),
    });
    
    // 构建房间选项
    final roomOptions = js_util.jsify({
      'isAutoPublish': true,
      'isAutoSubscribeAudio': true,
      'roomProfileType': 1, // RoomProfileType.chat
    });
    
    // 执行加入房间
    await js_util.promiseToFuture(
      js_util.callMethod(_engine, 'joinRoom', [token, roomId, userInfo, roomOptions])
    );
    
    debugPrint('成功加入房间: $roomId, 用户: $userId');
  } catch (e, stack) {
    debugPrint('加入房间失败: $e\n$stack');
    throw RTCError(RTCErrorType.joinRoomError, '加入房间失败: $e');
  }
}

/// 离开RTC房间
Future<void> leaveRoom() async {
  if (!_initialized) return;
  
  try {
    // 停止AI服务
    await stopVoiceChat();
    
    // 离开房间
    await js_util.promiseToFuture(
      js_util.callMethod(_engine, 'leaveRoom', [])
    );
    
    debugPrint('成功离开房间');
  } catch (e) {
    debugPrint('离开房间失败: $e');
    // 离开房间时即使出错也不抛异常，防止影响UI流程
  }
}
```

### 3. 音频设备管理

```dart
/// 获取音频输入设备列表
Future<List<AudioDevice>> getAudioInputDevices() async {
  if (!_initialized) {
    throw RTCError(RTCErrorType.notInitialized, '引擎未初始化');
  }
  
  try {
    final jsDevices = await js_util.promiseToFuture(
      js_util.callMethod(_engine, 'getAudioInputDevices', [])
    );
    
    // 将JavaScript设备列表转换为Dart对象
    final List<dynamic> deviceList = js_util.dartify(jsDevices);
    
    // 转换为AudioDevice列表
    return deviceList.map((device) {
      final Map<String, dynamic> deviceInfo = device;
      return AudioDevice(
        deviceId: deviceInfo['deviceId'] ?? '',
        label: deviceInfo['label'] ?? '未知设备',
      );
    }).toList();
  } catch (e) {
    debugPrint('获取音频设备失败: $e');
    return [];
  }
}

/// 设置音频输入设备
Future<void> setAudioInputDevice(String deviceId) async {
  if (!_initialized) {
    throw RTCError(RTCErrorType.notInitialized, '引擎未初始化');
  }
  
  try {
    js_util.callMethod(_engine, 'setAudioCaptureDevice', [deviceId]);
    debugPrint('设置音频输入设备成功: $deviceId');
  } catch (e) {
    debugPrint('设置音频输入设备失败: $e');
    throw RTCError(RTCErrorType.deviceError, '设置音频设备失败: $e');
  }
}

/// 设置音频输入音量
Future<void> setAudioInputVolume(int volume) async {
  if (!_initialized) return;
  
  try {
    // 确保音量在有效范围内
    final int safeVolume = volume.clamp(0, 100);
    js_util.callMethod(_engine, 'setCaptureVolume', [safeVolume]);
    debugPrint('设置捕获音量: $safeVolume');
  } catch (e) {
    debugPrint('设置音量失败: $e');
  }
}
```

### 4. AI 语音交互实现

```dart
/// AI语音聊天配置
class AIVoiceChatConfig {
  final String appId;
  final String? businessId;
  final String asrAppId;
  final String ttsAppId;
  final String language;
  final String voiceType;
  final String modelEndpointId;
  
  AIVoiceChatConfig({
    required this.appId,
    this.businessId,
    required this.asrAppId,
    required this.ttsAppId,
    this.language = 'zh',
    this.voiceType = 'zh_female_voice',
    required this.modelEndpointId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'AppId': appId,
      'BusinessId': businessId,
      'AgentConfig': {
        'ASRConfig': {
          'AppId': asrAppId,
          'SampleRate': 16000,
          'VadConfig': {
            'MaxDurationMs': 15000,
          },
          'LanguageConfig': {
            'LanguageType': language,
          },
        },
        'TTSConfig': {
          'AppId': ttsAppId,
          'Voice': voiceType,
          'LanguageConfig': {
            'LanguageType': language,
          },
        },
        'LLMConfig': {
          'EndpointId': modelEndpointId,
          'Parameters': {
            'temperature': 0.7,
            'max_tokens': 4096,
            'top_p': 0.95,
            'top_k': 50,
          },
        },
      },
      'Config': {
        'features': {
          'EmotionAnalysisConfig': {
            'enable': true,
          },
        },
      },
    };
  }
}

/// 启动AI语音聊天
Future<String> startVoiceChat(AIVoiceChatConfig config, String roomId, String userId) async {
  if (!_initialized) {
    throw RTCError(RTCErrorType.notInitialized, '引擎未初始化');
  }
  
  // 如果已启用，先停止
  if (_voiceChatEnabled) {
    await stopVoiceChat();
  }
  
  try {
    // 构建完整参数
    final options = Map<String, dynamic>.from(config.toJson());
    options['RoomId'] = roomId;
    options['TaskId'] = userId;
    options['AgentConfig']['TargetUserId'] = [userId];
    
    // 调用JavaScript API
    final jsOptions = js_util.jsify(options);
    final JsObject apiNamespace = js_util.getProperty(html.window, 'openAPIs');
    
    final result = await js_util.promiseToFuture(
      js_util.callMethod(apiNamespace, 'StartVoiceChat', [jsOptions])
    );
    
    _voiceChatEnabled = true;
    _sessionId = userId; // 使用taskId作为会话ID
    
    debugPrint('启动AI语音聊天成功: $_sessionId');
    return _sessionId;
  } catch (e, stack) {
    debugPrint('启动AI语音聊天失败: $e\n$stack');
    throw RTCError(RTCErrorType.aiServiceError, '启动AI语音聊天失败: $e');
  }
}

/// 控制AI语音聊天(如中断)
Future<void> controlVoiceChat(String command) async {
  if (!_initialized || !_voiceChatEnabled || _sessionId.isEmpty) {
    throw RTCError(RTCErrorType.invalidState, 'AI语音聊天未启动');
  }
  
  try {
    // 构建控制参数
    final options = {
      'AppId': _config.appId,
      'BusinessId': _config.businessId,
      'RoomId': _roomId,
      'TaskId': _sessionId,
      'Command': command,
    };
    
    // 调用JavaScript API
    final jsOptions = js_util.jsify(options);
    final JsObject apiNamespace = js_util.getProperty(html.window, 'openAPIs');
    
    await js_util.promiseToFuture(
      js_util.callMethod(apiNamespace, 'UpdateVoiceChat', [jsOptions])
    );
    
    debugPrint('控制AI语音聊天成功: $command');
  } catch (e) {
    debugPrint('控制AI语音聊天失败: $e');
    throw RTCError(RTCErrorType.aiServiceError, '控制AI语音聊天失败: $e');
  }
}
```

### 5. 事件处理系统

```dart
class RtcEventProcessor {
  final Map<String, Set<Function>> _eventHandlers = {};
  
  // 注册事件处理器
  void on(String eventName, Function callback) {
    if (!_eventHandlers.containsKey(eventName)) {
      _eventHandlers[eventName] = <Function>{};
    }
    _eventHandlers[eventName]!.add(callback);
  }
  
  // 移除事件处理器
  void off(String eventName, [Function? callback]) {
    if (!_eventHandlers.containsKey(eventName)) return;
    
    if (callback != null) {
      _eventHandlers[eventName]!.remove(callback);
    } else {
      _eventHandlers.remove(eventName);
    }
  }
  
  // 处理事件
  void processEvent(String eventName, dynamic jsEvent) {
    if (!_eventHandlers.containsKey(eventName)) return;
    
    try {
      // 转换事件数据
      final eventData = _convertEventData(eventName, jsEvent);
      
      // 通知所有处理器
      for (var handler in _eventHandlers[eventName]!) {
        handler(eventData);
      }
    } catch (e, stack) {
      debugPrint('处理事件 $eventName 失败: $e\n$stack');
    }
  }
  
  // 转换不同类型的事件数据
  dynamic _convertEventData(String eventName, dynamic jsEvent) {
    switch (eventName) {
      case 'onUserJoined':
        return _convertUserJoinedEvent(jsEvent);
      case 'onLocalAudioPropertiesReport':
        return _convertAudioPropertiesEvent(jsEvent);
      // 其他事件类型转换...
      default:
        return js_util.dartify(jsEvent);
    }
  }
}
```

### 6. 二进制消息处理

```dart
enum MessageType {
  brief,    // 状态变化信息 (conv)
  subtitle, // 字幕 (subv)
  functionCall, // 函数调用 (func)
}

class BinaryMessageProcessor {
  // 消息处理回调
  final Function(MessageType, Map<String, dynamic>)? onMessage;
  
  BinaryMessageProcessor({this.onMessage});
  
  // 处理二进制消息
  void processMessage(Uint8List buffer) {
    try {
      final result = _parseTLV(buffer);
      if (result == null) return;
      
      final type = _getMessageType(result.type);
      final jsonData = jsonDecode(result.value);
      
      if (onMessage != null) {
        onMessage!(type, jsonData);
      }
    } catch (e, stack) {
      debugPrint('解析二进制消息失败: $e\n$stack');
    }
  }
  
  // 解析TLV格式二进制数据
  _TLVResult? _parseTLV(Uint8List buffer) {
    if (buffer.length < 5) return null;
    
    final ByteData data = ByteData.view(buffer.buffer);
    final int typeLength = data.getUint8(0);
    if (buffer.length < 1 + typeLength) return null;
    
    final String type = String.fromCharCodes(buffer.sublist(1, 1 + typeLength));
    final int valueLength = data.getUint32(1 + typeLength, Endian.big);
    
    if (buffer.length < 1 + typeLength + 4 + valueLength) return null;
    
    final String value = String.fromCharCodes(
      buffer.sublist(1 + typeLength + 4, 1 + typeLength + 4 + valueLength)
    );
    
    return _TLVResult(type: type, value: value);
  }
}
```

### 7. SDK 加载实现

```dart
class SDKLoader {
  static final SDKLoader _instance = SDKLoader._internal();
  factory SDKLoader() => _instance;
  SDKLoader._internal();
  
  bool _sdkLoaded = false;
  bool _aiExtensionLoaded = false;
  
  Future<void> loadSDK() async {
    if (_sdkLoaded) return;
    
    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/@volcengine/rtc@4.58.9/dist/index.min.js'
      ..type = 'text/javascript';
    
    script.onLoad.listen((event) {
      _sdkLoaded = true;
      completer.complete();
    });
    
    script.onError.listen((event) {
      completer.completeError('加载 RTC SDK 失败');
    });
    
    html.document.head!.append(script);
    return completer.future;
  }
  
  Future<void> waitForSDKLoad() async {
    const maxAttempts = 20;
    int attempts = 0;
    
    while (!_checkSDKExists() && attempts < maxAttempts) {
      await Future.delayed(Duration(milliseconds: 200));
      attempts++;
    }
    
    if (!_checkSDKExists()) {
      throw Exception('RTC SDK 加载失败');
    }
    
    _sdkLoaded = true;
  }
  
  bool _checkSDKExists() {
    try {
      return js_util.getProperty(html.window, 'VERTC') != null;
    } catch (_) {
      return false;
    }
  }
}
```

## 三、性能优化最佳实践

### 1. 减少 JS 交互开销

```dart
// 推荐: 批量更新
void updateSettings(dynamic jsEngine, Map<String, dynamic> settings) {
  final jsSettings = js_util.jsify(settings);
  js_util.callMethod(
    js_util.getProperty(html.window, 'Object'),
    'assign',
    [jsEngine, jsSettings]
  );
}
```

### 2. 事件处理节流控制

```dart
class EventThrottler<T> {
  final Duration interval;
  final Function(T) callback;
  
  DateTime _lastCallTime = DateTime(1970);
  T? _lastValue;
  Timer? _timer;
  
  EventThrottler({required this.interval, required this.callback});
  
  void call(T value) {
    _lastValue = value;
    final now = DateTime.now();
    
    if (now.difference(_lastCallTime) >= interval) {
      _executeCallback();
    } else if (_timer == null) {
      _timer = Timer(
        interval - now.difference(_lastCallTime),
        _executeCallback
      );
    }
  }
  
  void _executeCallback() {
    if (_lastValue != null) {
      callback(_lastValue as T);
      _lastCallTime = DateTime.now();
      _timer = null;
    }
  }
  
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
```

## 四、实现注意事项

1. **必要参数**
   - AppID: RTC 应用 ID
   - ASR AppID: 语音识别服务 ID
   - TTS AppID: 语音合成服务 ID 
   - ARK_V3_MODEL_ID: 火山方舟模型接入点 ID

2. **错误处理策略**
   - 网络错误：实现重连机制
   - 设备错误：提供默认设备回退
   - 权限错误：清晰的用户权限请求提示

3. **调试技巧**
   - 使用 `debugPrint` 跟踪缓存和事件
   - 监控 JavaScript 交互性能
   - 日志分级记录，区分开发和生产环境