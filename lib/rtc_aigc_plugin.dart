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
      // Ensure we don't initialize twice
      if (_rtcService != null) {
        debugPrint('RTC AIGC plugin already initialized');
        return true;
      }

      debugPrint('Initializing RTC AIGC plugin...');

      // Pre-check SDK status for diagnostics
      try {
        debugPrint('Pre-checking SDK loading status...');
        final isSdkLoaded = await WebUtils.isSdkLoaded();
        debugPrint(
            'SDK pre-check result: ${isSdkLoaded ? "loaded" : "not loaded"}');
      } catch (e) {
        debugPrint('SDK pre-check error (non-fatal): $e');
      }

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

      // Explicitly initialize the RtcService
      debugPrint('Starting RtcService initialization sequence...');
      final success = await _rtcService!.initialize();

      if (success) {
        debugPrint('RTC AIGC plugin initialized successfully');
      } else {
        debugPrint('RTC AIGC plugin initialization failed');
      }

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
        return await _rtcService!
            .joinRoom(roomId: roomId, userId: userId, token: token);
    } catch (e, s) {
      debugPrint('Error joining room: $e ${s.toString()}');
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
        _rtcService!.onStateChange!(
            'error', 'Failed to stop conversation: $e');
      }
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

  /// 开始音频采集
  static Future<Map<String, dynamic>> startAudioCapture({String? deviceId}) async {
    try {
      if (_rtcService != null) {
        final result = await _rtcService!.startAudioCapture(deviceId);
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      } else {
        final result = await _channel
            .invokeMethod('startAudioCapture', {'deviceId': deviceId});
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      }
    } catch (e) {
      debugPrint('Error starting audio capture: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 停止音频采集
  static Future<Map<String, dynamic>> stopAudioCapture() async {
    try {
      if (_rtcService != null) {
        final result = await _rtcService!.stopAudioCapture();
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      } else {
        final result = await _channel.invokeMethod('stopAudioCapture');
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      }
    } catch (e) {
      debugPrint('Error stopping audio capture: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 静音/取消静音
  static Future<Map<String, dynamic>> muteAudio(bool mute) async {
    try {
      if (_rtcService != null) {
        // 通过停止/开始音频采集来实现静音
        if (mute) {
          return await stopAudioCapture();
        } else {
          return await startAudioCapture();
        }
      } else {
        final result = await _channel.invokeMethod('muteAudio', {'mute': mute});
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      }
    } catch (e) {
      debugPrint('Error muting audio: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 设置音频采集音量
  static Future<Map<String, dynamic>> setAudioCaptureVolume(int volume) async {
    try {
      if (_rtcService != null) {
        final result = await _rtcService!.setAudioCaptureVolume(volume);
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      } else {
        final result = await _channel.invokeMethod('setAudioCaptureVolume', {'volume': volume});
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      }
    } catch (e) {
      debugPrint('Error setting audio volume: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// 切换音频设备
  static Future<Map<String, dynamic>> switchAudioDevice(String deviceId) async {
    try {
      if (_rtcService != null) {
        final result = await _rtcService!.switchAudioDevice(deviceId);
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      } else {
        final result = await _channel.invokeMethod('switchAudioDevice', {'deviceId': deviceId});
        if (result is bool) {
          return {'success': result};
        } else if (result is Map<String, dynamic>) {
          return result;
        }
        return {'success': false, 'error': '未知返回类型'};
      }
    } catch (e) {
      debugPrint('Error switching audio device: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 获取音频输入设备列表
  static Future<List<Map<String, dynamic>>> getAudioInputDevices() async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.getAudioInputDevices();
      } else {
        final result = await _channel.invokeMethod('getAudioInputDevices');
        if (result is List) {
          return List<Map<String, dynamic>>.from(
            result.map((item) => Map<String, dynamic>.from(item))
          );
        }
        return [];
      }
    } catch (e) {
      debugPrint('Error getting audio input devices: $e');
      return [];
    }
  }
  
  /// 刷新设备列表 - 手动调用以更新可用设备
  /// 
  /// 主动刷新当前可用的音频设备列表，解决重复设备问题
  /// 当设备列表发生变化时，会自动发送通知到deviceStateStream
  /// 
  /// @return 刷新后的音频输入设备列表
  static Future<List<Map<String, dynamic>>> refreshDevices() async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.refreshDevices();
      } else {
        final result = await _channel.invokeMethod('refreshDevices');
        if (result is List) {
          return List<Map<String, dynamic>>.from(
            result.map((item) => Map<String, dynamic>.from(item))
          );
        }
        return [];
      }
    } catch (e) {
      debugPrint('Error refreshing devices: $e');
      return [];
    }
  }
  
  /// 获取音频输出设备列表
  static Future<List<Map<String, dynamic>>> getAudioOutputDevices() async {
    try {
      if (_rtcService != null) {
        return await _rtcService!.getAudioOutputDevices();
      } else {
        final result = await _channel.invokeMethod('getAudioOutputDevices');
        if (result is List) {
          return List<Map<String, dynamic>>.from(
            result.map((item) => Map<String, dynamic>.from(item))
          );
        }
        return [];
      }
    } catch (e) {
      debugPrint('Error getting audio output devices: $e');
      return [];
    }
  }
}
