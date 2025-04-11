import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
import 'package:rtc_aigc_plugin/src/config/aigc_config.dart';

import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_engine_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_device_manager.dart';
import 'package:rtc_aigc_plugin/src/client/aigc_client.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_event_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_message_handler.dart';
import 'package:rtc_aigc_plugin/src/utils/rtc_message_utils.dart' as utils;
import 'dart:js_util' as js_util;

/// RTC消息回调
typedef RtcMessageCallback = void Function(RtcAigcMessage message);

/// RTC状态回调
typedef RtcStateCallback = void Function(RtcState state);

/// RTC音频状态回调
typedef RtcAudioStatusCallback = void Function(bool isPlaying);

/// RTC设备状态回调
typedef RtcDeviceStateCallback = void Function(bool isAvailable);

/// RTC功能调用回调
typedef RtcFunctionCallCallback = void Function(
    Map<String, dynamic> functionCall);

/// RTC网络质量回调
typedef RtcNetworkQualityCallback = void Function(Map<String, dynamic> quality);

/// RTC自动播放失败回调
typedef RtcAutoPlayFailedCallback = void Function(Map<String, dynamic> data);

/// RTC音频属性回调
typedef RtcAudioPropertiesCallback = void Function(
    Map<String, dynamic> properties);

/// RTC用户发布流回调
typedef RtcUserPublishStreamCallback = void Function(Map<String, dynamic> data);

/// RTC用户相关事件回调
typedef RtcUserEventCallback = void Function(Map<String, dynamic> data);

/// 状态变更回调
typedef StateChangeCallback = void Function(String state, String? message);

/// RTC服务 - 提供统一的接口用于RTC相关操作
class RtcService {
  /// 配置信息
  final AigcConfig _config;

  /// Get the current configuration
  AigcConfig get config => _config;

  /// 引擎管理器 - 内部组件
  final RtcEngineManager _engineManager;

  /// 设备管理器 - 内部组件
  final RtcDeviceManager _deviceManager;

  /// 事件管理器 - 内部组件
  final RtcEventManager _eventManager;

  /// 消息处理器 - 内部组件
  final RtcMessageHandler _messageHandler;

  /// AIGC客户端
  AigcClient? _aigcClient;

  /// 当前状态
  RtcState _state = RtcState.initial;

  /// 消息回调
  RtcMessageCallback? _messageCallback;

  /// 状态回调
  RtcStateCallback? _stateCallback;

  /// 音频状态回调
  RtcAudioStatusCallback? _audioStatusCallback;

  /// 设备状态回调
  RtcDeviceStateCallback? _deviceStateCallback;

  /// 功能调用回调
  RtcFunctionCallCallback? _functionCallCallback;

  /// 网络质量回调
  RtcNetworkQualityCallback? _networkQualityCallback;

  /// 自动播放失败回调
  RtcAutoPlayFailedCallback? _autoPlayFailedCallback;

  /// 音频属性回调
  RtcAudioPropertiesCallback? _audioPropertiesCallback;

  /// 用户发布流回调
  RtcUserPublishStreamCallback? _userPublishStreamCallback;

  /// 状态变更回调 
  StateChangeCallback? onStateChange;

  /// 用户相关事件回调
  RtcUserEventCallback? onUserJoined;
  RtcUserEventCallback? onUserLeave;
  RtcUserEventCallback? onUserPublishStream;
  RtcUserEventCallback? onUserUnpublishStream;
  RtcUserEventCallback? onUserStartAudioCapture;
  RtcUserEventCallback? onUserStopAudioCapture;

  /// 状态流控制器
  final StreamController<RtcState> _stateController =
      StreamController<RtcState>.broadcast();

  /// 音频状态流控制器
  final StreamController<bool> _audioStatusController =
      StreamController<bool>.broadcast();

  /// 音频设备流控制器
  final StreamController<List<dynamic>> _audioDevicesController =
      StreamController<List<dynamic>>.broadcast();

  /// 音频设备流
  Stream<List<dynamic>> get audioDevicesStream =>
      _audioDevicesController.stream;

  /// 字幕流控制器
  final StreamController<Map<String, dynamic>> _subtitleController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 连接状态流控制器
  final StreamController<RtcConnectionState> _connectionStateController =
      StreamController<RtcConnectionState>.broadcast();

  /// 设备状态流控制器
  final StreamController<bool> _deviceStateController =
      StreamController<bool>.broadcast();

  /// 消息历史流控制器
  final StreamController<List<RtcAigcMessage>> _messageHistoryController =
      StreamController<List<RtcAigcMessage>>.broadcast();

  /// 函数调用流控制器
  final StreamController<Map<String, dynamic>> _functionCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 状态消息流控制器
  final StreamController<Map<String, dynamic>> _stateMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 网络质量流控制器
  final StreamController<Map<String, dynamic>> _networkQualityController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 自动播放失败流控制器
  final StreamController<Map<String, dynamic>> _autoPlayFailedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 本地音频属性流控制器
  final StreamController<Map<String, dynamic>> _localAudioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 远程音频属性流控制器
  final StreamController<Map<String, dynamic>>
      _remoteAudioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用户发布流控制器
  final StreamController<Map<String, dynamic>> _userPublishStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用户取消发布流控制器
  final StreamController<Map<String, dynamic>> _userUnpublishStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用户加入流控制器
  final StreamController<Map<String, dynamic>> _userJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用户离开流控制器
  final StreamController<Map<String, dynamic>> _userLeaveController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用户开始音频采集流控制器
  final StreamController<Map<String, dynamic>> _userStartAudioCaptureController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 用户停止音频采集流控制器
  final StreamController<Map<String, dynamic>> _userStopAudioCaptureController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 消息历史
  final List<RtcAigcMessage> _messageHistory = [];

  /// 是否已在房间中
  bool _isInRoom = false;

  /// 是否正在对话中
  bool _isInConversation = false;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否已销毁
  bool _isDisposed = false;

  /// 构造函数 - 使用依赖注入
  RtcService({
    required AigcConfig config,
    required RtcEngineManager engineManager,
    required RtcDeviceManager deviceManager,
    required RtcEventManager eventManager,
    required RtcMessageHandler messageHandler,
  })  : _config = config,
        _engineManager = engineManager,
        _deviceManager = deviceManager,
        _eventManager = eventManager,
        _messageHandler = messageHandler {
    _init();
  }

  /// 获取状态流
  Stream<RtcState> get stateStream => _stateController.stream;

  /// 获取音频状态流
  Stream<bool> get audioStatusStream => _audioStatusController.stream;

  /// 获取字幕流
  Stream<Map<String, dynamic>> get subtitleStream => _subtitleController.stream;

  /// 获取连接状态流
  Stream<RtcConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// 获取设备状态流
  Stream<bool> get deviceStateStream => _deviceStateController.stream;

  /// 获取消息历史流
  Stream<List<RtcAigcMessage>> get messageHistoryStream =>
      _messageHistoryController.stream;

  /// 获取函数调用流
  Stream<Map<String, dynamic>> get functionCallStream =>
      _functionCallController.stream;

  /// 获取状态消息流
  Stream<Map<String, dynamic>> get stateMessageStream =>
      _stateMessageController.stream;

  /// 获取网络质量流
  Stream<Map<String, dynamic>> get networkQualityStream =>
      _networkQualityController.stream;

  /// 获取自动播放失败流
  Stream<Map<String, dynamic>> get autoPlayFailedStream =>
      _autoPlayFailedController.stream;

  /// 获取本地音频属性流
  Stream<Map<String, dynamic>> get localAudioPropertiesStream =>
      _localAudioPropertiesController.stream;

  /// 获取远程音频属性流
  Stream<Map<String, dynamic>> get remoteAudioPropertiesStream =>
      _remoteAudioPropertiesController.stream;

  /// 获取用户发布流流
  Stream<Map<String, dynamic>> get userPublishStreamStream =>
      _userPublishStreamController.stream;

  /// 获取用户取消发布流流
  Stream<Map<String, dynamic>> get userUnpublishStreamStream =>
      _userUnpublishStreamController.stream;

  /// 用户加入流
  Stream<Map<String, dynamic>> get userJoinedStream => _userJoinedController.stream;

  /// 用户离开流
  Stream<Map<String, dynamic>> get userLeaveStream => _userLeaveController.stream;

  /// 用户开始音频采集流
  Stream<Map<String, dynamic>> get userStartAudioCaptureStream => _userStartAudioCaptureController.stream;

  /// 用户停止音频采集流
  Stream<Map<String, dynamic>> get userStopAudioCaptureStream => _userStopAudioCaptureController.stream;

  /// 初始化
  Future<void> _init() async {
    try {
      // 初始化AIGC客户端
      _aigcClient = AigcClient(
          baseUrl: _config.serverUrl ?? 'http://localhost:3001',
          config: _config);

      // 注册事件监听
      _registerEventListeners();

      _isInitialized = true;
      _setState(RtcState.initialized);
      debugPrint('【RTC服务】初始化完成');
    } catch (e) {
      debugPrint('【RTC服务】初始化失败: $e');
    }
  }

  /// 注册事件监听器
  void _registerEventListeners() {
    // 监听用户加入
    _eventManager.userJoinStream.listen((userId) {
      debugPrint('【RTC服务】用户加入: $userId');
      
      final data = {'userId': userId};
      _userJoinedController.add(data);
      
      if (onUserJoined != null) {
        onUserJoined!(data);
      }

      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }
    });

    // 监听用户离开
    _eventManager.userLeaveStream.listen((userId) {
      debugPrint('【RTC服务】用户离开: $userId');
      
      final data = {'userId': userId};
      _userLeaveController.add(data);
      
      if (onUserLeave != null) {
        onUserLeave!(data);
      }

      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }
    });

    // 监听字幕
    _eventManager.subtitleStream.listen((subtitle) {
      if (subtitle.isNotEmpty) {
        _subtitleController.add(subtitle);
      }
    });

    // 监听函数调用
    _eventManager.functionCallStream.listen((functionCall) {
      debugPrint('【RTC服务】函数调用: ${functionCall['name']}');

      // 创建函数调用消息对象并添加到历史
      final functionCallMessage = RtcAigcMessage.functionCall(
        id: functionCall['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: functionCall['name'] ?? '',
        arguments: functionCall['arguments'] ?? {},
        isUser: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      _addMessage(functionCallMessage);

      if (_functionCallCallback != null) {
        _functionCallCallback!(functionCall);
      }
    });

    // 监听状态变化
    _eventManager.stateStream.listen((stateData) {
      final state = stateData['state'];

      // 更新状态
      switch (state) {
        case 'THINKING':
          _setState(RtcState.waitingResponse);
          break;
        case 'SPEAKING':
          _setState(RtcState.inConversation);
          break;
        case 'FINISHED':
          _setState(RtcState.initialized);
          break;
        case 'INTERRUPTED':
          _setState(RtcState.inRoom);
          break;
      }

      if (_stateCallback != null) {
        _stateCallback!(_state);
      }
      
      // Translate state for compatibility with previous API
      String stateStr;
      String? message;
      
      switch (_state) {
        case RtcState.initialized:
          stateStr = 'ready';
          message = '服务就绪';
          break;
        case RtcState.inRoom:
          stateStr = 'joined';
          message = '已加入房间';
          break;
        case RtcState.inConversation:
          stateStr = 'inConversation';
          message = '对话进行中';
          break;
        case RtcState.waitingResponse:
          stateStr = 'waiting';
          message = '等待响应';
          break;
        case RtcState.error:
          stateStr = 'error';
          message = '发生错误';
          break;
        default:
          stateStr = 'unknown';
          message = '未知状态';
      }
      
      if (onStateChange != null) {
        onStateChange!(stateStr, message);
      }
    });

    // 监听音频状态变化
    _eventManager.audioCaptureStream.listen((isCapturing) {
      debugPrint('【RTC服务】音频采集状态变更: $isCapturing');
      _audioStatusController.add(isCapturing);

      if (_audioStatusCallback != null) {
        _audioStatusCallback!(isCapturing);
      }
    });

    // 监听连接状态
    _eventManager.connectionStateStream.listen((state) {
      debugPrint('【RTC服务】连接状态变更: $state');

      RtcConnectionState connectionState;
      switch (state.toLowerCase()) {
        case 'connected':
          connectionState = RtcConnectionState.connected;
          break;
        case 'connecting':
          connectionState = RtcConnectionState.connecting;
          break;
        case 'disconnected':
          connectionState = RtcConnectionState.disconnected;
          break;
        case 'failed':
          connectionState = RtcConnectionState.failed;
          break;
        default:
          connectionState = RtcConnectionState.unknown;
      }

      _connectionStateController.add(connectionState);
    });

    // 监听网络质量
    _eventManager.networkQualityStream.listen((quality) {
      // 更新网络质量数据
      _networkQualityController.add(quality);
    });

    // 监听自动播放失败
    _eventManager.autoPlayFailedStream.listen((data) {
      debugPrint('【RTC服务】自动播放失败: ${data['userId']}');

      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }

      _autoPlayFailedController.add(data);
    });

    // 监听设备状态变化
    _eventManager.audioDevicesStream.listen((data) {
      debugPrint('【RTC服务】音频设备状态变化');
      _deviceStateController.add(true);
    });

    // 监听本地音频属性
    _eventManager.localAudioPropertiesStream.listen((data) {
      _localAudioPropertiesController.add(data);
    });

    // 监听远程音频属性
    _eventManager.remoteAudioPropertiesStream.listen((data) {
      _remoteAudioPropertiesController.add(data);
    });

    // 监听用户发布流
    _eventManager.userPublishStreamStream.listen((data) {
      debugPrint('【RTC服务】用户发布流: ${data['userId']}');
      _userPublishStreamController.add(data);
    });

    // 监听用户取消发布流
    _eventManager.userUnpublishStreamStream.listen((data) {
      debugPrint('【RTC服务】用户取消发布流: ${data['userId']}');
      _userUnpublishStreamController.add(data);
    });

    // 监听错误
    _eventManager.errorStream.listen((error) {
      debugPrint('【RTC服务】发生错误: ${error.code} - ${error.message}');

      if (_messageCallback != null) {
        final message = RtcAigcMessage.error(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: 'RTC错误: ${error.code} - ${error.message}',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }

      if (error.isFatal) {
        _setState(RtcState.error);
      }
    });

    // 监听中断事件
    _eventManager.interruptStream.listen((_) {
      debugPrint('【RTC服务】检测到会话中断');

      // 发送中断消息
      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          isInterrupted: true,
        );
        _messageCallback!(message);
      }

      // 如果当前正在等待响应，则更新状态
      if (_state == RtcState.waitingResponse) {
        _setState(RtcState.inConversation);
      }
    });

    // AIGC客户端消息监听
    if (_aigcClient != null) {
      _aigcClient!.messageStream.listen((message) {
        debugPrint('【RTC服务】收到AIGC消息: ${message.text}');
        _addMessage(message);

        if (_messageCallback != null) {
          _messageCallback!(message);
        }
      });

      // 监听AIGC客户端状态
      _aigcClient!.stateStream.listen((state) {
        debugPrint('【RTC服务】AIGC状态变更: $state');

        if (state == AigcClientState.responding) {
          _setState(RtcState.waitingResponse);
        } else if (state == AigcClientState.ready &&
            _state == RtcState.waitingResponse) {
          _setState(RtcState.inConversation);
        } else if (state == AigcClientState.error) {
          // 发送错误消息
          if (_messageCallback != null) {
            final message = RtcAigcMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: MessageType.error,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            );
            _messageCallback!(message);
          }
        }
      });
    }
  }

  /// 更新状态
  void _setState(RtcState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
      debugPrint('【RTC服务】状态变更: $_state');
    }
  }

  /// 添加消息到历史记录
  void _addMessage(RtcAigcMessage message) {
    _messageHistory.add(message);
    _messageHistoryController.add(_messageHistory);
  }

  /// 检查是否已初始化
  bool _checkInitialized() {
    if (!_isInitialized) {
      debugPrint('【RTC服务】尚未初始化');
      return false;
    }

    if (_isDisposed) {
      debugPrint('【RTC服务】已销毁');
      return false;
    }

    return true;
  }

  /// 设置消息回调
  void setMessageCallback(RtcMessageCallback callback) {
    _messageCallback = callback;
  }

  /// 设置状态回调
  void setStateCallback(RtcStateCallback callback) {
    _stateCallback = callback;
  }

  /// 设置音频状态回调
  void setAudioStatusCallback(RtcAudioStatusCallback callback) {
    _audioStatusCallback = callback;
  }

  /// 设置设备状态回调
  void setDeviceStateCallback(RtcDeviceStateCallback callback) {
    _deviceStateCallback = callback;
  }

  /// 设置功能调用回调
  void setFunctionCallCallback(RtcFunctionCallCallback callback) {
    _functionCallCallback = callback;
  }

  /// 设置网络质量回调
  void setNetworkQualityCallback(RtcNetworkQualityCallback callback) {
    _networkQualityCallback = callback;
  }

  /// 设置自动播放失败回调
  void setAutoPlayFailedCallback(RtcAutoPlayFailedCallback callback) {
    _autoPlayFailedCallback = callback;
  }

  /// 设置音频属性回调
  void setAudioPropertiesCallback(RtcAudioPropertiesCallback callback) {
    _audioPropertiesCallback = callback;
  }

  /// 设置用户发布流回调
  void setUserPublishStreamCallback(RtcUserPublishStreamCallback callback) {
    _userPublishStreamCallback = callback;
  }

  /// 初始化服务
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        debugPrint('【RTC服务】已初始化，跳过');
        return true;
      }

      // 初始化引擎
      final engineSuccess = await _engineManager.initialize();
      if (!engineSuccess) {
        debugPrint('【RTC服务】引擎初始化失败');
        return false;
      }

      // 获取RTC客户端实例
      final rtcClient = _engineManager.getRtcClient();
      if (rtcClient == null) {
        debugPrint('【RTC服务】无法获取RTC客户端实例');
        return false;
      }

      // 设置内部组件的引擎实例
      _messageHandler.setEngine(rtcClient);
      _eventManager.setEngine(rtcClient);
      _deviceManager.setEngine(rtcClient);

      // 注册事件处理器
      _engineManager.registerEventHandler(_eventManager);

      // 标记为已初始化
      _isInitialized = true;
      _setState(RtcState.initialized);
      return true;
    } catch (e) {
      debugPrint('【RTC服务】初始化失败: $e');
      return false;
    }
  }

  /// 加入RTC房间
  Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String token,
  }) async {
    try {
      if (!_checkInitialized()) return false;

      if (_isInRoom) {
        debugPrint('【RTC服务】已在房间中');
        return true;
      }

      debugPrint('【RTC服务】开始加入房间: $roomId, $userId');

      // 加入RTC房间
      final joinSuccess = await _engineManager.joinRoom(
        roomId: roomId,
        userId: userId,
        token: token,
      );

      if (!joinSuccess) {
        debugPrint('【RTC服务】加入房间失败');
        return false;
      }

      // 更新状态
      _isInRoom = true;
      _setState(RtcState.inRoom);

      return true;
    } catch (e) {
      debugPrint('【RTC服务】加入房间时发生错误: $e');
      return false;
    }
  }

  /// 离开RTC房间
  Future<bool> leaveRoom() async {
    try {
      if (!_checkInitialized()) return false;

      if (!_isInRoom) {
        debugPrint('【RTC服务】未在房间中');
        return true;
      }

      // 停止对话
      if (_isInConversation) {
        await stopConversation();
      }

      // 断开AIGC连接
      if (_aigcClient != null) {
        await _aigcClient!.disconnect();
      }

      // 离开RTC房间
      final leaveSuccess = await _engineManager.leaveRoom();
      if (!leaveSuccess) {
        debugPrint('【RTC服务】离开房间失败');
        return false;
      }

      // 更新状态
      _isInRoom = false;
      _setState(RtcState.initialized);

      // 清空消息历史
      _messageHistory.clear();
      _messageHistoryController.add(_messageHistory);

      return true;
    } catch (e) {
      debugPrint('【RTC服务】离开房间时发生错误: $e');
      return false;
    }
  }

  /// 开始对话
  Future<bool> startConversation() async {
    try {
      if (!_checkInitialized()) return false;

      // if (!_isInRoom) {
      //   debugPrint('【RTC服务】未在房间中，无法开始对话');
      //   return false;
      // }

      if (_isInConversation) {
        debugPrint('【RTC服务】已经在对话中');
        return true;
      }

      debugPrint('【RTC服务】开始对话...');

      // 确保音频采集已启动
      if (!_deviceManager.isCapturingAudio) {
        await _deviceManager.startAudioCapture();
      }

      // 更新状态为对话中
      _isInConversation = true;
      _setState(RtcState.inConversation);

      _aigcClient?.startVoiceChat();

      return true;
    } catch (e) {
      debugPrint('【RTC服务】开始对话时发生错误: $e');
      return false;
    }
  }

  /// 停止对话
  Future<bool> stopConversation() async {
    try {
      if (!_checkInitialized()) return false;

      if (!_isInRoom) {
        debugPrint('【RTC服务】未在房间中，无法停止对话');
        return false;
      }

      if (!_isInConversation) {
        debugPrint('【RTC服务】未在对话中');
        return true;
      }

      debugPrint('【RTC服务】停止对话...');

      // 中断当前响应（如果有）
      await interruptConversation();

      // 停止音频采集
      await _deviceManager.stopAudioCapture();

      // 更新状态
      _isInConversation = false;
      _setState(RtcState.inRoom);

      // 发送通知消息
      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }

      return true;
    } catch (e) {
      debugPrint('【RTC服务】停止对话时发生错误: $e');
      return false;
    }
  }

  /// 发送文本消息到AI
  Future<bool> sendTextMessage(String message) async {
    if (!_isInitialized || _isDisposed || !_isInRoom || !_isInConversation) {
      debugPrint('Cannot send message: Not in conversation');
      return false;
    }

    try {
      // 添加用户消息到历史记录
      final userMessage = RtcAigcMessage.user(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: message,
        senderId: _config.agentConfig?.userId,
      );

      // 添加到历史记录
      _addMessage(userMessage);

      // 发送到AI服务
      if (_aigcClient != null) {
        _aigcClient!.sendMessage(message);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// 中断对话
  Future<bool> interruptConversation() async {
    try {
      if (!_checkInitialized()) return false;

      if (!_isInRoom || !_isInConversation) {
        debugPrint('【RTC服务】未在对话中，无法中断');
        return false;
      }

      debugPrint('【RTC服务】中断对话...');

      // 取消AI响应
      final cancelSuccess = await _aigcClient!.cancelResponse();

      if (cancelSuccess) {
        // 发送中断消息
        if (_messageCallback != null) {
          final message = RtcAigcMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.system,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          _messageCallback!(message);
        }

        // 更新状态为对话中
        _setState(RtcState.inConversation);
      }

      return cancelSuccess;
    } catch (e) {
      debugPrint('【RTC服务】中断对话时发生错误: $e');
      return false;
    }
  }

  /// 恢复音频播放
  Future<bool> resumeAudioPlayback() async {
    try {
      if (!_checkInitialized()) return false;

      debugPrint('【RTC服务】恢复音频播放...');

      // 通过引擎管理器恢复音频播放
      final resumeSuccess = await _engineManager.resumeAudioPlayback();

      return resumeSuccess;
    } catch (e) {
      debugPrint('【RTC服务】恢复音频播放时发生错误: $e');
      return false;
    }
  }

  /// 获取音频输入设备列表
  Future<List<Map<String, dynamic>>> getAudioInputDevices() async {
    try {
      if (!_checkInitialized()) return [];

      final devices = await _deviceManager.getAudioInputDevices();
      return devices;
    } catch (e) {
      debugPrint('【RTC服务】获取音频输入设备列表时发生错误: $e');
      return [];
    }
  }

  /// 获取音频输出设备列表
  Future<List<Map<String, dynamic>>> getAudioOutputDevices() async {
    try {
      if (!_checkInitialized()) return [];

      final devices = await _deviceManager.getAudioOutputDevices();
      return devices;
    } catch (e) {
      debugPrint('【RTC服务】获取音频输出设备列表时发生错误: $e');
      return [];
    }
  }

  /// 设置音频采集设备
  Future<bool> setAudioCaptureDevice(String deviceId) async {
    try {
      if (!_checkInitialized()) return false;

      final success = await _deviceManager.setAudioCaptureDevice(deviceId);
      return success;
    } catch (e) {
      debugPrint('【RTC服务】设置音频采集设备时发生错误: $e');
      return false;
    }
  }

  /// 设置音频播放设备
  Future<bool> setAudioPlaybackDevice(String deviceId) async {
    try {
      if (!_checkInitialized()) return false;

      final success = await _deviceManager.setAudioPlaybackDevice(deviceId);
      return success;
    } catch (e) {
      debugPrint('【RTC服务】设置音频播放设备时发生错误: $e');
      return false;
    }
  }

  /// 开始音频采集
  Future<bool> startAudioCapture([String? deviceId]) async {
    try {
      if (!_checkInitialized()) return false;

      debugPrint('【RTC服务】开始音频采集...');

      // 1. 开始音频采集
      final success =
          await _deviceManager.startAudioCapture(deviceId: deviceId);
      if (!success) {
        debugPrint('【RTC服务】开始音频采集失败');
        return false;
      }

      // 2. 发布音频流 - 参考web demo的 publishStream 方法
      try {
        final rtcClient = _engineManager.getRtcClient();
        if (rtcClient != null) {
          // 获取 MediaType 常量值
          final mediaTypeObj = js_util.getProperty(js_util.globalThis, 'VERTC');
          dynamic mediaType;
          if (mediaTypeObj != null) {
            mediaType = js_util.getProperty(mediaTypeObj, 'MediaType.AUDIO');
          }

          if (mediaType != null) {
            // 使用音频类型发布流
            js_util.callMethod(rtcClient, 'publishStream', [mediaType]);
            debugPrint('【RTC服务】发布音频流成功');
          } else {
            // 使用数字常量 (MediaType.AUDIO = 1)
            js_util.callMethod(rtcClient, 'publishStream', [1]);
            debugPrint('【RTC服务】使用默认值发布音频流');
          }
        }
      } catch (e) {
        debugPrint('【RTC服务】发布音频流失败: $e');
        // 继续执行，不中断流程
      }

      return true;
    } catch (e) {
      debugPrint('【RTC服务】开始音频采集时发生错误: $e');
      return false;
    }
  }

  /// 停止音频采集
  Future<bool> stopAudioCapture() async {
    try {
      if (!_checkInitialized()) return false;

      debugPrint('【RTC服务】停止音频采集...');

      // 1. 取消发布音频流 - 参考web demo的 unpublishStream 方法
      try {
        final rtcClient = _engineManager.getRtcClient();
        if (rtcClient != null) {
          // 获取 MediaType 常量值
          final mediaTypeObj = js_util.getProperty(js_util.globalThis, 'VERTC');
          dynamic mediaType;
          if (mediaTypeObj != null) {
            mediaType = js_util.getProperty(mediaTypeObj, 'MediaType.AUDIO');
          }

          if (mediaType != null) {
            // 使用音频类型取消发布流
            js_util.callMethod(rtcClient, 'unpublishStream', [mediaType]);
            debugPrint('【RTC服务】取消发布音频流成功');
          } else {
            // 使用数字常量 (MediaType.AUDIO = 1)
            js_util.callMethod(rtcClient, 'unpublishStream', [1]);
            debugPrint('【RTC服务】使用默认值取消发布音频流');
          }
        }
      } catch (e) {
        debugPrint('【RTC服务】取消发布音频流失败: $e');
        // 继续执行，不中断流程
      }

      // 2. 停止音频采集
      final success = await _deviceManager.stopAudioCapture();
      if (!success) {
        debugPrint('【RTC服务】停止音频采集失败');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('【RTC服务】停止音频采集时发生错误: $e');
      return false;
    }
  }

  /// 设置音频采集音量
  Future<bool> setAudioCaptureVolume(int volume) async {
    try {
      if (!_checkInitialized()) return false;

      debugPrint('【RTC服务】设置音频采集音量: $volume');

      // 参考web demo的 setAudioVolume 方法
      try {
        final rtcClient = _engineManager.getRtcClient();
        if (rtcClient != null) {
          // 设置主流和屏幕共享流的音量
          // StreamIndex.STREAM_INDEX_MAIN = 0
          js_util.callMethod(rtcClient, 'setCaptureVolume', [0, volume]);

          // StreamIndex.STREAM_INDEX_SCREEN = 1 (可选)
          js_util.callMethod(rtcClient, 'setCaptureVolume', [1, volume]);

          debugPrint('【RTC服务】音频采集音量设置成功');
          return true;
        }
      } catch (e) {
        debugPrint('【RTC服务】设置音频采集音量失败: $e');
      }

      return false;
    } catch (e) {
      debugPrint('【RTC服务】设置音频采集音量时发生错误: $e');
      return false;
    }
  }

  /// 切换音频设备
  Future<bool> switchAudioDevice(String deviceId) async {
    try {
      if (!_checkInitialized()) return false;

      debugPrint('【RTC服务】切换音频设备: $deviceId');

      // 参考web demo的 switchDevice 方法
      try {
        final rtcClient = _engineManager.getRtcClient();
        if (rtcClient != null) {
          // 设置音频采集设备
          js_util.callMethod(rtcClient, 'setAudioCaptureDevice', [deviceId]);

          debugPrint('【RTC服务】音频设备切换成功');
          return true;
        }
      } catch (e) {
        debugPrint('【RTC服务】切换音频设备失败: $e');
      }

      return false;
    } catch (e) {
      debugPrint('【RTC服务】切换音频设备时发生错误: $e');
      return false;
    }
  }

  /// 获取当前音频输入设备ID
  Future<String?> getCurrentAudioInputDeviceId() async {
    try {
      if (!_checkInitialized()) return null;

      return await _deviceManager.getCurrentAudioInputDeviceId();
    } catch (e) {
      debugPrint('【RTC服务】获取当前音频输入设备ID时发生错误: $e');
      return null;
    }
  }

  /// 获取当前音频输出设备ID
  Future<String?> getCurrentAudioOutputDeviceId() async {
    try {
      if (!_checkInitialized()) return null;

      return await _deviceManager.getCurrentAudioOutputDeviceId();
    } catch (e) {
      debugPrint('【RTC服务】获取当前音频输出设备ID时发生错误: $e');
      return null;
    }
  }

  /// 获取当前状态
  RtcState get state => _state;

  /// 是否已在房间中
  bool get isInRoom => _isInRoom;

  /// 是否正在对话中
  bool get isInConversation => _isInConversation;

  /// 获取消息历史
  List<RtcAigcMessage> getMessageHistory() {
    return List.unmodifiable(_messageHistory);
  }

  /// 请求摄像头访问权限
  Future<bool> requestCameraAccess() async {
    try {
      if (!_checkInitialized()) return false;

      final success = await _deviceManager.requestCameraAccess();
      return success;
    } catch (e) {
      debugPrint('【RTC服务】请求摄像头访问权限时发生错误: $e');
      return false;
    }
  }

  /// 销毁服务
  Future<void> dispose() async {
    if (_isDisposed) return;

    debugPrint('【RTC服务】开始销毁...');

    try {
      // 离开房间
      if (_isInRoom) {
        await leaveRoom();
      }

      // 关闭AIGC客户端
      if (_aigcClient != null) {
        _aigcClient!.dispose();
        _aigcClient = null;
      }

      // 关闭流控制器
      _stateController.close();
      _audioStatusController.close();
      _subtitleController.close();
      _connectionStateController.close();
      _deviceStateController.close();
      _messageHistoryController.close();
      _functionCallController.close();
      _stateMessageController.close();
      _networkQualityController.close();
      _autoPlayFailedController.close();
      _localAudioPropertiesController.close();
      _remoteAudioPropertiesController.close();
      _userPublishStreamController.close();
      _userUnpublishStreamController.close();
      _userJoinedController.close();
      _userLeaveController.close();
      _userStartAudioCaptureController.close();
      _userStopAudioCaptureController.close();

      _isDisposed = true;
      _isInitialized = false;
      debugPrint('【RTC服务】销毁完成');
    } catch (e) {
      debugPrint('【RTC服务】销毁时发生错误: $e');
    }
  }
}
