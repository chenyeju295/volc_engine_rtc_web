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
export 'src/config/aigc_config.dart';
// 导出工具类
export 'src/utils/rtc_message_utils.dart';
export 'src/utils/web_utils.dart';

export 'src/services/rtc_service.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
import 'package:rtc_aigc_plugin/src/config/aigc_config.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_device_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_engine_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_event_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_message_handler.dart';

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

  // RTC service instance
  static RtcService? _rtcService;

  // 回调函数
  static StreamSubscription? _stateSubscription;

  /// Initialize the plugin
  static Future<bool> initialize({required AigcConfig config}) async {
    try {
      // Create necessary internal components
      final engineManager = RtcEngineManager(config: config);
      final messageHandler = RtcMessageHandler();
      final eventManager = RtcEventManager(messageHandler: messageHandler);
      final deviceManager = RtcDeviceManager(engineManager: engineManager);

      // Create RtcService
      _rtcService = RtcService(
        config: config,
        engineManager: engineManager,
        deviceManager: deviceManager,
        eventManager: eventManager,
        messageHandler: messageHandler,
      );

      debugPrint('Initialize RTC AIGC plugin');
      final success = await _rtcService!.initialize();
      return success;
    } catch (e) {
      debugPrint('Failed to initialize RTC AIGC plugin: $e');
      return false;
    }
  }

  /// Get RtcService instance
  static RtcService? get rtcService => _rtcService;

  /// Clean up resources
  static Future<void> dispose() async {
    try {
      if (_rtcService != null) {
        await _rtcService!.dispose();
        _rtcService = null;
      }

      if (_stateSubscription != null) {
        await _stateSubscription!.cancel();
        _stateSubscription = null;
      }
    } catch (e) {
      debugPrint('Error during dispose: $e');
    }
  }

  /// ---------- 字幕和消息相关流 ----------

  /// 用于监听字幕变化的流
  static Stream<Map<String, dynamic>> get subtitleStream =>
      _rtcService?.subtitleStream ?? const Stream<Map<String, dynamic>>.empty();

  /// 用于监听字幕状态变化的流
  static Stream<Map<String, dynamic>> get subtitleStateStream =>
      _rtcService?.subtitleStream ?? const Stream<Map<String, dynamic>>.empty();

  /// 用于监听消息历史变化的流
  static Stream<List<RtcAigcMessage>> get messageHistoryStream =>
      _rtcService?.messageHistoryStream ??
      const Stream<List<RtcAigcMessage>>.empty();

  /// 用于获取消息历史
  static List<RtcAigcMessage> get messageHistory =>
      _rtcService?.getMessageHistory() ?? [];

  /// ---------- 音频相关流 ----------

  /// 用于监听音频状态变化的流
  static Stream<bool> get audioStatusStream =>
      _rtcService?.audioStatusStream ?? const Stream<bool>.empty();

  /// 用于监听音频属性变化的流 (音量等)
  static Stream<Map<String, dynamic>> get audioPropertiesStream =>
      _rtcService?.localAudioPropertiesStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// ---------- 状态和设备相关流 ----------

  /// 用于监听AI状态变化的流
  static Stream<RtcState> get stateStream =>
      _rtcService?.stateStream ?? const Stream<RtcState>.empty();

  /// 用于监听连接状态变化的流
  static Stream<RtcConnectionState> get connectionStateStream =>
      _rtcService?.connectionStateStream ??
      const Stream<RtcConnectionState>.empty();

  /// 用于监听设备变化的流
  static Stream<bool> get deviceStateStream =>
      _rtcService?.deviceStateStream ?? const Stream<bool>.empty();

  /// 用于监听网络质量变化的流
  static Stream<Map<String, dynamic>> get networkQualityStream =>
      _rtcService?.networkQualityStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// ---------- RTC用户事件相关流 ----------

  /// 用户加入事件流
  static Stream<Map<String, dynamic>> get userJoinedStream =>
      _rtcService?.userJoinedStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用户离开事件流
  static Stream<Map<String, dynamic>> get userLeaveStream =>
      _rtcService?.userLeaveStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用户发布流事件流
  static Stream<Map<String, dynamic>> get userPublishStreamStream =>
      _rtcService?.userPublishStreamStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用户取消发布流事件流
  static Stream<Map<String, dynamic>> get userUnpublishStreamStream =>
      _rtcService?.userUnpublishStreamStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用户开始音频采集事件流
  static Stream<Map<String, dynamic>> get userStartAudioCaptureStream =>
      _rtcService?.userStartAudioCaptureStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用户停止音频采集事件流
  static Stream<Map<String, dynamic>> get userStopAudioCaptureStream =>
      _rtcService?.userStopAudioCaptureStream ??
      const Stream<Map<String, dynamic>>.empty();

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
        if (_rtcService?.onUserJoined != null) {
          _rtcService!.onUserJoined!(data);
        }
        return;

      case 'onUserLeave':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_rtcService?.onUserLeave != null) {
          _rtcService!.onUserLeave!(data);
        }
        return;

      case 'onUserPublishStream':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_rtcService?.onUserPublishStream != null) {
          _rtcService!.onUserPublishStream!(data);
        }
        return;

      case 'onUserUnpublishStream':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_rtcService?.onUserUnpublishStream != null) {
          _rtcService!.onUserUnpublishStream!(data);
        }
        return;

      case 'onUserStartAudioCapture':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_rtcService?.onUserStartAudioCapture != null) {
          _rtcService!.onUserStartAudioCapture!(data);
        }
        return;

      case 'onUserStopAudioCapture':
        final data = Map<String, dynamic>.from(call.arguments);
        if (_rtcService?.onUserStopAudioCapture != null) {
          _rtcService!.onUserStopAudioCapture!(data);
        }
        return;

      default:
        return;
    }
  }

  /// Join an RTC room
  static Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String token,
  }) async {
    try {
      if (_rtcService != null) {
        return await _rtcService!
            .joinRoom(roomId: roomId, userId: userId, token: token);
      } else {
        final Map<String, dynamic> arguments = {
          'roomId': roomId,
          'userId': userId,
          'token': token,
        };

        final result = await _channel.invokeMethod('joinRoom', arguments);
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
      if (_rtcService?.onStateChange != null) {
        _rtcService!.onStateChange!('error', 'Failed to join room: $e');
      }
      return false;
    }
  }

  /// Start a conversation with the AI
  static Future<bool> startConversation({
    String? welcomeMessage,
  }) async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.startConversation();
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
      if (_rtcService?.onStateChange != null) {
        _rtcService!.onStateChange!(
            'error', 'Failed to start conversation: $e');
      }
      return false;
    }
  }

  /// Leave the RTC room
  static Future<bool> leaveRoom() async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.leaveRoom();
      } else {
        final result = await _channel.invokeMethod('leaveRoom');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
      if (_rtcService?.onStateChange != null) {
        _rtcService!.onStateChange!('error', 'Failed to leave room: $e');
      }
      return false;
    }
  }

  /// Stop the current conversation
  static Future<bool> stopConversation() async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.stopConversation();
      } else {
        final result = await _channel.invokeMethod('stopConversation');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error stopping conversation: $e');
      if (_rtcService?.onStateChange != null) {
        _rtcService!.onStateChange!('error', 'Failed to stop conversation: $e');
      }
      return false;
    }
  }

  /// 设置音频输入设备
  static Future<bool> setAudioInputDevice(String deviceId) async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.setAudioCaptureDevice(deviceId);
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
      if (_rtcService != null) {
        return await _rtcService!.setAudioPlaybackDevice(deviceId);
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
      if (_rtcService != null) {
        return await _rtcService!.sendTextMessage(message);
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
      if (_rtcService != null) {
        return await _rtcService!.interruptConversation();
      } else {
        final result = await _channel.invokeMethod('interruptConversation');
        return result is bool
            ? result
            : (result is Map && result['success'] == true);
      }
    } catch (e) {
      debugPrint('Error interrupting conversation: $e');
      if (_rtcService?.onStateChange != null) {
        _rtcService!.onStateChange!(
            'error', 'Failed to interrupt conversation: $e');
      }
      return false;
    }
  }

  /// Get available audio input devices (microphones)
  static Future<List<Map<String, String>>> getAudioInputDevices() async {
    try {
      if (_rtcService != null) {
        final devices = await _rtcService!.getAudioInputDevices();
        return devices.map((e) => Map<String, String>.from(e)).toList();
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
      if (_rtcService != null) {
        final devices = await _rtcService!.getAudioOutputDevices();
        return devices.map((e) => Map<String, String>.from(e)).toList();
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
      if (_rtcService != null) {
        return await _rtcService!.getCurrentAudioInputDeviceId();
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
      if (_rtcService != null) {
        return await _rtcService!.getCurrentAudioOutputDeviceId();
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
      if (_rtcService != null) {
        final success = await _rtcService!.requestCameraAccess();
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
      if (_rtcService != null) {
        return await _rtcService!.startAudioCapture(deviceId);
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
      if (_rtcService != null) {
        return await _rtcService!.stopAudioCapture();
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

  /// 静音/取消静音
  static Future<bool> muteAudio(bool mute) async {
    try {
      if (_rtcService != null) {
        // 通过停止/开始音频采集来实现静音
        if (mute) {
          return await _rtcService!.stopAudioCapture();
        } else {
          return await _rtcService!.startAudioCapture(null);
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
