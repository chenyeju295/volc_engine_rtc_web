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

  // 新增: 事件控制器
  final StreamController<Map<String, dynamic>> _userJoinedController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userLeaveController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userPublishStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userUnpublishStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStartAudioCaptureController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStopAudioCaptureController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _playerEventController = 
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用于监听字幕变化的流
  Stream<Map<String, dynamic>> get subtitleStream =>
      _serviceManager?.rtcService.subtitleStream ??
      const Stream<Map<String, dynamic>>.empty();

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

  /// 新增: 用户加入事件流
  Stream<Map<String, dynamic>> get userJoinedStream => _userJoinedController.stream;

  /// 新增: 用户离开事件流
  Stream<Map<String, dynamic>> get userLeaveStream => _userLeaveController.stream;

  /// 新增: 用户发布流事件流
  Stream<Map<String, dynamic>> get userPublishStreamStream => _userPublishStreamController.stream;

  /// 新增: 用户取消发布流事件流
  Stream<Map<String, dynamic>> get userUnpublishStreamStream => _userUnpublishStreamController.stream;

  /// 新增: 用户开始音频采集事件流
  Stream<Map<String, dynamic>> get userStartAudioCaptureStream => _userStartAudioCaptureController.stream;

  /// 新增: 用户停止音频采集事件流
  Stream<Map<String, dynamic>> get userStopAudioCaptureStream => _userStopAudioCaptureController.stream;

  /// 新增: 播放器事件流
  Stream<Map<String, dynamic>> get playerEventStream => _playerEventController.stream;

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
    
    // 使用Future.microtask确保在Flutter binding初始化后再设置handler
    Future<void>.microtask(() {
      channel.setMethodCallHandler(pluginInstance.handleMethodCall);
    });

    debugPrint('RTC AIGC Plugin Web实现已注册');
  }

  /// 使用方法通道向Flutter端调用方法
  void _invokeMethodOnChannel(String method, dynamic arguments) {
    // 确保Flutter引擎已初始化后再调用方法
    // 这里使用了一个简单的检查，防止在初始化前调用
    if (_channel != null) {
      try {
        _channel.invokeMethod(method, arguments);
      } catch (e) {
        debugPrint('【Web Plugin】调用方法 $method 失败: $e');
      }
    } else {
      debugPrint('【Web Plugin】无法调用方法 $method: 方法通道尚未初始化');
    }
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
      
      // 注册事件监听器 - 新增
      _setupEventListeners();

      return {'success': true};
    } catch (e, s) {
      debugPrint('RTC AIGC Plugin initialize error: $e $s');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// 设置事件监听器 - 新增
  void _setupEventListeners() {
    if (_serviceManager == null) return;
    
    // 监听用户加入事件
    _serviceManager!.rtcService.userPublishStreamStream.listen((data) {
      debugPrint('【Web Plugin】用户发布流事件: $data');
      _userPublishStreamController.add(data);
      
      // 根据时序图，通知上层应用
      _invokeMethodOnChannel('onUserPublishStream', data);
    });
    
    // 监听用户开始音频采集事件 - 现在可以直接使用eventManager
    _serviceManager!.rtcService.eventManager.userStartAudioCaptureStream.listen((userId) {
      debugPrint('【Web Plugin】用户开始音频采集: $userId');
      final data = {'userId': userId};
      _userStartAudioCaptureController.add(data);
      
      // 根据时序图，通知上层应用
      _invokeMethodOnChannel('onUserStartAudioCapture', data);
    });
    
    // 监听播放器事件 - 现在可以直接使用eventManager
    _serviceManager!.rtcService.eventManager.playerEventStream.listen((data) {
      debugPrint('【Web Plugin】播放器事件: $data');
      _playerEventController.add(data);
      
      // 根据时序图，通知上层应用
      _invokeMethodOnChannel('onPlayerEvent', data);
    });
    
    // 监听用户加入事件 - 现在可以直接使用eventManager
    _serviceManager!.rtcService.eventManager.userJoinStream.listen((userId) {
      debugPrint('【Web Plugin】用户加入: $userId');
      final data = {'userId': userId};
      _userJoinedController.add(data);
      
      // 根据时序图，通知上层应用
      _invokeMethodOnChannel('onUserJoined', data);
    });
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
      
      // 根据时序图，音频采集成功后自动发布流
      if (result) {
        debugPrint('【Web Plugin】音频采集已开始，准备发布流...');
      }
      
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
      
      // 关闭事件流
      _userJoinedController.close();
      _userLeaveController.close();
      _userPublishStreamController.close();
      _userUnpublishStreamController.close();
      _userStartAudioCaptureController.close();
      _userStopAudioCaptureController.close();
      _playerEventController.close();
      
      return {'success': true};
    } catch (e) {
      debugPrint('RTC AIGC Plugin dispose error: $e');
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
