import 'dart:async';
import 'dart:core';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

import 'package:volc_engine_rtc_web/src/services/rtc_message_handler.dart';

import '../../volc_engine_rtc_web.dart';

/// RTC错误类，用于表示RTC操作中发生的错误
class RtcError {
  final int code;
  final String message;
  final dynamic details;
  final bool isFatal;
  final DateTime timestamp;

  RtcError({
    required this.code,
    required this.message,
    this.details,
    this.isFatal = false,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'RtcError($code): $message';
}

/// 事件回调类型 - 单参数版本
typedef JsEventCallbackSingle = void Function(dynamic);

/// 事件回调类型 - 双参数版本
typedef JsEventCallbackDouble = void Function(dynamic, dynamic);

/// RtcEventManager 负责管理RTC引擎的事件处理和状态跟踪
///
/// 主要功能:
/// - 注册和管理RTC引擎事件回调
/// - 将RTC引擎事件转发给Flutter应用
/// - 维护RTC连接状态和用户状态
/// - 提供事件流供应用订阅
///
/// 设计模式:
/// - 本类采用单例模式，通过instance提供全局访问点
/// - 使用流(Stream)模式实现事件向Flutter的传递
/// - 采用工厂方法处理不同类型的事件
class RtcEventManager {
  // 单例实例
  static final RtcEventManager _instance = RtcEventManager._internal();

  /// 全局访问点
  static RtcEventManager get instance => _instance;

  /// 内部构造函数，确保仅创建一个实例
  RtcEventManager._internal();

  dynamic _rtcClient;
  bool _engineSet = false;

  // Stream controllers for core events
  final StreamController<Map<String, dynamic>> _stateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStateController =
      StreamController<String>.broadcast();
  final StreamController<RtcError> _errorController =
      StreamController<RtcError>.broadcast();

  // Stream controllers for audio events
  final StreamController<List<dynamic>> _audioDevicesController =
      StreamController<List<dynamic>>.broadcast();
  final StreamController<bool> _audioStatusController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _audioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _localAudioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>>
      _remoteAudioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream controllers for user events
  final StreamController<String> _userJoinController =
      StreamController<String>.broadcast();
  final StreamController<String> _userLeaveController =
      StreamController<String>.broadcast();
  final StreamController<String> _userStartAudioCaptureController =
      StreamController<String>.broadcast();
  final StreamController<String> _userStopAudioCaptureController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _userPublishStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userUnpublishStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream controllers for media events
  final StreamController<SubtitleEntity> _subtitleController =
      StreamController<SubtitleEntity>.broadcast();
  final StreamController<Map<String, dynamic>> _networkQualityController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _functionCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _autoPlayFailedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _playerEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _trackEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _interruptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>>
      _connectionStateChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>>
      _binaryMessageReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // State tracking
  bool _isAIThinking = false;
  bool _isAITalking = false;
  String _connectionState = 'disconnected';
  bool _isAudioCapturing = false;
  int _networkQuality = 0; // 0-5, 0 is best
  final List<String> _joinedUsers = [];

  // Streams
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  Stream<String> get connectionStateStream => _connectionStateController.stream;
  Stream<RtcError> get errorStream => _errorController.stream;
  Stream<List<dynamic>> get audioDevicesStream =>
      _audioDevicesController.stream;
  Stream<bool> get audioStatusStream => _audioStatusController.stream;
  Stream<Map<String, dynamic>> get audioPropertiesStream =>
      _audioPropertiesController.stream;
  Stream<Map<String, dynamic>> get localAudioPropertiesStream =>
      _localAudioPropertiesController.stream;
  Stream<Map<String, dynamic>> get remoteAudioPropertiesStream =>
      _remoteAudioPropertiesController.stream;
  Stream<String> get userJoinStream => _userJoinController.stream;
  Stream<String> get userLeaveStream => _userLeaveController.stream;
  Stream<String> get userStartAudioCaptureStream =>
      _userStartAudioCaptureController.stream;
  Stream<String> get userStopAudioCaptureStream =>
      _userStopAudioCaptureController.stream;
  Stream<Map<String, dynamic>> get userPublishStreamStream =>
      _userPublishStreamController.stream;
  Stream<Map<String, dynamic>> get userUnpublishStreamStream =>
      _userUnpublishStreamController.stream;
  Stream<SubtitleEntity> get subtitleStream => _subtitleController.stream;
  Stream<Map<String, dynamic>> get networkQualityStream =>
      _networkQualityController.stream;
  Stream<Map<String, dynamic>> get functionCallStream =>
      _functionCallController.stream;
  Stream<Map<String, dynamic>> get autoPlayFailedStream =>
      _autoPlayFailedController.stream;
  Stream<Map<String, dynamic>> get playerEventStream =>
      _playerEventController.stream;
  Stream<Map<String, dynamic>> get trackEndedStream =>
      _trackEndedController.stream;
  Stream<Map<String, dynamic>> get interruptStream =>
      _interruptController.stream;
  Stream<Map<String, dynamic>> get connectionStateChangedStream =>
      _connectionStateChangedController.stream;
  Stream<Map<String, dynamic>> get binaryMessageReceivedStream =>
      _binaryMessageReceivedController.stream;

  /// 音频捕获状态流 (audioStatusStream 的别名，用于兼容)
  Stream<bool> get audioCaptureStream => _audioStatusController.stream;

  late RtcMessageHandler _messageHandler;

  // 事件处理器映射表
  late final Map<String, Function> _eventMap;

  // 已注册的事件处理器
  final Map<String, Function> _eventHandlers = {};

  // VERTC events reference
  dynamic _events;

  // Getters for current state
  bool get isAIThinking => _isAIThinking;
  bool get isAITalking => _isAITalking;
  String get connectionState => _connectionState;
  bool get isAudioCapturing => _isAudioCapturing;
  int get networkQuality => _networkQuality;

  // 错误处理和错误跟踪
  final List<RtcError> _errorHistory = [];
  bool _hasLoggedFatalError = false;

  /// 最近发生的错误
  RtcError? get lastError =>
      _errorHistory.isNotEmpty ? _errorHistory.last : null;

  /// 错误历史记录
  List<RtcError> get errorHistory => List.unmodifiable(_errorHistory);

  /// 已加入的用户列表
  List<String> get joinedUsers => List.unmodifiable(_joinedUsers);

  /// 用于记录和处理RTC错误
  void _handleError(RtcError error) {
    // 记录错误
    _errorHistory.add(error);
    if (_errorHistory.length > 10) {
      _errorHistory.removeAt(0); // 保持错误历史记录不超过10条
    }

    // 发送错误到流
    _errorController.add(error);

    // 打印错误信息
    debugPrint('RTC错误: ${error.code} - ${error.message}');

    // 处理致命错误
    if (error.isFatal && !_hasLoggedFatalError) {
      _hasLoggedFatalError = true; // 避免重复记录致命错误
      debugPrint('发生RTC致命错误，可能需要重新初始化RTC引擎');
    }
  }

  /// 构造函数 - 支持依赖注入
  RtcEventManager({RtcMessageHandler? messageHandler}) {
    // 初始化消息处理器
    if (messageHandler != null) {
      _messageHandler = messageHandler;

      // 设置消息处理器的回调
      messageHandler.onSubtitle = (subtitle) {
        _subtitleController.add(subtitle);
      };

      messageHandler.onFunctionCall = (functionCall) {
        _functionCallController.add(functionCall);
      };

      messageHandler.onState = (state) {
        _stateController.add(state);
      };
    } else {
      // 如果没有传入消息处理器，创建一个新的
      _messageHandler = RtcMessageHandler();
      debugPrint('RtcEventManager: 创建了新的消息处理器实例');
    }

    // 配置事件映射表
    _setupEventMap();
  }

  /// 设置引擎并初始化事件监听
  void setEngine(dynamic rtcClient) {
    if (_engineSet) {
      return;
    }

    _rtcClient = rtcClient;
    _engineSet = true;

    // 设置消息处理器的引擎
    try {
      _messageHandler.setEngine(rtcClient);
    } catch (e) {
      debugPrint('RtcEventManager: 设置消息处理器的引擎失败: $e');
      // 继续执行，因为可能消息处理器已在其他地方初始化
    }

    // 获取事件常量
    _getEvents();

    // 注册事件处理器
    _registerEventHandlers();

    // 初始获取设备列表
    _getAudioDevices();
  }

  /// 配置事件映射表
  void _setupEventMap() {
    _eventMap = {
      'onError': _handleErrorEvent,
      'onUserJoined': _handleUserJoined,
      'onUserLeave': _handleUserLeave,
      'onTrackEnded': _handleTrackEnded,
      'onUserPublishStream': _handleUserPublishStream,
      'onUserUnpublishStream': _handleUserUnpublishStream,
      'onRemoteStreamStats': _handleRemoteStreamStats,
      'onLocalStreamStats': _handleLocalStreamStats,
      'onLocalAudioPropertiesReport': _handleLocalAudioPropertiesReport,
      'onRemoteAudioPropertiesReport': _handleRemoteAudioPropertiesReport,
      'onAudioDeviceStateChanged': _handleAudioDeviceStateChanged,
      'onAutoplayFailed': _handleAutoPlayFailed,
      'onPlayerEvent': _handlePlayerEvent,
      'onUserStartAudioCapture': _handleUserStartAudioCapture,
      'onUserStopAudioCapture': _handleUserStopAudioCapture,
      'onRoomBinaryMessageReceived': _handleRoomBinaryMessageReceived,
      'onNetworkQuality': _handleNetworkQuality,
      'onConnectionStateChanged': _handleConnectionStateChanged,
      'onMessageStatusChanged': _handleConversationStatus
    };
  }

  /// 获取VERTC事件常量 - 优化版
  void _getEvents() {
    try {
      if (js.context.hasProperty('VERTC') &&
          js.context['VERTC'].hasProperty('events')) {
        _events = js.context['VERTC']['events'];
        if (_events != null) {
          debugPrint('成功获取VERTC.events常量');

          // 预缓存常用事件引用以提高性能
          final commonEvents = [
            'onTrackEnded',
            'onUserJoined',
            'onUserLeave',
            'onError',
            'onConnectionStateChanged',
            'onRoomBinaryMessageReceived'
          ];

          for (var eventName in commonEvents) {
            if (_events.hasProperty(eventName)) {
              // 在此处可以存储事件引用，但当前实现中我们每次动态获取
            }
          }
          return;
        }
      }

      debugPrint('无法获取VERTC.events常量，将使用字符串事件名');
    } catch (e) {
      debugPrint('获取事件常量出错: $e');
    }
  }

  /// 获取事件引用 - 性能优化
  dynamic _getEventRef(String eventName) {
    try {
      if (_events != null && _events.hasProperty(eventName)) {
        return _events[eventName];
      }
    } catch (e) {
      debugPrint('获取事件引用出错: $e');
    }

    return eventName;
  }

  /// 注册RTC事件处理器
  void _registerEvent(String eventName, Function callback) {
    if (_rtcClient == null) {
      debugPrint('无法注册事件 $eventName：RTC引擎未初始化');
      return;
    }

    // 如果已经注册过该事件，先注销
    if (_eventHandlers.containsKey(eventName)) {
      _unregisterEvent(eventName);
    }

    try {
      // 获取事件引用 - 使用优化的方法
      dynamic eventRef = _getEventRef(eventName);

      // 存储回调函数，防止被垃圾回收
      _eventHandlers[eventName] = callback;

      // 检查回调函数类型并相应处理
      var wrappedCallback;

      if (eventName == 'onNetworkQuality') {
        // 特殊处理网络质量回调，接受两个参数
        wrappedCallback = js_util.allowInterop((dynamic arg1, [dynamic arg2]) {
          try {
            if (callback is Function(dynamic, dynamic)) {
              return callback(arg1, arg2);
            } else {
              return callback(arg1);
            }
          } catch (e) {
            debugPrint('执行 $eventName 回调出错: $e');
          }
        });
      } else {
        // 标准回调处理，接受单个参数
        wrappedCallback = js_util.allowInterop((dynamic arg) {
          try {
            return callback(arg);
          } catch (e) {
            debugPrint('执行 $eventName 回调出错: $e');
          }
        });
      }

      // 注册事件
      js_util.callMethod(_rtcClient, 'on', [eventRef, wrappedCallback]);
    } catch (e) {
      debugPrint('注册 $eventName 事件处理器出错: $e');
    }
  }

  /// 注销事件处理器
  void _unregisterEvent(String eventName) {
    if (_rtcClient == null) return;

    try {
      // 使用优化的方法获取事件引用
      dynamic eventRef = _getEventRef(eventName);

      js_util.callMethod(_rtcClient, 'off', [eventRef]);
      _eventHandlers.remove(eventName);
      debugPrint('已注销 $eventName 事件处理器');
    } catch (e) {
      debugPrint('注销 $eventName 事件处理器出错: $e');
    }
  }

  /// 注册所有RTC事件处理器
  void _registerEventHandlers() {
    if (_rtcClient == null) {
      debugPrint('无法注册事件处理器：RTC引擎未初始化');
      return;
    }

    try {
      debugPrint('正在注册RTC事件处理器...');

      // 批量注册事件，使用映射表
      _eventMap.forEach((eventName, handler) {
        _registerEvent(eventName, handler);
      });

      debugPrint('所有RTC事件处理器注册完成');
    } catch (e) {
      debugPrint('注册RTC事件处理器失败: $e');
    }
  }

  // ==================== 事件处理方法 ====================

  void _handleTrackEnded(dynamic event) {
    debugPrint('事件: onTrackEnded');
    try {
      final kind = js_util.getProperty(event, 'kind') ?? '';
      final isScreen = js_util.getProperty(event, 'isScreen') ?? false;

      _stateController.add({
        'type': 'track_ended',
        'kind': kind,
        'isScreen': isScreen,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onTrackEnded事件出错: $e');
    }
  }

  void _handleLocalStreamStats(dynamic event) {
    // 减少日志量，不打印详细信息
    try {
      final audioStats = js_util.getProperty(event, 'audioStats');

      _stateController.add({
        'type': 'local_stream_stats',
        'audioStats': audioStats,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onLocalStreamStats事件出错: $e');
    }
  }

  void _handleRemoteStreamStats(dynamic event) {
    // 减少日志量，不打印详细信息
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      final audioStats = js_util.getProperty(event, 'audioStats');

      _stateController.add({
        'type': 'remote_stream_stats',
        'userId': userId,
        'audioStats': audioStats,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onRemoteStreamStats事件出错: $e');
    }
  }

  void _handlePlayerEvent(dynamic event) {
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      final type = js_util.getProperty(event, 'type') ?? '';
      final rawEvent = js_util.getProperty(event, 'rawEvent');
      final rawEventType =
          rawEvent != null ? js_util.getProperty(rawEvent, 'type') : '';
      debugPrint('事件: onPlayerEvent ${userId} ${type} ${rawEventType}');

      _stateController.add({
        'type': 'player_event',
        'userId': userId,
        'mediaType': type,
        'rawEventType': rawEventType,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onPlayerEvent事件出错: $e');
    }
  }

  void _handleUserJoined(dynamic event) {
    try {
      String userId = js_util.getProperty(event, 'userInfo.userId') ?? '';

      // 添加到已加入用户列表
      if (!_joinedUsers.contains(userId)) {
        _joinedUsers.add(userId);
      }

      // 用于状态跟踪
      _userJoinController.add(userId);

      String username = userId;
      dynamic extraInfo;

      debugPrint('事件: onUserJoined ${userId} ${username}');
      try {
        extraInfo = js_util.getProperty(event, 'userInfo.extraInfo');
        if (extraInfo != null && extraInfo.toString() != 'undefined') {
          final jsonData = js_util.dartify(js_util.callMethod(
              js_util.globalThis, 'JSON.parse', [extraInfo.toString()]));

          if (jsonData is Map && jsonData.containsKey('user_name')) {
            username = jsonData['user_name'] ?? username;
          }
        }
      } catch (e) {
        debugPrint('解析extraInfo出错: $e');
      }

      _stateController.add({
        'type': 'user_joined',
        'userId': userId,
        'username': username,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onUserJoined事件出错: $e');
    }
  }

  void _handleUserLeave(dynamic event) {
    debugPrint('事件: onUserLeave');
    try {
      final userId = js_util.getProperty(event, 'userInfo.userId') ?? '';

      // 从已加入用户列表中移除
      _joinedUsers.remove(userId);

      // 用于状态跟踪
      _userLeaveController.add(userId);

      _stateController.add({
        'type': 'user_left',
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onUserLeave事件出错: $e');
    }
  }

  void _handleUserPublishStream(dynamic event) {
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      final mediaType = js_util.getProperty(event, 'mediaType') ?? '';
      debugPrint('事件: onUserPublishStream ${userId} ${mediaType}');

      _stateController.add({
        'type': 'user_publish_stream',
        'userId': userId,
        'mediaType': mediaType,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onUserPublishStream事件出错: $e');
    }
  }

  void _handleUserUnpublishStream(dynamic event) {
    debugPrint('事件: onUserUnpublishStream');
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      final mediaType = js_util.getProperty(event, 'mediaType') ?? '';
      final reason = js_util.getProperty(event, 'reason') ?? '';

      _stateController.add({
        'type': 'user_unpublish_stream',
        'userId': userId,
        'mediaType': mediaType,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onUserUnpublishStream事件出错: $e');
    }
  }

  void _handleUserStartAudioCapture(dynamic event) {
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      debugPrint('事件: onUserStartAudioCapture ${userId}');

      // 发送到专用流
      _userStartAudioCaptureController.add(userId);

      // 为本地用户更新音频状态
      // 注意: 根据时序图，当AI开始说话时会触发此事件
      // 这里我们通过判断用户ID来确认是否是AI在说话
      if (userId != null && userId.isNotEmpty) {
        // AI 用户通常是房间中的其他用户
        if (_joinedUsers.contains(userId) && !userId.contains('local_')) {
          debugPrint('AI用户 $userId 开始说话');
          _isAITalking = true;
          _audioStatusController.add(true); // 通知UI AI开始说话
        } else if (userId.contains('local_') || userId == 'local') {
          // 本地用户
          _isAudioCapturing = true;
          _audioStatusController.add(true);
          debugPrint('本地用户开始采集音频');
        }
      }

      _stateController.add({
        'type': 'user_start_audio_capture',
        'userId': userId,
        'isAITalking': _isAITalking,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onUserStartAudioCapture事件出错: $e');
    }
  }

  void _handleUserStopAudioCapture(dynamic event) {
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      debugPrint('事件: onUserStopAudioCapture $userId');

      // 从专用流向外发送
      _userStopAudioCaptureController.add(userId);

      // 更新音频状态
      // 注意: 根据时序图，当AI说完话时会触发此事件
      if (userId != null && userId.isNotEmpty) {
        // AI 用户通常是房间中的其他用户
        if (_joinedUsers.contains(userId) && !userId.contains('local_')) {
          debugPrint('AI用户 $userId 停止说话');
          _isAITalking = false;
          _audioStatusController.add(false); // 通知UI AI停止说话
        } else if (userId.contains('local_') || userId == 'local') {
          // 本地用户
          _isAudioCapturing = false;
          _audioStatusController.add(false);
          debugPrint('本地用户停止采集音频');
        }
      }

      _stateController.add({
        'type': 'user_stop_audio_capture',
        'userId': userId,
        'isAITalking': _isAITalking,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onUserStopAudioCapture事件出错: $e');
    }
  }

  /// 处理房间二进制消息接收事件
  void _handleRoomBinaryMessageReceived(dynamic event) {
    try {
      final userId = js_util.getProperty(event, 'userId') ?? '';
      final message = js_util.getProperty(event, 'message');

      if (message != null) {
        // 将消息传递给消息处理器
        _messageHandler.handleBinaryMessage(userId, message);
      } else {
        debugPrint('【事件系统】二进制消息为空，无法处理');
      }
    } catch (e, stackTrace) {
      debugPrint('【事件系统】处理二进制消息异常: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  void _handleConnectionStateChanged(dynamic event) {
    debugPrint('事件: onConnectionStateChanged');
    try {
      final state = js_util.getProperty(event, 'state') ?? '';
      _connectionState = state.toString();
      _connectionStateController.add(_connectionState);
    } catch (e) {
      debugPrint('处理onConnectionStateChanged事件出错: $e');
    }
  }

  void _handleAutoPlayFailed(dynamic event) {
    debugPrint('事件: onAutoplayFailed');
    try {
      _stateController.add({
        'type': 'autoplay_failed',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理onAutoplayFailed事件出错: $e');
    }
  }

  void _handleAudioDeviceStateChanged(dynamic event) {
    debugPrint('事件: onAudioDeviceStateChanged');
    try {
      // 获取设备信息
      final deviceId =
          js_util.getProperty(event, 'mediaDeviceInfo.deviceId') ?? '';
      final deviceLabel =
          js_util.getProperty(event, 'mediaDeviceInfo.label') ?? '';
      final deviceKind =
          js_util.getProperty(event, 'mediaDeviceInfo.kind') ?? '';
      final deviceState = js_util.getProperty(event, 'deviceState') ?? '';

      // 发送设备状态
      _stateController.add({
        'type': 'audio_device_changed',
        'deviceId': deviceId,
        'deviceLabel': deviceLabel,
        'deviceKind': deviceKind,
        'deviceState': deviceState,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });

      // 触发设备变化通知
      _getAudioDevices();
    } catch (e) {
      debugPrint('处理onAudioDeviceStateChanged事件出错: $e');
    }
  }

  void _handleLocalAudioPropertiesReport(dynamic event) {
    try {
      if (event == null) return;

      // 处理本地音频属性数据 - 简化处理为音量值
      final dynamic audioInfo = event[0]; // 获取第一个音频信息对象
      if (audioInfo != null) {
        final dynamic properties =
            js_util.getProperty(audioInfo, 'audioPropertiesInfo');
        if (properties != null) {
          final int volume =
              js_util.getProperty(properties, 'linearVolume') ?? 0;

          _audioPropertiesController.add({
            'type': 'local_audio',
            'volume': volume,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        }
      }
    } catch (e) {
      // 不打印日志以减少输出量
    }
  }

  void _handleRemoteAudioPropertiesReport(dynamic event) {
    try {
      if (event == null) return;

      // 处理多个远端音频
      final List<Map<String, dynamic>> users = [];
      final int length = js_util.getProperty(event, 'length') ?? 0;

      for (int i = 0; i < length; i++) {
        final dynamic audioInfo = event[i];
        if (audioInfo != null) {
          final dynamic streamKey = js_util.getProperty(audioInfo, 'streamKey');
          final dynamic properties =
              js_util.getProperty(audioInfo, 'audioPropertiesInfo');

          if (streamKey != null && properties != null) {
            final String userId =
                js_util.getProperty(streamKey, 'userId') ?? '';
            final int volume =
                js_util.getProperty(properties, 'linearVolume') ?? 0;

            users.add({'userId': userId, 'volume': volume});
          }
        }
      }

      if (users.isNotEmpty) {
        _audioPropertiesController.add({
          'type': 'remote_audio',
          'users': users,
          'timestamp': DateTime.now().millisecondsSinceEpoch
        });
      }
    } catch (e) {
      // 不打印日志以减少输出量
    }
  }

  /// 处理网络质量事件
  void _handleNetworkQuality(dynamic uplink, [dynamic downlink]) {
    try {
      // 处理不同的参数格式
      int uplinkQuality = 0;
      int downlinkQuality = 0;

      // 直接使用两个参数的情况
      if (downlink != null) {
        uplinkQuality = _safeParseInt(uplink);
        downlinkQuality = _safeParseInt(downlink);
      }
      // 如果只传入了一个参数，但它是列表或对象
      else if (uplink != null) {
        // 情况1: 参数是一个包含两个值的数组
        if (uplink is List && uplink.length >= 2) {
          uplinkQuality = _safeParseInt(uplink[0]);
          downlinkQuality = _safeParseInt(uplink[1]);
          debugPrint('网络质量（数组）- 上行: $uplinkQuality, 下行: $downlinkQuality');
        }
        // 情况2: 参数是一个对象，包含uplink和downlink属性
        else if (js_util.hasProperty(uplink, 'uplink') &&
            js_util.hasProperty(uplink, 'downlink')) {
          uplinkQuality = _safeParseInt(js_util.getProperty(uplink, 'uplink'));
          downlinkQuality =
              _safeParseInt(js_util.getProperty(uplink, 'downlink'));
          debugPrint('网络质量（对象）- 上行: $uplinkQuality, 下行: $downlinkQuality');
        }
        // 情况3: 只有一个数值参数
        else {
          uplinkQuality = _safeParseInt(uplink);
          debugPrint('网络质量（单值）- 上行: $uplinkQuality');
        }
      }

      // 计算平均网络质量（0-5，0表示最好，5表示最差）
      final int quality = ((uplinkQuality + downlinkQuality) / 2).floor();
      _networkQuality = quality;

      // 发送网络质量更新
      _networkQualityController.add({
        'uplinkQuality': uplinkQuality,
        'downlinkQuality': downlinkQuality,
        'overallQuality': quality,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      debugPrint('处理网络质量事件出错: $e');
    }
  }

  /// 安全解析整数
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.floor();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  /// 获取音频设备列表
  void _getAudioDevices() {
    if (_rtcClient == null) return;

    try {
      WebUtils.callMethodAsync(_rtcClient, 'getAudioDevices', [])
          .then((devices) {
        if (devices != null) {
          _audioDevicesController.add(devices);
        }
      });
    } catch (e) {
      debugPrint('获取音频设备列表出错: $e');
    }
  }

  /// 释放资源
  void dispose() {
    // 注销事件处理器
    _eventHandlers.keys.toList().forEach(_unregisterEvent);
    _eventHandlers.clear();

    // 关闭所有流控制器
    _stateController.close();
    _connectionStateController.close();
    _errorController.close();
    _audioDevicesController.close();
    _audioStatusController.close();
    _audioPropertiesController.close();
    _localAudioPropertiesController.close();
    _remoteAudioPropertiesController.close();
    _userJoinController.close();
    _userLeaveController.close();
    _userStartAudioCaptureController.close();
    _userStopAudioCaptureController.close();
    _userPublishStreamController.close();
    _userUnpublishStreamController.close();
    _subtitleController.close();
    _networkQualityController.close();
    _functionCallController.close();
    _autoPlayFailedController.close();
    _playerEventController.close();
    _trackEndedController.close();
    _interruptController.close();
    _connectionStateChangedController.close();
    _binaryMessageReceivedController.close();

    _engineSet = false;
    debugPrint('RtcEventManager: 资源已释放');
  }

  void _handleErrorEvent(dynamic event) {
    try {
      final errorCode = js_util.getProperty(event, 'errorCode') ?? 0;
      final errorMessage =
          js_util.getProperty(event, 'errorMessage') ?? 'Unknown error';
      debugPrint('事件: onError ${errorCode} ${errorMessage}');

      // 创建RtcError对象
      final error = RtcError(
        code: errorCode is int ? errorCode : 0,
        message: errorMessage is String ? errorMessage : 'Unknown error',
        details: event,
        isFatal: errorCode is int && errorCode > 1000, // 假设大于1000的错误码是致命错误
      );

      // 使用新的错误处理方法
      _handleError(error);

      // 更新连接状态
      _connectionStateController.add('error');
    } catch (e) {
      debugPrint('处理onError事件出错: $e');
      _handleError(RtcError(
        code: -1,
        message: 'Error handling error event: $e',
      ));
    }
  }

  void _handleConversationStatus(dynamic event) {
    try {
      if (event == null) {
        debugPrint('会话状态变化事件无数据');
        return;
      }

      debugPrint('会话状态变化: ${event.toString()}');

      // 解析状态变化数据
      final dynamic stageValue = js_util.getProperty(event, 'Stage');
      if (stageValue == null) {
        debugPrint('状态变化数据不完整，无法获取Stage字段');
        return;
      }

      final dynamic codeValue = js_util.getProperty(stageValue, 'Code');
      if (codeValue == null) {
        debugPrint('状态变化数据不完整，无法获取Code字段');
        return;
      }

      final int stageCode = _safeCastToInt(codeValue) ?? -1;
      final String stageDesc =
          js_util.getProperty(stageValue, 'Description')?.toString() ??
              'Unknown';

      debugPrint('会话阶段: $stageCode - $stageDesc');

      // 处理中断状态 (INTERRUPTED = 4)
      if (stageCode == 4) {
        // AGENT_BRIEF.INTERRUPTED
        debugPrint('检测到会话被中断');
        _interruptController.add({}); // 触发中断事件
      }

      // ... 处理其他状态 ...
    } catch (e) {
      debugPrint('处理会话状态变化出错: $e');
    }
  }

  /// 安全地将JavaScript值转换为int
  int? _safeCastToInt(dynamic value) {
    if (value == null) return null;

    try {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);

      // 尝试通过JavaScript转换
      return js_util.callMethod(js.context, 'Number', [value]);
    } catch (e) {
      debugPrint('无法转换为int: $value');
      return null;
    }
  }
}
