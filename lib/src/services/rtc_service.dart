import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_engine_manager.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_device_manager.dart';
import 'package:rtc_aigc_plugin/src/client/aigc_client.dart';
import 'package:rtc_aigc_plugin/src/services/rtc_event_manager.dart';

/// RTC消息回调
typedef RtcMessageCallback = void Function(RtcAigcMessage message);

/// RTC状态回调
typedef RtcStateCallback = void Function(RtcState state);

/// RTC音频状态回调
typedef RtcAudioStatusCallback = void Function(bool isPlaying);

/// RTC设备状态回调
typedef RtcDeviceStateCallback = void Function(bool isAvailable);

/// RTC服务 - 提供统一的接口用于RTC相关操作
class RtcService {
  /// 配置信息
  final RtcConfig _config;

  /// 引擎管理器
  final RtcEngineManager _engineManager;

  /// 设备管理器
  final RtcDeviceManager _deviceManager;

  /// 事件管理器
  final RtcEventManager _eventManager;

  /// AIGC客户端
  AigcClient? _aigcClient;

  /// 当前状态
  RtcState _state = RtcState.initial;

  /// 消息回调
  RtcMessageCallback? _messageCallback;

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
  final StreamController<String> _subtitleController =
      StreamController<String>.broadcast();

  /// 连接状态流控制器
  final StreamController<ConnectionState> _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  /// 设备状态流控制器
  final StreamController<bool> _deviceStateController =
      StreamController<bool>.broadcast();

  /// 消息历史流控制器
  final StreamController<List<RtcAigcMessage>> _messageHistoryController =
      StreamController<List<RtcAigcMessage>>.broadcast();

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

  /// 构造函数
  RtcService({
    required RtcConfig config,
    required RtcEngineManager engineManager,
    required RtcDeviceManager deviceManager,
    required RtcEventManager eventManager,
  })  : _config = config,
        _engineManager = engineManager,
        _deviceManager = deviceManager,
        _eventManager = eventManager {
    _init();
  }

  /// 初始化
  Future<void> _init() async {
    try {
      // 初始化AIGC客户端
      _aigcClient = AigcClient(
        baseUrl: _config.serverUrl ?? '',
        appId: _config.appId,
        asrConfig: _config.asrConfig,
        ttsConfig: _config.ttsConfig,
        llmConfig: _config.llmConfig,
        roomId: _config.roomId,
        userId: _config.userId,
        token: _config.token,
        taskId: _config.taskId,
      );

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
    // 监听音频状态
    _eventManager.audioStatusStream.listen((isCapturing) {
      debugPrint('【RTC服务】音频采集状态变更: $isCapturing');
      _audioStatusController.add(isCapturing);
    });

    // 监听用户加入
    _eventManager.userJoinStream.listen((userId) {
      debugPrint('【RTC服务】用户加入: $userId');

      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          content: '用户 $userId 加入房间',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }
    });

    // 监听用户离开
    _eventManager.userLeaveStream.listen((userId) {
      debugPrint('【RTC服务】用户离开: $userId');

      if (_messageCallback != null) {
        final message = RtcAigcMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.system,
          content: '用户 $userId 离开房间',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(message);
      }
    });

    // 监听AIGC客户端消息
    if (_aigcClient != null) {
      _aigcClient!.messageStream.listen((message) {
        debugPrint('【RTC服务】收到AIGC消息: ${message.content}');
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
              content: 'AI服务异常，请稍后再试',
              timestamp: DateTime.now().millisecondsSinceEpoch,
            );
            _messageCallback!(message);
          }
        }
      });
    }

    // 监听字幕
    _eventManager.subtitleStream.listen((subtitle) {
      if (subtitle.isNotEmpty) {
        debugPrint('【RTC服务】收到字幕: $subtitle');
      }
      _subtitleController.add(subtitle);
    });
  }

  /// 获取状态流
  Stream<RtcState> get stateStream => _stateController.stream;

  /// 获取音频状态流
  Stream<bool> get audioStatusStream => _audioStatusController.stream;

  /// 获取字幕流
  Stream<String> get subtitleStream => _subtitleController.stream;

  /// 获取连接状态流
  Stream<ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// 获取设备状态流
  Stream<bool> get deviceStateStream => _deviceStateController.stream;

  /// 获取消息历史流
  Stream<List<RtcAigcMessage>> get messageHistoryStream =>
      _messageHistoryController.stream;

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

  /// 初始化服务
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        debugPrint('【RTC服务】已初始化，跳过');
        return true;
      }

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

      if (!_isInRoom) {
        debugPrint('【RTC服务】未在房间中，无法开始对话');
        return false;
      }

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
          content: '对话已结束',
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

  /// 发送消息到AI
  Future<bool> sendMessage(String text) async {
    try {
      if (!_checkInitialized()) return false;

      if (!_isInRoom || !_isInConversation) {
        debugPrint('【RTC服务】未在对话中，无法发送消息');
        return false;
      }

      debugPrint('【RTC服务】发送消息: $text');

      // 添加用户消息到历史记录
      final userMessage = RtcAigcMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        type: MessageType.user,
        content: text,
        senderId: _config.userId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addMessage(userMessage);

      if (_messageCallback != null) {
        _messageCallback!(userMessage);
      }

      // 发送消息给AI
      final sendSuccess = await _aigcClient!.sendMessage(text);

      if (!sendSuccess) {
        // 发送失败消息
        if (_messageCallback != null) {
          final errorMessage = RtcAigcMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            type: MessageType.error,
            content: '消息发送失败，请稍后再试',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          _messageCallback!(errorMessage);
        }

        return false;
      }

      // 更新状态为等待响应
      _setState(RtcState.waitingResponse);

      return true;
    } catch (e) {
      debugPrint('【RTC服务】发送消息时发生错误: $e');

      // 发送错误消息
      if (_messageCallback != null) {
        final errorMessage = RtcAigcMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          type: MessageType.error,
          content: '发送消息时出错: ${e.toString()}',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _messageCallback!(errorMessage);
      }

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
            content: '已中断AI回复',
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

      final success =
          await _deviceManager.startAudioCapture(deviceId: deviceId);
      return success;
    } catch (e) {
      debugPrint('【RTC服务】开始音频采集时发生错误: $e');
      return false;
    }
  }

  /// 停止音频采集
  Future<bool> stopAudioCapture() async {
    try {
      if (!_checkInitialized()) return false;

      final success = await _deviceManager.stopAudioCapture();
      return success;
    } catch (e) {
      debugPrint('【RTC服务】停止音频采集时发生错误: $e');
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

  /// 获取用于测试的AI字幕
  Future<bool> testAISubtitle(String text, {bool isFinal = false}) async {
    try {
      if (!_checkInitialized()) return false;

      _subtitleController.add(text);

      if (isFinal) {
        // 模拟字幕结束
        Future.delayed(const Duration(milliseconds: 500), () {
          _subtitleController.add('');
        });
      }

      return true;
    } catch (e) {
      debugPrint('【RTC服务】测试AI字幕时发生错误: $e');
      return false;
    }
  }

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

      _isDisposed = true;
      _isInitialized = false;
      debugPrint('【RTC服务】销毁完成');
    } catch (e) {
      debugPrint('【RTC服务】销毁时发生错误: $e');
    }
  }
}
