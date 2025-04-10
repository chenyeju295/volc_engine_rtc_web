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

// 导出Web平台实现
export 'rtc_aigc_plugin_web.dart';

export 'src/services/service_interface.dart';

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
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin_web.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';

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
/// final plugin = RtcAigcPlugin();
///
/// // 配置和初始化RTC服务
/// await plugin.handleMethodCall(MethodCall('initialize', {
///   'appId': 'your_app_id',
///   'roomId': 'your_room_id',
///   'userId': 'user_123',
///   'token': 'your_rtc_token',
///   'serverUrl': 'https://your-api-server.com',
/// }));
///
/// // 加入房间
/// await plugin.handleMethodCall(MethodCall('joinRoom'));
///
/// // 开始与AI对话
/// await plugin.handleMethodCall(MethodCall('startConversation', {
///   'welcomeMessage': '你好，我是AI助手，有什么可以帮助你的？',
/// }));
///
/// // 监听AI返回的消息
/// plugin.messageHistoryStream.listen((message) {
///   // 使用RtcAigcMessageUtils格式化消息
///   final formattedMessage = RtcAigcMessageUtils.formatMessageForUI(message);
///   print('收到消息: ${formattedMessage['text']}');
/// });
///
/// // 发送文本消息给AI
/// await plugin.handleMethodCall(MethodCall('sendMessage', {
///   'message': '今天天气怎么样？',
/// }));
///
/// // 中断AI的回答
/// await plugin.handleMethodCall(MethodCall('interruptConversation'));
///
/// // 停止对话
/// await plugin.handleMethodCall(MethodCall('stopConversation'));
///
/// // 离开房间
/// await plugin.handleMethodCall(MethodCall('leaveRoom'));
/// ```
///
/// 更多高级用法请参考完整文档和示例代码
class RtcAigcPlugin {
  static const MethodChannel _channel = MethodChannel('rtc_aigc_plugin');

  // Web实现实例
  static RtcAigcPluginWeb? _webImpl;

  // 回调函数
  static void Function(String state, String? message)? _onStateChange;
  static void Function(String text, bool isUser)? _onMessage;
  static void Function(bool isPlaying)? _onAudioStatusChange;
  static void Function(List<dynamic> audioDevices)? _onAudioDevicesChanged;
  static void Function(Map<String, dynamic> subtitle)? _onSubtitle;

  /// 用于监听字幕变化的流
  static Stream<Object?> get subtitleStream =>
      _webImpl?.subtitleStream ?? const Stream.empty();

  /// 用于监听AI状态变化的流
  static Stream<Object> get stateStream =>
      _webImpl?.stateStream ?? const Stream.empty();

  /// 用于监听音频状态变化的流
  static Stream<bool> get audioStatusStream =>
      _webImpl?.audioStatusStream ?? const Stream.empty();

  /// 用于监听连接状态变化的流
  static Stream get connectionStateStream =>
      _webImpl?.connectionStateStream ?? const Stream.empty();

  /// 用于监听设备变化的流
  static Stream<Object> get deviceStateStream =>
      _webImpl?.deviceStateStream ?? const Stream.empty();

  /// 用于监听消息历史变化的流
  static Stream<Object> get messageHistoryStream =>
      _webImpl?.messageHistoryStream ?? const Stream.empty();

  /// 用于获取消息历史
  static List<Object> get messageHistory => _webImpl?.messageHistory ?? [];

  /// 用于监听字幕状态变化的流
  static Stream<Map<String, dynamic>> get subtitleStateStream =>
      _webImpl?.subtitleStateStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用于监听音频属性变化的流 (音量等)
  static Stream<Map<String, dynamic>> get audioPropertiesStream =>
      _webImpl?.audioPropertiesStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// 用于监听网络质量变化的流
  static Stream<Map<String, dynamic>> get networkQualityStream =>
      _webImpl?.networkQualityStream ??
      const Stream<Map<String, dynamic>>.empty();

  /// Factory constructor to enforce singleton instance of the plugin
  factory RtcAigcPlugin() => _instance;

  /// Private constructor
  RtcAigcPlugin._();

  /// Singleton instance
  static final RtcAigcPlugin _instance = RtcAigcPlugin._();

  /// Register this plugin
  static void registerWith(Registrar registrar) {
    RtcAigcPluginWeb.registerWith(registrar);
    if (kIsWeb) {
      // 在Web平台使用Web实现
      _webImpl = RtcAigcPluginWeb();
    }
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
  }) async {
    try {
      // Store callbacks
      _onStateChange = onStateChange;
      _onMessage = onMessage;
      _onAudioStatusChange = onAudioStatusChange;
      _onAudioDevicesChanged = onAudioDevicesChanged;
      _onSubtitle = onSubtitle;

      if (kIsWeb && _webImpl != null) {
        // 使用Web实现
        final result =
            await _webImpl!.handleMethodCall(MethodCall('initialize', {
          'appId': appId,
          'roomId': roomId,
          'userId': userId,
          'token': token,
          'taskId': taskId,
          'serverUrl': serverUrl,
          if (asrConfig != null) 'asrConfig': asrConfig.toMap(),
          if (ttsConfig != null) 'ttsConfig': ttsConfig.toMap(),
          if (llmConfig != null) 'llmConfig': llmConfig.toMap(),
        }));

        return result['success'] == true;
      } else {
        // 非Web平台使用方法通道
        final result = await _channel.invokeMethod<bool>('initialize', {
          'appId': appId,
          'roomId': roomId,
          'userId': userId,
          'token': token,
          'taskId': taskId,
          'serverUrl': serverUrl,
          if (asrConfig != null) 'asrConfig': asrConfig.toMap(),
          if (ttsConfig != null) 'ttsConfig': ttsConfig.toMap(),
          if (llmConfig != null) 'llmConfig': llmConfig.toMap(),
        });

        return result ?? false;
      }
    } catch (e) {
      print('Error initializing plugin: $e');
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
      final Map<String, dynamic> args = {
        if (roomId != null) 'roomId': roomId,
        if (userId != null) 'userId': userId,
        if (token != null) 'token': token,
      };

      if (kIsWeb && _webImpl != null) {
        final result =
            await _webImpl!.handleMethodCall(MethodCall('joinRoom', args));
        return result['success'] == true;
      } else {
        final result = await _channel.invokeMethod<bool>('joinRoom', args);
        return result ?? false;
      }
    } catch (e) {
      print('Error joining room: $e');
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
      final Map<String, dynamic> args = {
        'welcomeMessage': welcomeMessage,
      };

      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!
            .handleMethodCall(MethodCall('startConversation', args));
        return result['success'] == true;
      } else {
        return await _channel.invokeMethod('startConversation', args);
      }
    } catch (e) {
      print('Error starting conversation: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to start conversation: $e');
      }
      return false;
    }
  }

  /// Stop the current conversation
  static Future<bool> stopConversation() async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result =
            await _webImpl!.handleMethodCall(MethodCall('stopConversation'));
        return result['success'] == true;
      } else {
        final result = await _channel.invokeMethod<bool>('stopConversation');
        return result ?? false;
      }
    } catch (e) {
      print('Error stopping conversation: $e');
      return false;
    }
  }

  /// Send a text message to the AI
  static Future<bool> sendTextMessage(String message) async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!
            .handleMethodCall(MethodCall('sendMessage', {'message': message}));
        return result['success'] == true;
      } else {
        return await _channel.invokeMethod('sendTextMessage', message);
      }
    } catch (e) {
      print('Error sending message: $e');
      if (_onStateChange != null) {
        _onStateChange!('error', 'Failed to send message: $e');
      }
      return false;
    }
  }

  /// Interrupt the current AI response
  static Future<bool> interruptConversation() async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!
            .handleMethodCall(MethodCall('interruptConversation'));
        return result['success'] == true;
      } else {
        final result =
            await _channel.invokeMethod<bool>('interruptConversation');
        return result ?? false;
      }
    } catch (e) {
      print('Error interrupting conversation: $e');
      return false;
    }
  }

  /// Get available audio input devices (microphones)
  static Future<List<Map<String, String>>> getAudioInputDevices() async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!
            .handleMethodCall(MethodCall('getAudioInputDevices'));
        if (result['devices'] is List) {
          return (result['devices'] as List)
              .map((e) => Map<String, String>.from(e))
              .toList();
        }
      } else {
        final result = await _channel.invokeMethod('getAudioInputDevices');
        if (result is List) {
          return result.map((e) => Map<String, String>.from(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting audio input devices: $e');
      return [];
    }
  }

  /// Get available audio output devices (speakers)
  static Future<List<Map<String, String>>> getAudioOutputDevices() async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!
            .handleMethodCall(MethodCall('getAudioOutputDevices'));
        if (result['devices'] is List) {
          return (result['devices'] as List)
              .map((e) => Map<String, String>.from(e))
              .toList();
        }
      } else {
        final result = await _channel.invokeMethod('getAudioOutputDevices');
        if (result is List) {
          return result.map((e) => Map<String, String>.from(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting audio output devices: $e');
      return [];
    }
  }

  /// Set the audio input device (microphone)
  static Future<bool> setAudioInputDevice(String deviceId) async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!.handleMethodCall(
            MethodCall('setAudioInputDevice', {'deviceId': deviceId}));
        return result['success'] == true;
      } else {
        return await _channel.invokeMethod('setAudioInputDevice', deviceId);
      }
    } catch (e) {
      print('Error setting audio input device: $e');
      return false;
    }
  }

  /// Set the audio output device (speaker)
  static Future<bool> setAudioOutputDevice(String deviceId) async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!.handleMethodCall(
            MethodCall('setAudioOutputDevice', {'deviceId': deviceId}));
        return result['success'] == true;
      } else {
        return await _channel.invokeMethod('setAudioOutputDevice', deviceId);
      }
    } catch (e) {
      print('Error setting audio output device: $e');
      return false;
    }
  }

  /// Get the current audio input device ID
  static Future<String?> getCurrentAudioInputDevice() async {
    try {
      if (kIsWeb && _webImpl != null) {
        return await _webImpl!
            .handleMethodCall(MethodCall('getCurrentAudioInputDevice'));
      } else {
        return await _channel.invokeMethod('getCurrentAudioInputDevice');
      }
    } catch (e) {
      print('Error getting current audio input device: $e');
      return null;
    }
  }

  /// Get the current audio output device ID
  static Future<String?> getCurrentAudioOutputDevice() async {
    try {
      if (kIsWeb && _webImpl != null) {
        return await _webImpl!
            .handleMethodCall(MethodCall('getCurrentAudioOutputDevice'));
      } else {
        return await _channel.invokeMethod('getCurrentAudioOutputDevice');
      }
    } catch (e) {
      print('Error getting current audio output device: $e');
      return null;
    }
  }

  /// Request access to microphone
  static Future<Map<String, dynamic>> requestMicrophoneAccess() async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!
            .handleMethodCall(MethodCall('requestMicrophoneAccess'));
        return result;
      } else {
        final result = await _channel.invokeMethod('requestMicrophoneAccess');
        return result is Map<String, dynamic> ? result : {'success': result};
      }
    } catch (e) {
      print('Error requesting microphone access: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Dispose the plugin and release all resources
  static Future<bool> dispose() async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result = await _webImpl!.handleMethodCall(MethodCall('dispose'));
        _webImpl = null;
        _onStateChange = null;
        _onMessage = null;
        _onAudioStatusChange = null;
        _onAudioDevicesChanged = null;
        _onSubtitle = null;
        return result['success'] == true;
      } else {
        final result = await _channel.invokeMethod('dispose');
        _onStateChange = null;
        _onMessage = null;
        _onAudioStatusChange = null;
        _onAudioDevicesChanged = null;
        _onSubtitle = null;
        return result;
      }
    } catch (e) {
      print('Error disposing plugin: $e');
      return false;
    }
  }

  /// Called from native code when state changes
  static void handleStateChange(String state, String? message) {
    if (_onStateChange != null) {
      _onStateChange!(state, message);
    }
  }

  /// Called from native code when a message is received
  static void handleMessage(String text, bool isUser) {
    if (_onMessage != null) {
      _onMessage!(text, isUser);
    }
  }

  /// Called from native code when audio status changes
  static void handleAudioStatusChange(bool isPlaying) {
    if (_onAudioStatusChange != null) {
      _onAudioStatusChange!(isPlaying);
    }
  }

  /// Called from native code when audio devices change
  static void handleAudioDevicesChanged(List<dynamic> devices) {
    if (_onAudioDevicesChanged != null) {
      _onAudioDevicesChanged!(devices);
    }
  }

  /// Called from native code when a subtitle is received
  static void handleSubtitle(Map<String, dynamic> subtitle) {
    if (_onSubtitle != null) {
      _onSubtitle!(subtitle);
    }
  }

  /// 测试AI字幕功能（仅用于开发测试）
  static Future<bool> testAISubtitle({
    required String text,
    bool isFinal = false,
  }) async {
    try {
      if (kIsWeb && _webImpl != null) {
        final result =
            await _webImpl!.handleMethodCall(MethodCall('testAISubtitle', {
          'text': text,
          'isFinal': isFinal,
        }));
        return result['success'] == true;
      } else {
        final result = await _channel.invokeMethod<bool>(
          'testAISubtitle',
          {
            'text': text,
            'isFinal': isFinal,
          },
        );
        return result ?? false;
      }
    } catch (e) {
      print('Error testing AI subtitle: $e');
      return false;
    }
  }

  /// 静音/取消静音
  static Future<bool> muteAudio(bool mute) async {
    try {
      if (kIsWeb && _webImpl != null) {
        // Web实现可能没有直接的muteAudio方法，可以考虑通过停止采集来实现
        if (mute) {
          final result =
              await _webImpl!.handleMethodCall(MethodCall('stopAudioCapture'));
          return result['success'] == true;
        } else {
          final result =
              await _webImpl!.handleMethodCall(MethodCall('startAudioCapture'));
          return result['success'] == true;
        }
      } else {
        final result = await _channel.invokeMethod<bool>(
          'muteAudio',
          {
            'mute': mute,
          },
        );
        return result ?? false;
      }
    } catch (e) {
      print('Error muting audio: $e');
      return false;
    }
  }
}
