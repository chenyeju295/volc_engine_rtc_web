// RTC AIGC Plugin Web Implementation
// 这是Web平台实现的RTC AIGC插件，负责在Flutter Web环境中
// 实现与火山引擎实时音视频和AIGC接口的交互。

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/services/service_manager.dart';
import 'package:rtc_aigc_plugin/src/services/service_interface.dart';
import 'package:rtc_aigc_plugin/src/utils/rtc_message_utils.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_service.dart';

/// RTC AIGC Plugin for Web - Web平台专用实现
///
/// 负责在Flutter Web环境中处理RTC和AIGC的交互逻辑
/// 包含房间管理、对话控制、设备管理等功能
class RtcAigcPluginWeb {
  // 服务管理器实例
  ServiceManager? _serviceManager;

  // 用于与Flutter通信的方法通道
  late MethodChannel _channel;

  /// 用于监听字幕变化的流
  Stream<String> get subtitleStream =>
      _serviceManager?.rtcService.subtitleStream ??
      const Stream<String>.empty();

  /// 用于监听AI状态变化的流
  Stream<RtcState> get stateStream =>
      _serviceManager?.rtcService.stateStream ?? const Stream<RtcState>.empty();

  /// 用于监听音频状态变化的流
  Stream<bool> get audioStatusStream =>
      _serviceManager?.rtcService.audioStatusStream ??
      const Stream<bool>.empty();

  /// 用于监听连接状态变化的流 (connected, disconnected, autoplay_failed等)
  Stream<RtcConnectionState> get connectionStateStream =>
      _serviceManager?.rtcService.connectionStateStream ??
      const Stream<RtcConnectionState>.empty();

  /// 用于监听设备变化的流
  Stream<bool> get deviceStateStream =>
      _serviceManager?.rtcService.deviceStateStream ??
      const Stream<bool>.empty();

  /// 用于监听消息历史变化的流
  Stream<List<RtcAigcMessage>> get messageHistoryStream {
    if (_serviceManager == null) {
      return const Stream.empty();
    }
    return _serviceManager!.onMessageHistoryChanged;
  }

  /// 用于获取消息历史
  List<RtcAigcMessage> get messageHistory {
    if (_serviceManager == null) {
      return [];
    }
    return _serviceManager!.messageHistory;
  }

  /// 用于监听字幕状态变化的流
  Stream<Map<String, dynamic>> get subtitleStateStream {
    if (_serviceManager == null) {
      return const Stream<Map<String, dynamic>>.empty();
    }
    return _serviceManager!.onSubtitleStateChanged;
  }

  /// 用于监听音频属性变化的流 (音量等)
  Stream<Map<String, dynamic>> get audioPropertiesStream {
    if (_serviceManager == null) {
      return const Stream<Map<String, dynamic>>.empty();
    }
    return _serviceManager!.onAudioPropertiesChanged;
  }

  /// 用于监听网络质量变化的流
  Stream<Map<String, dynamic>> get networkQualityStream {
    if (_serviceManager == null) {
      return const Stream<Map<String, dynamic>>.empty();
    }
    return _serviceManager!.onNetworkQualityChanged;
  }

  /// Web平台实现的注册方法
  ///
  /// 注册插件并设置方法通道处理器
  static void registerWith(Registrar registrar) {
    // 创建一个通道以处理方法调用
    final channel = MethodChannel(
      'rtc_aigc_plugin',
      const StandardMethodCodec(),
      registrar,
    );

    // 创建插件实例并设置方法处理程序
    final pluginInstance = RtcAigcPluginWeb();
    pluginInstance._channel = channel;
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);

    debugPrint('RTC AIGC Plugin Web实现已注册');
  }

  /// 处理来自Flutter的方法调用
  ///
  /// 根据方法名分发到具体的处理函数
  Future<dynamic> handleMethodCall(MethodCall call) async {
    // 尝试解析调用参数
    final Map<dynamic, dynamic>? args = call.arguments;

    // 解析配置参数
    switch (call.method) {
      case 'initialize':
        return await _handleInitialize(args);

      case 'joinRoom':
        return await _handleJoinRoom(args);

      case 'startConversation':
        return await _handleStartConversation(args);

      case 'stopConversation':
        return await _handleStopConversation();

      case 'interruptConversation':
        return await _handleInterruptConversation();

      case 'resumeAudioPlayback':
        return await _handleResumeAudioPlayback();

      case 'sendMessage':
        return await _handleSendMessage(args);

      case 'sendTextMessage': // 添加兼容老版本的方法名
        return await _handleSendMessage(
            args is String ? {'message': args} : args);

      case 'getAudioInputDevices':
        return await _handleGetAudioInputDevices();

      case 'getAudioOutputDevices':
        return await _handleGetAudioOutputDevices();

      case 'setAudioCaptureDevice':
      case 'setAudioInputDevice': // 兼容老版本
        return await _handleSetAudioCaptureDevice(
            args is String ? {'deviceId': args} : args);

      case 'setAudioPlaybackDevice':
      case 'setAudioOutputDevice': // 兼容老版本
        return await _handleSetAudioPlaybackDevice(
            args is String ? {'deviceId': args} : args);

      case 'requestMicrophoneAccess':
        return await _handleRequestMicrophoneAccess();

      case 'startAudioCapture':
        return await _handleStartAudioCapture(args);

      case 'stopAudioCapture':
        return await _handleStopAudioCapture();

      case 'dispose':
        return await _handleDispose();

      case 'testAISubtitle':
      case 'simulateSubtitle': // 兼容老版本
        return await _handleTestAISubtitle(args);

      case 'leaveRoom':
        return await _handleLeaveRoom();

      case 'getCurrentAudioInputDevice':
        return _serviceManager?.rtcService.getCurrentAudioInputDeviceId();

      case 'getCurrentAudioOutputDevice':
        return _serviceManager?.rtcService.getCurrentAudioOutputDeviceId();

      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'The rtc_aigc_plugin for web doesn\'t implement the method: ${call.method}',
        );
    }
  }

  /// 初始化RTC服务
  ///
  /// 创建并初始化RTC服务管理器
  Future<Map<String, dynamic>> _handleInitialize(
      Map<dynamic, dynamic>? args) async {
    try {
      if (args == null) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Arguments cannot be null for initialize',
        );
      }

      // 创建配置对象
      final config = RtcConfig(
        appId: args['appId'],
        roomId: args['roomId'],
        userId: args['userId'],
        taskId: args['taskId'],
        token: args['token'],
        serverUrl: args['serverUrl'],
        // 添加默认的配置
        asrConfig: args['asrConfig'] != null
            ? AsrConfig.fromMap(args['asrConfig'])
            : const AsrConfig(),
        ttsConfig: args['ttsConfig'] != null
            ? TtsConfig.fromMap(args['ttsConfig'])
            : const TtsConfig(),
        llmConfig: args['llmConfig'] != null
            ? LlmConfig.fromMap(args['llmConfig'])
            : const LlmConfig(),
      );

      // 创建服务管理器
      _serviceManager = ServiceManager(config: config);

      // 初始化服务
      await _serviceManager!.initialize();

      return {'success': true};
    } catch (e, s) {
      debugPrint('RTC AIGC Plugin initialize error: $e $s');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 加入RTC房间
  Future<Map<String, dynamic>> _handleJoinRoom(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final roomId =
          args?['roomId'] as String? ?? _serviceManager!.config.roomId;
      final userId =
          args?['userId'] as String? ?? _serviceManager!.config.userId;
      final token = args?['token'] as String? ?? _serviceManager!.config.token;

      final result = await _serviceManager!.joinRoom(
        roomId: roomId,
        userId: userId,
        token: token ?? '',
      );

      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin joinRoom error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 开始AI对话
  Future<Map<String, dynamic>> _handleStartConversation(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.startConversation();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin startConversation error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 停止AI对话
  Future<Map<String, dynamic>> _handleStopConversation() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.stopConversation();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin stopConversation error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 中断AI对话
  Future<Map<String, dynamic>> _handleInterruptConversation() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.interruptConversation();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin interruptConversation error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 恢复音频播放（解决浏览器自动播放限制问题）
  Future<Map<String, dynamic>> _handleResumeAudioPlayback() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.resumeAudioPlayback();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin resumeAudioPlayback error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 发送文本消息
  Future<Map<String, dynamic>> _handleSendMessage(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null || args == null) {
        throw PlatformException(
          code: 'INVALID_STATE',
          message: 'RTC service not initialized or missing arguments',
        );
      }

      final message = args['message'] as String?;
      if (message == null || message.isEmpty) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Message cannot be null or empty',
        );
      }

      final result = await _serviceManager!.sendMessage(message);
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin sendMessage error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 获取音频输入设备列表
  Future<Map<String, dynamic>> _handleGetAudioInputDevices() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final devices = await _serviceManager!.getAudioInputDevices();
      return {'success': true, 'devices': devices};
    } catch (e) {
      debugPrint('RTC AIGC Plugin getAudioInputDevices error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'devices': <Map<String, String>>[]
      };
    }
  }

  /// 获取音频输出设备列表
  Future<Map<String, dynamic>> _handleGetAudioOutputDevices() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final devices = await _serviceManager!.getAudioOutputDevices();
      return {'success': true, 'devices': devices};
    } catch (e) {
      debugPrint('RTC AIGC Plugin getAudioOutputDevices error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'devices': <Map<String, String>>[]
      };
    }
  }

  /// 设置音频采集设备
  Future<Map<String, dynamic>> _handleSetAudioCaptureDevice(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null || args == null) {
        throw PlatformException(
          code: 'INVALID_STATE',
          message: 'RTC service not initialized or missing arguments',
        );
      }

      final deviceId = args['deviceId'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Device ID cannot be null or empty',
        );
      }

      final result = await _serviceManager!.setAudioCaptureDevice(deviceId);
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin setAudioCaptureDevice error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 设置音频播放设备
  Future<Map<String, dynamic>> _handleSetAudioPlaybackDevice(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null || args == null) {
        throw PlatformException(
          code: 'INVALID_STATE',
          message: 'RTC service not initialized or missing arguments',
        );
      }

      final deviceId = args['deviceId'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Device ID cannot be null or empty',
        );
      }

      final result = await _serviceManager!.setAudioPlaybackDevice(deviceId);
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin setAudioPlaybackDevice error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 请求麦克风访问权限
  Future<Map<String, dynamic>> _handleRequestMicrophoneAccess() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.requestMicrophoneAccess();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin requestMicrophoneAccess error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 开始音频采集
  Future<Map<String, dynamic>> _handleStartAudioCapture(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final deviceId = args?['deviceId'] as String?;
      final result = await _serviceManager!.startAudioCapture(deviceId);
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin startAudioCapture error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 停止音频采集
  Future<Map<String, dynamic>> _handleStopAudioCapture() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.stopAudioCapture();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin stopAudioCapture error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 释放资源
  Future<Map<String, dynamic>> _handleDispose() async {
    try {
      if (_serviceManager != null) {
        await _serviceManager!.dispose();
        _serviceManager = null;
      }
      return {'success': true};
    } catch (e) {
      debugPrint('RTC AIGC Plugin dispose error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 测试AI字幕 - 开发模式下用于测试
  Future<Map<String, dynamic>> _handleTestAISubtitle(
      Map<dynamic, dynamic>? args) async {
    try {
      if (_serviceManager == null || args == null) {
        throw PlatformException(
          code: 'INVALID_STATE',
          message: 'RTC service not initialized or missing arguments',
        );
      }

      final text = args['text'] as String?;
      if (text == null || text.isEmpty) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Subtitle text cannot be null or empty',
        );
      }

      final isFinal = args['isFinal'] as bool? ?? true;
      final result =
          await _serviceManager!.testAISubtitle(text, isFinal: isFinal);
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin testAISubtitle error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 离开RTC房间
  Future<Map<String, dynamic>> _handleLeaveRoom() async {
    try {
      if (_serviceManager == null) {
        throw PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'RTC service not initialized',
        );
      }

      final result = await _serviceManager!.leaveRoom();
      return {'success': result};
    } catch (e) {
      debugPrint('RTC AIGC Plugin leaveRoom error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
