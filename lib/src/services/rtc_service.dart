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
import 'package:rtc_aigc_plugin/src/utils/rtc_message_utils.dart' as utils;
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';

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
        _messageHandler = messageHandler,
        _eventManager = eventManager {
    // 构造函数内不执行初始化操作，所有初始化统一在initialize()方法中完成
    debugPrint('【RTC服务】构造完成，等待initialize()方法调用');
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
    if (_messageHandler == null) {
      debugPrint('【RTC服务】警告: 消息处理器为null，无法设置回调');
      return;
    }

    debugPrint('【RTC服务】设置消息处理器回调...');

    // 设置字幕回调
    _messageHandler.onSubtitle = (subtitle) {
      if (subtitle != null && _subtitleController != null) {
        _subtitleController.add(subtitle);
      }
    };

    // 设置函数调用回调
    _messageHandler.onFunctionCall = (functionCall) {
      if (functionCall != null) {
        if (_functionCallController != null) {
          _functionCallController.add(functionCall);
        }

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
      }
    };

    // 设置状态回调
    _messageHandler.onState = (state) {
      if (state != null) {
        if (_stateMessageController != null) {
          _stateMessageController.add(state);
        }

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
      }
    };

    debugPrint('【RTC服务】消息处理器回调设置完成');
  }

  /// 设置事件流转发
  void _setupEventStreams() {
    if (_eventManager == null) {
      debugPrint('【RTC服务】警告: 事件管理器为null，无法设置事件流');
      return;
    }

    try {
      // 转发用户加入/离开事件
      _eventManager.userJoinStream.listen((userId) {
        if (userId == null) return;

        final data = {'userId': userId};

        if (_userJoinedController != null) {
          _userJoinedController.add(data);
        }

        if (onUserJoined != null) {
          onUserJoined!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户加入流错误: $e'));

      _eventManager.userLeaveStream.listen((userId) {
        if (userId == null) return;

        final data = {'userId': userId};

        if (_userLeaveController != null) {
          _userLeaveController.add(data);
        }

        if (onUserLeave != null) {
          onUserLeave!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户离开流错误: $e'));

      // 转发连接状态事件
      _eventManager.connectionStateStream.listen((state) {
        if (state == null) return;

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

        if (_connectionStateController != null) {
          _connectionStateController.add(connectionState);
        }
      }, onError: (e) => debugPrint('【RTC服务】连接状态流错误: $e'));

      // 转发网络质量事件
      _eventManager.networkQualityStream.listen((quality) {
        if (quality == null) return;

        if (_networkQualityController != null) {
          _networkQualityController.add(quality);
        }

        if (_networkQualityCallback != null) {
          _networkQualityCallback!(quality);
        }
      }, onError: (e) => debugPrint('【RTC服务】网络质量流错误: $e'));

      // 转发自动播放失败事件
      _eventManager.autoPlayFailedStream.listen((data) {
        if (data == null) return;

        if (_autoPlayFailedController != null) {
          _autoPlayFailedController.add(data);
        }

        if (_autoPlayFailedCallback != null) {
          _autoPlayFailedCallback!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】自动播放失败流错误: $e'));

      // 转发音频属性事件
      _eventManager.localAudioPropertiesStream.listen((data) {
        if (data == null) return;

        if (_localAudioPropertiesController != null) {
          _localAudioPropertiesController.add(data);
        }

        if (_audioPropertiesCallback != null) {
          _audioPropertiesCallback!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】本地音频属性流错误: $e'));

      _eventManager.remoteAudioPropertiesStream.listen((data) {
        if (data == null) return;

        if (_remoteAudioPropertiesController != null) {
          _remoteAudioPropertiesController.add(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】远程音频属性流错误: $e'));

      // 转发用户流事件
      _eventManager.userPublishStreamStream.listen((data) {
        if (data == null) return;

        if (_userPublishStreamController != null) {
          _userPublishStreamController.add(data);
        }

        if (_userPublishStreamCallback != null) {
          _userPublishStreamCallback!(data);
        }

        if (onUserPublishStream != null) {
          onUserPublishStream!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户发布流事件错误: $e'));

      _eventManager.userUnpublishStreamStream.listen((data) {
        if (data == null) return;

        if (_userUnpublishStreamController != null) {
          _userUnpublishStreamController.add(data);
        }

        if (onUserUnpublishStream != null) {
          onUserUnpublishStream!(data);
        }
      }, onError: (e) => debugPrint('【RTC服务】用户取消发布流事件错误: $e'));

      // 转发音频捕获事件
      _eventManager.audioCaptureStream.listen((isCapturing) {
        if (_audioStatusController != null) {
          _audioStatusController.add(isCapturing);
        }

        if (_audioStatusCallback != null) {
          _audioStatusCallback!(isCapturing);
        }
      }, onError: (e) => debugPrint('【RTC服务】音频捕获流错误: $e'));

      // 转发音频设备事件
      _eventManager.audioDevicesStream.listen((devices) {
        if (devices == null) return;

        if (_audioDevicesController != null) {
          _audioDevicesController.add(devices);
        }

        if (_deviceStateController != null) {
          _deviceStateController.add(true);
        }

        if (_deviceStateCallback != null) {
          _deviceStateCallback!(true);
        }
      }, onError: (e) => debugPrint('【RTC服务】音频设备流错误: $e'));

      // 转发错误事件
      _eventManager.errorStream.listen((error) {
        if (error == null) return;

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
          if (message == null) return;

          debugPrint('【RTC服务】收到AIGC消息: ${message.text}');
          _addMessage(message);

          if (_messageCallback != null) {
            _messageCallback!(message);
          }
        }, onError: (e) => debugPrint('【RTC服务】AIGC消息流错误: $e'));

        _aigcClient!.stateStream.listen((state) {
          if (state == null) return;

          debugPrint('【RTC服务】AIGC状态变更: $state');

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

      debugPrint('【RTC服务】事件流设置完成');
    } catch (e, stackTrace) {
      debugPrint('【RTC服务】设置事件流时出错: $e');
      debugPrint('【RTC服务】错误堆栈: $stackTrace');
    }
  }

  /// 更新状态
  void _setState(RtcState newState) {
    try {
      if (newState == null) {
        debugPrint('【RTC服务】警告: 尝试设置null状态');
        return;
      }

      if (_state != newState) {
        _state = newState;

        // 通知状态流监听器
        if (_stateController != null && !_stateController.isClosed) {
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

        debugPrint('【RTC服务】状态变更: $_state');
      }
    } catch (e) {
      debugPrint('【RTC服务】设置状态时出错: $e');
    }
  }

  /// 添加消息到历史记录
  void _addMessage(RtcAigcMessage message) {
    try {
      if (message == null) {
        debugPrint('【RTC服务】警告: 尝试添加null消息到历史记录');
        return;
      }

      // 确保消息有ID
      String messageId = message.id;
      if (messageId == null || messageId.isEmpty) {
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
      if (_messageHistoryController != null &&
          !_messageHistoryController.isClosed) {
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
        debugPrint('【RTC服务】已初始化，跳过');
        return true;
      }

      debugPrint('【RTC服务】开始初始化...');

      // 0. 首先确保SDK已完全加载
      debugPrint('【RTC服务】确认SDK加载状态...');
      if (!WebUtils.isSdkLoaded()) {
        debugPrint('【RTC服务】SDK未加载，正在等待加载完成...');
        try {
          await WebUtils.waitForSdkLoaded();
          debugPrint('【RTC服务】SDK加载完成，继续初始化流程');
        } catch (e) {
          debugPrint('【RTC服务】SDK加载失败: $e');
          return false;
        }
      } else {
        debugPrint('【RTC服务】SDK已加载，继续初始化流程');
      }

      // 1. 初始化引擎管理器，这是一切的基础
      debugPrint('【RTC服务】初始化引擎管理器...');
      final engineSuccess = await _engineManager.initialize();
      if (!engineSuccess) {
        debugPrint('【RTC服务】引擎初始化失败');
        return false;
      }
      debugPrint('【RTC服务】引擎管理器初始化成功');

      // 2. 获取RTC客户端实例
      final rtcClient = _engineManager.getRtcClient();
      if (rtcClient == null) {
        debugPrint('【RTC服务】无法获取RTC客户端实例');
        return false;
      }
      debugPrint('【RTC服务】获取RTC客户端实例成功');

      // 3. 安全设置内部组件的引擎引用
      try {
        // 确保组件初始化的正确顺序：先消息处理器，再事件管理器
        debugPrint('【RTC服务】设置消息处理器引擎...');
        _messageHandler.setEngine(rtcClient);

        debugPrint('【RTC服务】设置事件管理器引擎...');
        // 先注册事件处理器，再设置引擎
        _engineManager.registerEventHandler(_eventManager);
        _eventManager.setEngine(rtcClient);
      } catch (e, stackTrace) {
        debugPrint('【RTC服务】设置内部组件引擎失败: $e');
        debugPrint('【RTC服务】错误堆栈: $stackTrace');
        return false;
      }

      // 4. 初始化AIGC客户端
      try {
        debugPrint('【RTC服务】初始化AIGC客户端...');
        _aigcClient = AigcClient(
            baseUrl: _config.serverUrl ?? 'http://localhost:3001',
            config: _config);
        debugPrint('【RTC服务】AIGC客户端初始化成功');
      } catch (e) {
        debugPrint('【RTC服务】AIGC客户端初始化失败: $e，但继续初始化其他组件');
        // 不返回失败，因为AIGC客户端不是必要组件
      }

      // 5. 设置各组件回调和事件监听
      try {
        // 设置消息处理器回调
        debugPrint('【RTC服务】设置消息处理器回调...');
        _setupMessageHandlerCallbacks();

        // 设置事件监听
        debugPrint('【RTC服务】设置事件流监听...');
        _setupEventStreams();
      } catch (e) {
        debugPrint('【RTC服务】设置回调和事件监听失败: $e');
        return false;
      }

      // 6. 标记为已初始化
      _isInitialized = true;
      _setState(RtcState.initialized);

      debugPrint('【RTC服务】初始化完成');
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

  /// 设置并安全获取 MediaType 常量
  dynamic _getMediaTypeAudio() {
    try {
      // 方法1: 尝试通过 js_util.globalThis 获取
      final mediaTypeObj = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (mediaTypeObj != null) {
        dynamic mediaType = js_util.getProperty(mediaTypeObj, 'MediaType');
        if (mediaType != null) {
          var audioType = js_util.getProperty(mediaType, 'AUDIO');
          if (audioType != null) {
            return audioType;
          }
        }
      }
      
      // 方法2: 尝试通过 js.context 获取
      if (js.context.hasProperty('VERTC')) {
        final vertc = js.context['VERTC'];
        if (vertc.hasProperty('MediaType') && vertc['MediaType'].hasProperty('AUDIO')) {
          return vertc['MediaType']['AUDIO'];
        }
      }
      
      // 返回默认值 1 (MediaType.AUDIO = 1)
      return 1;
    } catch (e) {
      debugPrint('【RTC服务】获取MediaType.AUDIO常量失败: $e');
      return 1; // 默认值
    }
  }
  
  // 设置并安全获取 StreamIndex 常量
  dynamic _getStreamIndexMain() {
    try {
      // 方法1: 尝试通过 js_util.globalThis 获取
      final streamIndexObj = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (streamIndexObj != null) {
        dynamic streamIndex = js_util.getProperty(streamIndexObj, 'StreamIndex');
        if (streamIndex != null) {
          var mainType = js_util.getProperty(streamIndex, 'MAIN');
          if (mainType != null) {
            return mainType;
          }
        }
      }
      
      // 方法2: 尝试通过 js.context 获取
      if (js.context.hasProperty('VERTC')) {
        final vertc = js.context['VERTC'];
        if (vertc.hasProperty('StreamIndex') && vertc['StreamIndex'].hasProperty('STREAM_INDEX_MAIN')) {
          return vertc['StreamIndex']['STREAM_INDEX_MAIN'];
        }
      }
      
      // 返回默认值 0 (StreamIndex.STREAM_INDEX_MAIN = 0)
      return 0;
    } catch (e) {
      debugPrint('【RTC服务】获取StreamIndex.MAIN常量失败: $e');
      return 0; // 默认值
    }
  }

  /// 开始音频采集
  /// 开启内部音频采集。默认为关闭状态。
  /// 内部采集是指：使用 RTC SDK 内置采集机制进行音频采集。
  /// 可见用户进房后调用该方法，房间中的其他用户会收到 onUserStartAudioCapture 的回调。
  /// 
  /// 注意：
  /// - 调用 stopAudioCapture 可以停止内部音频采集。否则，只有当销毁引擎实例时，内部音频采集才会停止。
  /// - 创建引擎后，无论是否发布音频数据，你都可以调用该方法开启音频采集，只有当（内部或外部）音频采集开始以后音频流才会发布。
  /// 
  /// @param deviceId 设备 ID，传入采集音频的设备 ID，以免出现无声等异常。可通过 getAudioInputDevices 获取设备列表。
  /// @return 如果成功，返回包含实际生效的音频采集参数；如果失败，返回错误信息。
  Future<Map<String, dynamic>> startAudioCapture([String? deviceId]) async {
    try {
      if (!_checkInitialized()) {
        return {'success': false, 'error': 'RTC服务未初始化'};
      }

      debugPrint('【RTC服务】开始音频采集${deviceId != null ? "，设备ID: $deviceId" : ""}');

      // 获取RTC客户端实例
      final rtcClient = _engineManager.getRtcClient();
      if (rtcClient == null) {
        debugPrint('【RTC服务】无法获取RTC客户端实例');
        return {'success': false, 'error': '无法获取RTC客户端实例'};
      }

      // 调用原生的startAudioCapture方法
      try {
        // 准备参数
        final args = deviceId != null ? [deviceId] : [];
        
        // 直接调用引擎的startAudioCapture方法
        final resultPromise = js_util.callMethod(rtcClient, 'startAudioCapture', args);
        
        // 等待Promise完成
        final result = await js_util.promiseToFuture(resultPromise);
        
        // 更新设备管理器的状态
        _deviceManager.setCapturingAudioStatus(true);
        
        // 发布音频流
        try {
          // 获取MediaType.AUDIO常量
          dynamic mediaType = _getMediaTypeAudio();
          
          // 发布音频流
          final publishPromise = js_util.callMethod(rtcClient, 'publishStream', [mediaType]);
          await js_util.promiseToFuture(publishPromise);
          debugPrint('【RTC服务】音频流发布成功，使用MediaType.AUDIO: $mediaType');
        } catch (e) {
          debugPrint('【RTC服务】发布音频流失败，但采集已启动: $e');
          // 不影响整体返回结果，因为采集已启动
        }
        
        // 转换结果
        final Map<String, dynamic> trackSettings = {};
        if (result != null) {
          try {
            // 尝试将JS对象转换为Dart Map
            final settings = js_util.dartify(result);
            if (settings is Map) {
              trackSettings.addAll(Map<String, dynamic>.from(settings));
            }
          } catch (e) {
            debugPrint('【RTC服务】转换音频采集参数失败: $e');
          }
        }
        
        debugPrint('【RTC服务】音频采集启动成功: $trackSettings');
        return {
          'success': true, 
          'trackSettings': trackSettings,
        };
      } catch (e) {
        // 检查常见错误码
        String errorMsg = e.toString();
        String errorCode = 'UNKNOWN_ERROR';
        
        if (errorMsg.contains('REPEAT_CAPTURE')) {
          errorCode = 'REPEAT_CAPTURE';
          errorMsg = '重复采集';
        } else if (errorMsg.contains('GET_AUDIO_TRACK_FAILED')) {
          errorCode = 'GET_AUDIO_TRACK_FAILED';
          errorMsg = '采集音频失败，请确认是否有可用的采集设备，或是否被其他应用占用';
        } else if (errorMsg.contains('STREAM_TYPE_NOT_MATCH')) {
          errorCode = 'STREAM_TYPE_NOT_MATCH';
          errorMsg = '流类型不匹配。调用setAudioSourceType设置了自定义媒体源后，又调用内部采集相关的接口';
        }
        
        debugPrint('【RTC服务】音频采集启动失败: [$errorCode] $errorMsg');
        return {
          'success': false, 
          'error': errorMsg,
          'errorCode': errorCode
        };
      }
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

      // 获取RTC客户端实例
      final rtcClient = _engineManager.getRtcClient();
      if (rtcClient == null) {
        debugPrint('【RTC服务】无法获取RTC客户端实例');
        return {'success': false, 'error': '无法获取RTC客户端实例'};
      }

      // 先尝试取消发布流
      try {
        // 获取MediaType.AUDIO常量
        dynamic mediaType = _getMediaTypeAudio();
        
        // 取消发布音频流
        final unpublishPromise = js_util.callMethod(rtcClient, 'unpublishStream', [mediaType]);
        await js_util.promiseToFuture(unpublishPromise);
        debugPrint('【RTC服务】取消发布音频流成功，使用MediaType.AUDIO: $mediaType');
      } catch (e) {
        debugPrint('【RTC服务】取消发布音频流失败: $e');
        // 继续执行，不影响停止采集
      }

      // 调用原生的stopAudioCapture方法
      try {
        // 直接调用引擎的stopAudioCapture方法
        final resultPromise = js_util.callMethod(rtcClient, 'stopAudioCapture', []);
        
        // 等待Promise完成
        await js_util.promiseToFuture(resultPromise);
        
        // 更新设备管理器的状态
        _deviceManager.setCapturingAudioStatus(false);
        
        debugPrint('【RTC服务】音频采集停止成功');
        return true;
      } catch (e) {
        // 检查常见错误码
        String errorMsg = e.toString();
        String errorCode = 'UNKNOWN_ERROR';
        
        if (errorMsg.contains('STREAM_TYPE_NOT_MATCH')) {
          errorCode = 'STREAM_TYPE_NOT_MATCH';
          errorMsg = '流类型不匹配。调用setAudioSourceType设置了自定义媒体源后，又调用内部采集相关的接口';
        }
        
        debugPrint('【RTC服务】音频采集停止失败: [$errorCode] $errorMsg');
        return {
          'success': false, 
          'error': errorMsg,
          'errorCode': errorCode
        };
      }
    } catch (e) {
      debugPrint('【RTC服务】停止音频采集过程发生未知错误: $e');
      return {'success': false, 'error': e.toString()};
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
