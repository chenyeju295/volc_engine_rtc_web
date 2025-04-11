/// RTC AIGC Plugin
///
/// 火山引擎实时音视频与AIGC集成的Flutter插件，用于Web环境
/// 支持与AI智能体进行实时对话，并收发字幕、状态和函数调用等消息
///
/// 包含以下功能：
/// - RTC服务：实时音视频通话
/// - AIGC集成：与AI智能体对话
/// - 消息处理：支持字幕、状态、函数调用等消息类型
/// - 设备管理：音频输入输出设备管理
/// - UI组件：提供对话、字幕等UI组件
library rtc_aigc_plugin;

// 导出模型
export 'src/models/models.dart';

// 导出客户端相关类
export 'src/client/aigc_client.dart';

// 导出配置相关类
export 'src/config/config.dart';

// 导出UI组件
export 'src/widgets/widgets.dart';

// 导出工具类
export 'src/utils/rtc_message_utils.dart';
export 'src/utils/web_utils.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/services/service_manager.dart';

/// RTC AIGC Plugin
///
/// 火山引擎实时音视频与AIGC集成的Flutter插件，用于Web环境
/// 支持与AI智能体进行实时对话，并收发字幕、状态和函数调用等消息
///
/// 基本用法示例:
///
/// ```dart
/// import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
///
/// // 初始化插件
/// await RtcAigcPlugin.initialize(
///   appId: 'your_app_id',
///   roomId: 'your_room_id',
///   userId: 'user_123',
///   token: 'your_rtc_token',
///   serverUrl: 'https://your-api-server.com',
/// );
///
/// // 加入房间
/// await RtcAigcPlugin.joinRoom();
///
/// // 开始与AI对话
/// await RtcAigcPlugin.startConversation(
///   welcomeMessage: '你好，我是AI助手，有什么可以帮助你的？',
/// );
///
/// // 监听AI返回的消息
/// RtcAigcPlugin.messageHistoryStream.listen((messages) {
///   for (var message in messages) {
///     print('收到消息: ${message.text}');
///   }
/// });
///
/// // 发送文本消息给AI
/// await RtcAigcPlugin.sendMessage('今天天气怎么样？');
///
/// // 中断AI的回答
/// await RtcAigcPlugin.interruptConversation();
///
/// // 停止对话
/// await RtcAigcPlugin.stopConversation();
///
/// // 离开房间
/// await RtcAigcPlugin.leaveRoom();
/// ```
///
/// 更多高级用法请参考完整文档和示例代码
class RtcAigcPlugin {
  static const MethodChannel _channel = MethodChannel('rtc_aigc_plugin');

  // 服务管理器实例
  static ServiceManager? _serviceManager;

  // 回调函数
  static void Function(String state, String? message)? _onStateChange;
  static void Function(String text, bool isUser)? _onMessage;
  static void Function(bool isPlaying)? _onAudioStatusChange;
  static void Function(List<dynamic> audioDevices)? _onAudioDevicesChanged;
  static void Function(Map<String, dynamic> subtitle)? _onSubtitle;

  // RTC事件回调
  static void Function(Map<String, dynamic> data)? _onUserJoined;
  static void Function(Map<String, dynamic> data)? _onUserLeave;
  static void Function(Map<String, dynamic> data)? _onUserPublishStream;
  static void Function(Map<String, dynamic> data)? _onUserUnpublishStream;
  static void Function(Map<String, dynamic> data)? _onUserStartAudioCapture;
  static void Function(Map<String, dynamic> data)? _onUserStopAudioCapture;

  // 事件控制器
  static final StreamController<Map<String, dynamic>> _userJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _userLeaveController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>>
      _userPublishStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>>
      _userUnpublishStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>>
      _userStartAudioCaptureController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>>
      _userStopAudioCaptureController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _playerEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// ---------- 字幕和消息相关流 ----------

  /// 用于监听字幕变化的流
  static Stream<Map<String, dynamic>> get subtitleStream =>
      _serviceManager?.rtcService.subtitleStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用于监听字幕状态变化的流
  static Stream<Map<String, dynamic>> get subtitleStateStream =>
      _serviceManager?.onSubtitleStateChanged ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用于监听消息历史变化的流
  static Stream<List<RtcAigcMessage>> get messageHistoryStream =>
      _serviceManager?.onMessageHistoryChanged ??
      const Stream<List<RtcAigcMessage>>.empty();

  /// 用于获取消息历史
  static List<RtcAigcMessage> get messageHistory =>
      _serviceManager?.messageHistory ?? [];

  /// ---------- 音频相关流 ----------

  /// 用于监听音频状态变化的流
  static Stream<bool> get audioStatusStream =>
      _serviceManager?.rtcService.audioStatusStream ??
      const Stream<bool>.empty();

  /// 用于监听音频属性变化的流 (音量等)
  static Stream<Map<String, dynamic>> get audioPropertiesStream =>
      _serviceManager?.onAudioPropertiesChanged ??
      const Stream<Map<String, dynamic>>.empty();

  /// 播放器事件流
  static Stream<Map<String, dynamic>> get playerEventStream =>
      _playerEventController.stream;

  /// ---------- 状态和设备相关流 ----------

  /// 用于监听AI状态变化的流
  static Stream<RtcState> get stateStream =>
      _serviceManager?.rtcService.stateStream ?? const Stream<RtcState>.empty();

  /// 用于监听连接状态变化的流
  static Stream<RtcConnectionState> get connectionStateStream =>
      _serviceManager?.rtcService.connectionStateStream ??
      const Stream<RtcConnectionState>.empty();

  /// 用于监听设备变化的流
  static Stream<bool> get deviceStateStream =>
      _serviceManager?.rtcService.deviceStateStream ??
      const Stream<bool>.empty();

  /// 用于监听网络质量变化的流
  static Stream<Map<String, dynamic>> get networkQualityStream =>
      _serviceManager?.onNetworkQualityChanged ??
      const Stream<Map<String, dynamic>>.empty();

  /// ---------- RTC用户事件相关流 ----------

  /// 用户加入事件流
  static Stream<Map<String, dynamic>> get userJoinedStream =>
      _userJoinedController.stream;

  /// 用户离开事件流
  static Stream<Map<String, dynamic>> get userLeaveStream =>
      _userLeaveController.stream;

  /// 用户发布流事件流
  static Stream<Map<String, dynamic>> get userPublishStreamStream =>
      _userPublishStreamController.stream;

  /// 用户取消发布流事件流
  static Stream<Map<String, dynamic>> get userUnpublishStreamStream =>
      _userUnpublishStreamController.stream;

  /// 用户开始音频采集事件流
  static Stream<Map<String, dynamic>> get userStartAudioCaptureStream =>
      _userStartAudioCaptureController.stream;

  /// 用户停止音频采集事件流
  static Stream<Map<String, dynamic>> get userStopAudioCaptureStream =>
      _userStopAudioCaptureController.stream;

  /// Register this plugin
  static void registerWith(Registrar registrar) {
    // 确保Flutter binding已初始化
    WidgetsFlutterBinding.ensureInitialized();

    // 注册方法通道处理原生平台调用 (非Web)
    _channel.setMethodCallHandler(_handleMethodCall);

    debugPrint('RTC AIGC Plugin 注册完成');
  }

  /// 处理来自原生平台的方法调用
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('【RTC Plugin】收到原生平台方法调用: ${call.method}');

    switch (call.method) {
      case 'onUserJoined':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_onUserJoined != null) {
          _onUserJoined!(data);
        }
        _userJoinedController.add(data);
        return;

      case 'onUserLeave':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_onUserLeave != null) {
          _onUserLeave!(data);
        }
        _userLeaveController.add(data);
        return;

      case 'onUserPublishStream':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_onUserPublishStream != null) {
          _onUserPublishStream!(data);
        }
        _userPublishStreamController.add(data);
        return;

      case 'onUserUnpublishStream':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_onUserUnpublishStream != null) {
          _onUserUnpublishStream!(data);
        }
        _userUnpublishStreamController.add(data);
        return;

      case 'onUserStartAudioCapture':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_onUserStartAudioCapture != null) {
          _onUserStartAudioCapture!(data);
        }
        _userStartAudioCaptureController.add(data);
        return;

      case 'onUserStopAudioCapture':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_onUserStopAudioCapture != null) {
          _onUserStopAudioCapture!(data);
        }
        _userStopAudioCaptureController.add(data);
        return;

      default:
        return;
    }
  }

  /// 设置事件监听器
  static void _setupEventListeners() {
    if (_serviceManager == null) return;

    // 监听用户相关事件
    _serviceManager!.rtcService.eventManager.userJoinStream.listen((userId) {
      debugPrint('【RTC Plugin】用户加入: $userId');
      final data = {'userId': userId};
      _userJoinedController.add(data);

      if (_onUserJoined != null) {
        _onUserJoined!(data);
      }
    });

    _serviceManager!.rtcService.eventManager.userLeaveStream.listen((userId) {
      debugPrint('【RTC Plugin】用户离开: $userId');
      final data = {'userId': userId};
      _userLeaveController.add(data);

      if (_onUserLeave != null) {
        _onUserLeave!(data);
      }
    });

    _serviceManager!.rtcService.userPublishStreamStream.listen((data) {
      debugPrint('【RTC Plugin】用户发布流事件: $data');
      _userPublishStreamController.add(data);

      if (_onUserPublishStream != null) {
        _onUserPublishStream!(data);
      }
    });

    _serviceManager!.rtcService.eventManager.userStartAudioCaptureStream
        .listen((userId) {
      debugPrint('【RTC Plugin】用户开始音频采集: $userId');
      final data = {'userId': userId};
      _userStartAudioCaptureController.add(data);

      if (_onUserStartAudioCapture != null) {
        _onUserStartAudioCapture!(data);
      }
    });

    _serviceManager!.rtcService.eventManager.playerEventStream.listen((data) {
      debugPrint('【RTC Plugin】播放器事件: $data');
      _playerEventController.add(data);
    });
  }

  /// Initialize the plugin
  static Future<bool> initialize({
    required String appId,
    required String roomId,
    required String userId,
    required String token,
    required String taskId,
    required String serverUrl,
    AsrConfig? asrConfig,
    TtsConfig? ttsConfig,
    LlmConfig? llmConfig,
    void Function(String state, String? message)? onStateChange,
    void Function(String text, bool isUser)? onMessage,
    void Function(bool isPlaying)? onAudioStatusChange,
    void Function(List<dynamic> audioDevices)? onAudioDevicesChanged,
    void Function(Map<String, dynamic> subtitle)? onSubtitle,
    void Function(Map<String, dynamic> data)? onUserJoined,
    void Function(Map<String, dynamic> data)? onUserLeave,
    void Function(Map<String, dynamic> data)? onUserPublishStream,
    void Function(Map<String, dynamic> data)? onUserUnpublishStream,
    void Function(Map<String, dynamic> data)? onUserStartAudioCapture,
    void Function(Map<String, dynamic> data)? onUserStopAudioCapture,
  }) async {
    try {
      // 确保Flutter binding已初始化
      WidgetsFlutterBinding.ensureInitialized();

      // 参数验证
      if (appId.isEmpty) {
        debugPrint('RtcAigcPlugin initialize error: AppID不能为空');
        return false;
      }

      if (roomId.isEmpty) {
        debugPrint('RtcAigcPlugin initialize error: RoomID不能为空');
        return false;
      }

      if (userId.isEmpty) {
        debugPrint('RtcAigcPlugin initialize error: UserID不能为空');
        return false;
      }

      if (token.isEmpty) {
        debugPrint('RtcAigcPlugin initialize error: Token不能为空');
        return false;
      }

      // 存储回调
      _onStateChange = onStateChange;
      _onMessage = onMessage;
      _onAudioStatusChange = onAudioStatusChange;
      _onAudioDevicesChanged = onAudioDevicesChanged;
      _onSubtitle = onSubtitle;
      _onUserJoined = onUserJoined;
      _onUserLeave = onUserLeave;
      _onUserPublishStream = onUserPublishStream;
      _onUserUnpublishStream = onUserUnpublishStream;
      _onUserStartAudioCapture = onUserStartAudioCapture;
      _onUserStopAudioCapture = onUserStopAudioCapture;

      if (kIsWeb) {
        // 创建配置对象
        final config = RtcConfig(
          appId: appId,
          roomId: roomId,
          userId: userId,
          taskId: taskId,
          token: token,
          serverUrl: serverUrl,
          asrConfig: asrConfig ?? const AsrConfig(),
          ttsConfig: ttsConfig ?? const TtsConfig(),
          llmConfig: llmConfig ?? const LlmConfig(),
        );

        // 创建服务管理器
        _serviceManager = ServiceManager(config: config);

        // 设置回调
        _serviceManager!.setOnStateChange((state, message) {
          debugPrint('状态变化: $state, $message');
          if (_onStateChange != null) {
            _onStateChange!(state, message);
          }
        });

        if (_onMessage != null) {
          _serviceManager!.setOnMessage((message) {
            _onMessage!(message.text ?? '', message.isUser ?? false);
          });
        }

        if (_onAudioStatusChange != null) {
          _serviceManager!.setOnAudioStatusChange(_onAudioStatusChange!);
        }

        if (_onAudioDevicesChanged != null) {
          _serviceManager!.setOnAudioDevicesChange(_onAudioDevicesChanged!);
        }

        if (_onSubtitle != null) {
          _serviceManager!.setOnSubtitle(_onSubtitle!);
        }

        // 初始化服务
        final success = await _serviceManager!.initialize();

        if (success) {
          // 设置事件监听器
          _setupEventListeners();
        }

        return success;
      } else {
        // 非Web平台使用方法通道
        final Map<String, dynamic> arguments = {
          'appId': appId,
          'roomId': roomId,
          'userId': userId,
          'token': token,
          'taskId': taskId,
          'serverUrl': serverUrl,
          if (asrConfig != null) 'asrConfig': asrConfig.toMap(),
          if (ttsConfig != null) 'ttsConfig': ttsConfig.toMap(),
          if (llmConfig != null) 'llmConfig': llmConfig.toMap(),
        };

        final result = await _channel.invokeMethod('initialize', arguments);
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error initializing plugin: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to initialize plugin: $e');
      }
      return false;
    }
  }

  /// Join an RTC room
  static Future<bool> joinRoom({
    String? roomId,
    String? userId,
    String? token,
  }) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.joinRoom(
          roomId: roomId ?? _serviceManager!.config.roomId,
          userId: userId ?? _serviceManager!.config.userId,
          token: token ?? _serviceManager!.config.token,
        );
      } else {
        final Map<String, dynamic> arguments = {
          if (roomId != null) 'roomId': roomId,
          if (userId != null) 'userId': userId,
          if (token != null) 'token': token,
        };

        final result = await _channel.invokeMethod('joinRoom', arguments);
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to join room: $e');
      }
      return false;
    }
  }

  /// Start a conversation with the AI
  static Future<bool> startConversation({
    String? welcomeMessage,
  }) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.startConversation();
      } else {
        final Map<String, dynamic> arguments = {
          if (welcomeMessage != null) 'welcomeMessage': welcomeMessage,
        };

        final result =
            await _channel.invokeMethod('startConversation', arguments);
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to start conversation: $e');
      }
      return false;
    }
  }

  /// Leave the RTC room
  static Future<bool> leaveRoom() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.leaveRoom();
      } else {
        final result = await _channel.invokeMethod('leaveRoom');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to leave room: $e');
      }
      return false;
    }
  }

  /// Stop the current conversation
  static Future<bool> stopConversation() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.stopConversation();
      } else {
        final result = await _channel.invokeMethod('stopConversation');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error stopping conversation: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to stop conversation: $e');
      }
      return false;
    }
  }

  /// 设置音频输入设备
  static Future<bool> setAudioInputDevice(String deviceId) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.setAudioInputDevice(deviceId);
      } else {
        final result = await _channel
            .invokeMethod('setAudioInputDevice', {'deviceId': deviceId});
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error setting audio input device: $e');
      return false;
    }
  }

  /// 设置音频输出设备
  static Future<bool> setAudioOutputDevice(String deviceId) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.setAudioOutputDevice(deviceId);
      } else {
        final result = await _channel
            .invokeMethod('setAudioOutputDevice', {'deviceId': deviceId});
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error setting audio output device: $e');
      return false;
    }
  }

  /// 发送文本消息给AI
  static Future<bool> sendMessage(String message) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.sendMessage(message);
      } else {
        final result =
            await _channel.invokeMethod('sendMessage', {'message': message});
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// 发送文本消息给AI (兼容旧版本API)
  @Deprecated('Use sendMessage() instead')
  static Future<bool> sendTextMessage(String message) async {
    return sendMessage(message);
  }

  /// Interrupt the current AI response
  static Future<bool> interruptConversation() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.interruptConversation();
      } else {
        final result = await _channel.invokeMethod('interruptConversation');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error interrupting conversation: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to interrupt conversation: $e');
      }
      return false;
    }
  }

  /// Get available audio input devices (microphones)
  static Future<List<Map<String, String>>> getAudioInputDevices() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.getAudioInputDevices();
      } else {
        final result = await _channel.invokeMethod('getAudioInputDevices');

        if (result is List) {
          return result.map((e) => Map<String, String>.from(e)).toList();
        } else if (result is Map && result['devices'] is List) {
          return (result['devices'] as List)
              .map((e) => Map<String, String>.from(e))
              .toList();
        }

        return [];
      }
    } catch (e) {
      debugPrint('Error getting audio input devices: $e');
      return [];
    }
  }

  /// Get available audio output devices (speakers)
  static Future<List<Map<String, String>>> getAudioOutputDevices() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.getAudioOutputDevices();
      } else {
        final result = await _channel.invokeMethod('getAudioOutputDevices');

        if (result is List) {
          return result.map((e) => Map<String, String>.from(e)).toList();
        } else if (result is Map && result['devices'] is List) {
          return (result['devices'] as List)
              .map((e) => Map<String, String>.from(e))
              .toList();
        }

        return [];
      }
    } catch (e) {
      debugPrint('Error getting audio output devices: $e');
      return [];
    }
  }

  /// Get the current audio input device ID
  static Future<String?> getCurrentAudioInputDevice() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return _serviceManager!.rtcService.getCurrentAudioInputDeviceId();
      } else {
        return await _channel.invokeMethod('getCurrentAudioInputDevice');
      }
    } catch (e) {
      debugPrint('Error getting current audio input device: $e');
      return null;
    }
  }

  /// Get the current audio output device ID
  static Future<String?> getCurrentAudioOutputDevice() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return _serviceManager!.rtcService.getCurrentAudioOutputDeviceId();
      } else {
        return await _channel.invokeMethod('getCurrentAudioOutputDevice');
      }
    } catch (e) {
      debugPrint('Error getting current audio output device: $e');
      return null;
    }
  }

  /// Request access to microphone
  static Future<Map<String, dynamic>> requestMicrophoneAccess() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        final success = await _serviceManager!.requestMicrophoneAccess();
        return {'success': success};
      } else {
        final result = await _channel.invokeMethod('requestMicrophoneAccess');
        return result is Map<String, dynamic> ? result : {'success': result};
      }
    } catch (e) {
      debugPrint('Error requesting microphone access: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 开始音频采集
  static Future<bool> startAudioCapture({String? deviceId}) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.startAudioCapture(deviceId);
      } else {
        final result = await _channel
            .invokeMethod('startAudioCapture', {'deviceId': deviceId});
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error starting audio capture: $e');
      return false;
    }
  }

  /// 停止音频采集
  static Future<bool> stopAudioCapture() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        return await _serviceManager!.stopAudioCapture();
      } else {
        final result = await _channel.invokeMethod('stopAudioCapture');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error stopping audio capture: $e');
      return false;
    }
  }

  /// Dispose the plugin and release all resources
  static Future<bool> dispose() async {
    try {
      if (kIsWeb && _serviceManager != null) {
        // 销毁服务管理器
        await _serviceManager!.dispose();
        _serviceManager = null;
      } else {
        await _channel.invokeMethod('dispose');
      }

      // 清除回调
      _onStateChange = null;
      _onMessage = null;
      _onAudioStatusChange = null;
      _onAudioDevicesChanged = null;
      _onSubtitle = null;
      _onUserJoined = null;
      _onUserLeave = null;
      _onUserPublishStream = null;
      _onUserUnpublishStream = null;
      _onUserStartAudioCapture = null;
      _onUserStopAudioCapture = null;

      // 关闭事件控制器
      await _userJoinedController.close();
      await _userLeaveController.close();
      await _userPublishStreamController.close();
      await _userUnpublishStreamController.close();
      await _userStartAudioCaptureController.close();
      await _userStopAudioCaptureController.close();
      await _playerEventController.close();

      return true;
    } catch (e) {
      debugPrint('Error disposing plugin: $e');
      return false;
    }
  }

  /// 静音/取消静音
  static Future<bool> muteAudio(bool mute) async {
    try {
      if (kIsWeb && _serviceManager != null) {
        // 通过停止/开始音频采集来实现静音
        if (mute) {
          return await _serviceManager!.stopAudioCapture();
        } else {
          return await _serviceManager!.startAudioCapture(null);
        }
      } else {
        final result = await _channel.invokeMethod('muteAudio', {'mute': mute});
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error muting audio: $e');
      return false;
    }
  }
}
