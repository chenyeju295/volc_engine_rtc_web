import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
import 'package:rtc_aigc_plugin/src/config/aigc_config.dart';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:js_interop';

import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_engine_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_device_manager.dart';
import 'package:rtc_aigc_plugin/src/client/aigc_client.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_event_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_message_handler.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';

import '../utils/token_generator.dart';

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
  final StreamController<SubtitleEntity> _subtitleController =
      StreamController<SubtitleEntity>.broadcast();

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
  final StreamController<Map<String, dynamic>>
      _userStartAudioCaptureController =
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

  ///
  final String _baseUrl;
  final String _appKey;
  final String _userId;

  /// 构造函数 - 使用依赖注入
  RtcService({
    required AigcConfig config,
    required String baseUrl,
    required String appKey,
    required String userId,
    required RtcEngineManager engineManager,
    required RtcDeviceManager deviceManager,
    required RtcEventManager eventManager,
    required RtcMessageHandler messageHandler,
  })  : _config = config,
        _baseUrl = baseUrl,
        _appKey = appKey,
        _userId = userId,
        _engineManager = engineManager,
        _deviceManager = deviceManager,
        _messageHandler = messageHandler,
        _eventManager = eventManager {
    // 构造函数内不执行初始化操作，所有初始化统一在initialize()方法中完成
  }

  /// 获取状态流
  Stream<RtcState> get stateStream => _stateController.stream;

  /// 获取音频状态流
  Stream<bool> get audioStatusStream => _audioStatusController.stream;

  /// 获取字幕流
  Stream<SubtitleEntity> get subtitleStream => _subtitleController.stream;

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
  Stream<Map<String, dynamic>> get userJoinedStream =>
      _userJoinedController.stream;

  /// 用户离开流
  Stream<Map<String, dynamic>> get userLeaveStream =>
      _userLeaveController.stream;

  /// 用户开始音频采集流
  Stream<Map<String, dynamic>> get userStartAudioCaptureStream =>
      _userStartAudioCaptureController.stream;

  /// 用户停止音频采集流
  Stream<Map<String, dynamic>> get userStopAudioCaptureStream =>
      _userStopAudioCaptureController.stream;

  /// 设置消息处理器回调
  void _setupMessageHandlerCallbacks() {
    // 设置字幕回调
    _messageHandler.onSubtitle = (subtitle) {
      _subtitleController.add(subtitle);
    };

    // 设置函数调用回调
    _messageHandler.onFunctionCall = (functionCall) {
      _functionCallController.add(functionCall);

      // 创建函数调用消息对象并添加到历史
      final functionCallMessage = RtcAigcMessage.functionCall(
        id: functionCall['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: functionCall['name'] ?? '',
        arguments: functionCall['arguments'] ?? {},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addMessage(functionCallMessage);

      if (_functionCallCallback != null) {
        _functionCallCallback!(functionCall);
      }
    };

    // 设置状态回调
    _messageHandler.onState = (state) {
      _stateMessageController.add(state);

      final stateType = state['state'] as String? ?? '';

      // 更新状态
      switch (stateType) {
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
    };
  }

  /// 设置事件流转发
  void _setupEventStreams() {
    try {
      // 转发用户加入/离开事件
      _eventManager.userJoinStream.listen((userId) {
        final data = {'userId': userId};

        _userJoinedController.add(data);

        if (onUserJoined != null) {
          onUserJoined!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户加入流错误: $e'));

      _eventManager.userLeaveStream.listen((userId) {
        final data = {'userId': userId};

        _userLeaveController.add(data);

        if (onUserLeave != null) {
          onUserLeave!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户离开流错误: $e'));

      // 转发连接状态事件
      _eventManager.connectionStateStream.listen((state) {
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
      }, onError: (e) => debugPrint('【RTC服务】连接状态流错误: $e'));

      // 转发网络质量事件
      _eventManager.networkQualityStream.listen((quality) {
        _networkQualityController.add(quality);

        if (_networkQualityCallback != null) {
          _networkQualityCallback!(quality);
        }
      }, onError: (e) => debugPrint('【RTC服务】网络质量流错误: $e'));

      // 转发自动播放失败事件
      _eventManager.autoPlayFailedStream.listen((data) {
        _autoPlayFailedController.add(data);

        if (_autoPlayFailedCallback != null) {
          _autoPlayFailedCallback!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】自动播放失败流错误: $e'));

      // 转发音频属性事件
      _eventManager.localAudioPropertiesStream.listen((data) {
        _localAudioPropertiesController.add(data);

        if (_audioPropertiesCallback != null) {
          _audioPropertiesCallback!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】本地音频属性流错误: $e'));

      _eventManager.remoteAudioPropertiesStream.listen((data) {
        _remoteAudioPropertiesController.add(data);
      }, onError: (e) => debugPrint('【RTC服务】远程音频属性流错误: $e'));

      // 转发用户流事件
      _eventManager.userPublishStreamStream.listen((data) {
        _userPublishStreamController.add(data);

        if (_userPublishStreamCallback != null) {
          _userPublishStreamCallback!(data);
        }

        if (onUserPublishStream != null) {
          onUserPublishStream!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户发布流事件错误: $e'));

      _eventManager.userUnpublishStreamStream.listen((data) {
        _userUnpublishStreamController.add(data);

        if (onUserUnpublishStream != null) {
          onUserUnpublishStream!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户取消发布流事件错误: $e'));

      // 转发音频捕获事件
      _eventManager.audioCaptureStream.listen((isCapturing) {
        _audioStatusController.add(isCapturing);

        if (_audioStatusCallback != null) {
          _audioStatusCallback!(isCapturing);
        }
      }, onError: (e) => debugPrint('【RTC服务】音频捕获流错误: $e'));

      // 转发音频设备事件
      _eventManager.audioDevicesStream.listen((devices) {
        _audioDevicesController.add(devices);

        _deviceStateController.add(true);

        if (_deviceStateCallback != null) {
          _deviceStateCallback!(true);
        }
      }, onError: (e) => debugPrint('【RTC服务】音频设备流错误: $e'));

      // 转发错误事件
      _eventManager.errorStream.listen((error) {
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
      }, onError: (e) => debugPrint('【RTC服务】错误流监听错误: $e'));

      // 转发中断事件
      _eventManager.interruptStream.listen((_) {
        if (_messageCallback != null) {
          final message = RtcAigcMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.system,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            isInterrupted: true,
          );
          _messageCallback!(message);
        }

        if (_state == RtcState.waitingResponse) {
          _setState(RtcState.inConversation);
        }
      }, onError: (e) => debugPrint('【RTC服务】中断流错误: $e'));

      // AIGC客户端消息监听
      if (_aigcClient != null) {
        _aigcClient!.messageStream.listen((message) {
          _addMessage(message);

          if (_messageCallback != null) {
            _messageCallback!(message);
          }
        }, onError: (e) => debugPrint('【RTC服务】AIGC消息流错误: $e'));

        _aigcClient!.stateStream.listen((state) {
          if (state == AigcClientState.responding) {
            _setState(RtcState.waitingResponse);
          } else if (state == AigcClientState.ready &&
              _state == RtcState.waitingResponse) {
            _setState(RtcState.inConversation);
          } else if (state == AigcClientState.error) {
            if (_messageCallback != null) {
              final message = RtcAigcMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: MessageType.error,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
              _messageCallback!(message);
            }
          }
        }, onError: (e) => debugPrint('【RTC服务】AIGC状态流错误: $e'));
      }
    } catch (e, stackTrace) {
      debugPrint('【RTC服务】设置事件流时出错: $e');
      debugPrint('【RTC服务】错误堆栈: $stackTrace');
    }
  }

  /// 更新状态
  void _setState(RtcState newState) {
    try {
      if (_state != newState) {
        _state = newState;

        // 通知状态流监听器
        if (!_stateController.isClosed) {
          _stateController.add(_state);
        }

        // 调用状态回调
        if (_stateCallback != null) {
          _stateCallback!(_state);
        }

        // 调用状态变更回调
        if (onStateChange != null) {
          final stateString = _state.toString().split('.').last;
          onStateChange!(stateString, null);
        }
      }
    } catch (e) {
      debugPrint('【RTC服务】设置状态时出错: $e');
    }
  }

  /// 添加消息到历史记录
  void _addMessage(RtcAigcMessage message) {
    try {
      String messageId = message.id;
      if (messageId.isEmpty) {
        messageId = DateTime.now().millisecondsSinceEpoch.toString();
        // 创建一个新的消息对象，确保ID不为空
        message = RtcAigcMessage(
          id: messageId,
          type: message.type,
          text: message.text,
          timestamp: message.timestamp,
          senderId: message.senderId,
          isUser: message.isUser,
          isInterrupted: message.isInterrupted,
        );
      }

      // 添加到历史记录
      _messageHistory.add(message);

      // 通知监听器
      if (!_messageHistoryController.isClosed) {
        _messageHistoryController.add(List.unmodifiable(_messageHistory));
      }

      debugPrint(
          '【RTC服务】添加消息到历史记录: ${message.type}, ID: ${message.id}, 用户: ${message.isUser}');
    } catch (e) {
      debugPrint('【RTC服务】添加消息到历史记录失败: $e');
    }
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

  String _currentToken = '';

  /// 初始化服务
  ///
  /// 此方法负责初始化RTC服务的所有组件：
  /// - 确保SDK已完全加载
  /// - 初始化引擎管理器和获取RTC客户端实例
  /// - 设置事件处理器和回调
  /// - 初始化AIGC客户端
  /// - 设置消息处理器回调和事件监听
  ///
  /// 必须在使用其他服务方法前调用此方法。
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        return true;
      }

      if (!WebUtils.isSdkLoaded()) {
        try {
          await WebUtils.waitForSdkLoaded();
        } catch (e) {
          debugPrint('【RTC服务】SDK加载失败: $e');
          return false;
        }
      }

      final engineSuccess = await _engineManager.initialize();
      if (!engineSuccess) {
        debugPrint('【RTC服务】引擎初始化失败');
        return false;
      }

      // 2. 获取RTC客户端实例
      final rtcClient = _engineManager.getRtcClient();
      if (rtcClient == null) {
        debugPrint('【RTC服务】无法获取RTC客户端实例');
        return false;
      }

      // 3. 安全设置内部组件的引擎引用
      try {
        // 确保组件初始化的正确顺序：先消息处理器，再事件管理器
        _messageHandler.setEngine(rtcClient);
        _eventManager.setEngine(rtcClient);
      } catch (e, stackTrace) {
        debugPrint('【RTC服务】设置内部组件引擎失败: $e');
        debugPrint('【RTC服务】错误堆栈: $stackTrace');
        return false;
      }

      // 4. 初始化AIGC客户端
      try {
        _aigcClient = AigcClient(baseUrl: _baseUrl, config: _config);
      } catch (e) {
        debugPrint('【RTC服务】AIGC客户端初始化失败: $e，但继续初始化其他组件');
        // 不返回失败，因为AIGC客户端不是必要组件
      }

      // 5. 设置各组件回调和事件监听
      try {
        _setupMessageHandlerCallbacks();
        _setupEventStreams();
      } catch (e) {
        debugPrint('【RTC服务】设置回调和事件监听失败: $e');
        return false;
      }
      // 6. 标记为已初始化
      _isInitialized = true;
      _setState(RtcState.initialized);
      return true;
    } catch (e) {
      debugPrint('【RTC服务】初始化失败: $e');
      return false;
    }
  }

  /// 加入RTC房间
  Future<bool> joinRoom() async {
    try {
      if (!_checkInitialized()) return false;

      if (_isInRoom) {
        debugPrint('【RTC服务】已在房间中');
        return true;
      }

      // 生成令牌
      _currentToken = await generateToken();

      // 加入RTC房间
      final joinSuccess = await _engineManager.joinRoom(
        roomId: config.roomId.toString(),
        userId: _userId,
        token: _currentToken,
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

  /// 生成令牌
  Future<String> generateToken() async {
    try {
      _currentToken = await TokenGenerator.generateToken(
        appId: config.appId.toString(),
        appKey: _appKey,
        roomId: config.roomId.toString(),
        userId: _userId,
      );
      return _currentToken;
    } catch (e) {
      debugPrint('生成令牌失败: $e');
      throw Exception('Failed to generate token: $e');
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

      if (!_isInRoom) {
        await joinRoom();
        return false;
      }

      if (_isInConversation) {
        debugPrint('【RTC服务】已经在对话中');
        return true;
      }

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

  /// 开始音频采集
  /// @param deviceId 可选的音频设备ID
  /// @return 如果成功，返回true；如果失败，返回包含错误信息的Map
  Future<dynamic> startAudioCapture(String? deviceId) async {
    try {
      if (!_checkInitialized()) {
        return {'success': false, 'error': 'RTC服务未初始化'};
      }

      debugPrint('【RTC服务】开始音频采集，设备ID: ${deviceId ?? "默认设备"}');

      // 委托给设备管理器处理
      final result = await _deviceManager.startAudioCapture(deviceId: deviceId);

      // 如果成功启动采集，并且在房间中，尝试发布流
      if (result.success && _isInRoom) {
        debugPrint('【RTC服务】尝试发布流');

        try {
          // 获取RTC客户端实例
          final rtcClient = _engineManager.getRtcClient();
          if (rtcClient != null) {
            // 获取MediaType.AUDIO常量
            dynamic mediaType = _getMediaTypeAudio();

            // 发布音频流
            final publishPromise =
                js_util.callMethod(rtcClient, 'publishStream', [mediaType]);
            await js_util.promiseToFuture(publishPromise);
            debugPrint('【RTC服务】音频流发布成功');
          }
        } catch (e) {
          debugPrint('【RTC服务】发布音频流失败，但采集已启动: $e');
          // 不影响整体返回结果，因为采集已启动
        }
      }

      return result.toMap();
    } catch (e) {
      debugPrint('【RTC服务】音频采集启动过程发生未知错误: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 停止音频采集
  /// 立即关闭内部音频采集。
  /// 发布流后调用该方法，房间内的其他用户会收到 onUserStopAudioCapture 的回调。
  ///
  /// 注意：
  /// - 调用 startAudioCapture 可以开启内部音频采集。
  /// - 如果不调用本方法停止内部音频采集，则只有当销毁引擎实例时，内部音频采集才会停止。
  ///
  /// @return 如果成功，返回true；如果失败，返回包含错误信息的Map
  Future<dynamic> stopAudioCapture() async {
    try {
      if (!_checkInitialized()) {
        return {'success': false, 'error': 'RTC服务未初始化'};
      }

      debugPrint('【RTC服务】停止音频采集...');

      // 如果在房间中，先尝试取消发布流
      if (_isInRoom) {
        try {
          // 获取RTC客户端实例
          final rtcClient = _engineManager.getRtcClient();
          if (rtcClient != null) {
            // 获取MediaType.AUDIO常量
            dynamic mediaType = _getMediaTypeAudio();

            // 取消发布音频流
            final unpublishPromise =
                js_util.callMethod(rtcClient, 'unpublishStream', [mediaType]);
            await js_util.promiseToFuture(unpublishPromise);
            debugPrint('【RTC服务】取消发布音频流成功');
          }
        } catch (e) {
          debugPrint('【RTC服务】取消发布音频流失败: $e');
          // 继续执行，不影响停止采集
        }
      }

      // 委托给设备管理器处理
      final result = await _deviceManager.stopAudioCapture();
      return result.toMap();
    } catch (e) {
      debugPrint('【RTC服务】停止音频采集过程发生未知错误: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 设置音频采集音量
  Future<dynamic> setAudioCaptureVolume(int volume) async {
    try {
      if (!_checkInitialized()) {
        return {'success': false, 'error': 'RTC服务未初始化'};
      }

      debugPrint('【RTC服务】设置音频采集音量: $volume');

      // 委托给设备管理器处理
      final result = await _deviceManager.setAudioCaptureVolume(volume);
      return result.toMap();
    } catch (e) {
      debugPrint('【RTC服务】设置音频采集音量时发生错误: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 切换音频设备
  Future<dynamic> switchAudioDevice(String deviceId) async {
    try {
      if (!_checkInitialized()) {
        return {'success': false, 'error': 'RTC服务未初始化'};
      }

      debugPrint('【RTC服务】切换音频设备: $deviceId');

      // 委托给设备管理器处理
      final result = await _deviceManager.switchAudioDevice(deviceId);
      return result.toMap();
    } catch (e) {
      debugPrint('【RTC服务】切换音频设备时发生错误: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 恢复音频播放
  Future<bool> resumeAudioPlayback() async {
    try {
      if (!_checkInitialized()) return false;

      debugPrint('【RTC服务】恢复音频播放...');

      // 委托给设备管理器处理
      return await _deviceManager.resumeAudioPlayback();
    } catch (e) {
      debugPrint('【RTC服务】恢复音频播放时发生错误: $e');
      return false;
    }
  }

  /// 获取音频输入设备列表
  Future<List<Map<String, dynamic>>> getAudioInputDevices() async {
    try {
      if (!_checkInitialized()) return [];

      // 委托给设备管理器处理
      return await _deviceManager.getAudioInputDevices();
    } catch (e) {
      debugPrint('【RTC服务】获取音频输入设备列表时发生错误: $e');
      return [];
    }
  }

  /// 刷新设备列表
  ///
  /// 手动刷新当前可用的音频设备列表，解决重复设备问题
  /// 适用于需要主动更新设备列表的场景
  ///
  /// @return 刷新后的音频输入设备列表
  Future<List<Map<String, dynamic>>> refreshDevices() async {
    try {
      if (!_checkInitialized()) return [];

      // 委托给设备管理器处理
      return await _deviceManager.refreshDevices();
    } catch (e) {
      debugPrint('【RTC服务】刷新设备列表失败: $e');
      return [];
    }
  }

  /// 获取音频输出设备列表
  Future<List<Map<String, dynamic>>> getAudioOutputDevices() async {
    try {
      if (!_checkInitialized()) return [];

      // 委托给设备管理器处理
      return await _deviceManager.getAudioOutputDevices();
    } catch (e) {
      debugPrint('【RTC服务】获取音频输出设备列表时发生错误: $e');
      return [];
    }
  }

  /// 获取当前音频输入设备ID
  Future<String?> getCurrentAudioInputDeviceId() async {
    try {
      if (!_checkInitialized()) return null;

      // 委托给设备管理器处理
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

      // 委托给设备管理器处理
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

  /// 请求麦克风访问权限
  Future<bool> requestMicrophoneAccess() async {
    try {
      if (!_checkInitialized()) return false;

      final success = await _deviceManager.requestMicrophoneAccess();
      return success;
    } catch (e) {
      debugPrint('【RTC服务】请求麦克风访问权限时发生错误: $e');
      return false;
    }
  }

  /// 获取设备权限
  ///
  /// 向用户请求音频和/或视频设备的访问权限
  /// @param options 请求选项，包含audio和video布尔值
  /// @return 权限获取结果
  Future<Map<String, dynamic>> enableDevices({
    bool video = false,
    bool audio = true,
  }) async {
    try {
      if (!_checkInitialized()) {
        return {
          'success': false,
          'audio': false,
          'video': false,
          'error': 'RTC服务未初始化'
        };
      }

      debugPrint('【RTC服务】请求设备权限: video=$video, audio=$audio');

      // 委托给设备管理器处理
      final result = await _deviceManager.enableDevices(
        video: video,
        audio: audio,
      );

      return result;
    } catch (e) {
      debugPrint('【RTC服务】请求设备权限时发生错误: $e');
      return {
        'success': false,
        'audio': false,
        'video': false,
        'error': e.toString()
      };
    }
  }

  /// 枚举所有媒体设备
  ///
  /// 获取系统中所有可用的媒体输入和输出设备列表
  /// 注意：浏览器只有在已经获得设备权限时，才能准确获取设备信息
  /// 推荐在调用enableDevices获取权限后使用本方法
  ///
  /// @return 所有媒体设备的列表
  Future<List<Map<String, dynamic>>> enumerateDevices() async {
    try {
      if (!_checkInitialized()) return [];

      // 委托给设备管理器处理
      return await _deviceManager.enumerateDevices();
    } catch (e) {
      debugPrint('【RTC服务】枚举媒体设备时发生错误: $e');
      return [];
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
      // 销毁引擎
      if (_engineManager != null) {
        _engineManager.dispose();
        _aigcClient = null;
      }
      _isDisposed = true;
    } catch (e) {
      debugPrint('【RTC服务】销毁时发生错误: $e');
    }
  }

  /// 获取MediaType.AUDIO常量
  /// 由于在dart中无法直接访问枚举值，这个方法用于从JS获取MediaType.AUDIO常量
  /// @return MediaType.AUDIO常量值
  dynamic _getMediaTypeAudio() {
    try {
      // 从全局VERTC对象获取MediaType
      final vertc = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertc == null) {
        debugPrint('【RTC服务】无法获取VERTC全局对象');
        return 0; // 默认值
      }

      // 获取MediaType枚举
      final mediaType = js_util.getProperty(vertc, 'MediaType');
      if (mediaType == null) {
        debugPrint('【RTC服务】无法获取MediaType枚举');
        return 0; // 默认值
      }

      // 获取AUDIO常量
      final audioType = js_util.getProperty(mediaType, 'AUDIO');
      if (audioType == null) {
        debugPrint('【RTC服务】无法获取MediaType.AUDIO常量');
        return 0; // 默认值
      }

      return audioType;
    } catch (e) {
      debugPrint('【RTC服务】获取MediaType.AUDIO常量失败: $e');
      return 0; // 默认值
    }
  }

  /// 获取消息历史
  List<RtcAigcMessage> getMessageHistory() {
    return List.unmodifiable(_messageHistory);
  }
}
