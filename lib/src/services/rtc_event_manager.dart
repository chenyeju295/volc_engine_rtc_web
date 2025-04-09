import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:js_interop';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';

// 更新函数类型定义
typedef JsEventCallback = void Function(dynamic);

/// Manages RTC events and state changes
class RtcEventManager {
  final RtcConfig config;
  dynamic _rtcClient;
  
  // Stream controllers
  final StreamController<Map<String, dynamic>> _stateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStateController = 
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _errorController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<dynamic>> _audioDevicesController =
      StreamController<List<dynamic>>.broadcast();
  final StreamController<bool> _audioStatusController =
      StreamController<bool>.broadcast();
  final StreamController<String> _subtitleController =
      StreamController<String>.broadcast();
  final StreamController<String> _userJoinController =
      StreamController<String>.broadcast();
  final StreamController<String> _userLeaveController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _subtitleStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _audioPropertiesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _networkQualityController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  // State tracking
  bool _isAIThinking = false;
  bool _isAITalking = false;
  String _connectionState = 'disconnected';
  bool _isAudioCapturing = false;
  int _networkQuality = 0; // 0-5, 0 is best
  
  // Streams
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  Stream<String> get connectionStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;
  Stream<List<dynamic>> get audioDevicesStream => _audioDevicesController.stream;
  Stream<bool> get audioStatusStream => _audioStatusController.stream;
  Stream<String> get subtitleStream => _subtitleController.stream;
  Stream<String> get userJoinStream => _userJoinController.stream;
  Stream<String> get userLeaveStream => _userLeaveController.stream;
  Stream<Map<String, dynamic>> get subtitleStateStream => _subtitleStateController.stream;
  Stream<Map<String, dynamic>> get audioPropertiesStream => _audioPropertiesController.stream;
  Stream<Map<String, dynamic>> get networkQualityStream => _networkQualityController.stream;
  
  // Getters for current state
  bool get isAIThinking => _isAIThinking;
  bool get isAITalking => _isAITalking;
  String get connectionState => _connectionState;
  bool get isAudioCapturing => _isAudioCapturing;
  int get networkQuality => _networkQuality;
  
  // Event handlers
  final Map<String, JsEventCallback> _eventHandlers = {};
  
  // VERTC events reference
  dynamic _events;
  
  RtcEventManager({required this.config});
  
  void setEngine(dynamic rtcClient) {
    _rtcClient = rtcClient;
    _getEvents();
    _registerEventHandlers();
  }
  
  /// 获取VERTC事件常量
  void _getEvents() {
    try {
      // 首先尝试从全局VERTC对象获取events
      final vertcObj = js_util.getProperty(js_util.globalThis, 'VERTC');
      if (vertcObj != null) {
        _events = js_util.getProperty(vertcObj, 'events');
        if (_events != null) {
          debugPrint('成功从VERTC全局对象获取events常量');
          return;
        }
      }
      
      // 如果全局获取失败，尝试从rtcClient引擎实例获取
      if (_rtcClient != null) {
        // 尝试从引擎实例获取events (根据SDK的实际结构可能需要调整)
        final engineEvents = js_util.getProperty(_rtcClient, 'events');
        if (engineEvents != null) {
          _events = engineEvents;
          debugPrint('成功从rtcClient实例获取events常量');
          return;
        }
        
        // 某些SDK可能将events作为静态成员，尝试获取构造函数的events
        final constructor = js_util.getProperty(js_util.globalThis, 
                          js_util.getProperty(_rtcClient, 'constructor.name'));
        if (constructor != null) {
          final constructorEvents = js_util.getProperty(constructor, 'events');
          if (constructorEvents != null) {
            _events = constructorEvents;
            debugPrint('成功从构造函数获取events常量');
            return;
          }
        }
      }
      
      debugPrint('警告: 无法获取事件常量，将使用动态字符串作为事件名');
    } catch (e) {
      debugPrint('获取事件常量出错: $e');
    }
  }
  
  /// 注册事件处理器 - 这是一个Helper方法
  void _registerEvent(String eventName, JsEventCallback callback) {
    try {
      // 获取事件常量或直接使用事件名
      dynamic eventRef;
      
      if (_events != null) {
        // 如果有事件常量对象，从中获取
        eventRef = js_util.getProperty(_events, eventName);
      }
      
      if (eventRef == null) {
        // 如果无法获取事件常量，直接使用事件名字符串
        eventRef = eventName;
        debugPrint('使用事件名字符串: $eventName');
      }
      
      // 存储回调函数，防止被垃圾回收
      _eventHandlers[eventName] = callback;
      
      // 使用allowInterop包装回调函数，这一步对于Flutter Web是必须的
      final wrappedCallback = js_util.allowInterop(callback);
      
      // 注册事件
      js_util.callMethod(_rtcClient, 'on', [eventRef, wrappedCallback]);
      debugPrint('已注册 $eventName 事件处理器');
    } catch (e) {
      debugPrint('注册 $eventName 事件处理器出错: $e');
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

      // 用户加入事件
      _registerEvent('onUserJoined', (event) {
        debugPrint('事件: onUserJoined');
        try {
          String userId = js_util.getProperty(event, 'userInfo.userId') ?? '';
          
          // 用于状态跟踪
          _userJoinController.add(userId);
          
          String username = userId;
          dynamic extraInfo;
          
          try {
            extraInfo = js_util.getProperty(event, 'userInfo.extraInfo');
            if (extraInfo != null && extraInfo.toString() != 'undefined') {
              final jsonData = js_util.dartify(js_util.callMethod(
                js_util.globalThis, 'JSON.parse', [extraInfo.toString()]
              ));
              
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
      });

      // 用户离开事件
      _registerEvent('onUserLeave', (event) {
        debugPrint('事件: onUserLeave');
        try {
          final userId = js_util.getProperty(event, 'userInfo.userId') ?? '';
          
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
      });

      // 用户发布流事件
      _registerEvent('onUserPublishStream', (event) {
        debugPrint('事件: onUserPublishStream');
        try {
          final userId = js_util.getProperty(event, 'userId') ?? '';
          final mediaType = js_util.getProperty(event, 'mediaType') ?? '';
          
          _stateController.add({
            'type': 'user_publish_stream',
            'userId': userId,
            'mediaType': mediaType,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理onUserPublishStream事件出错: $e');
        }
      });

      // 用户取消发布流事件
      _registerEvent('onUserUnpublishStream', (event) {
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
      });

      // 音频采集开始事件
      _registerEvent('onUserStartAudioCapture', (event) {
        debugPrint('事件: onUserStartAudioCapture');
        try {
          final userId = js_util.getProperty(event, 'userId') ?? '';
          
          // 更新音频状态
          if (userId == config.userId) {
            _isAudioCapturing = true;
            _audioStatusController.add(true);
          }
          
          _stateController.add({
            'type': 'user_start_audio_capture',
            'userId': userId,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理onUserStartAudioCapture事件出错: $e');
        }
      });

      // 音频采集停止事件
      _registerEvent('onUserStopAudioCapture', (event) {
        debugPrint('事件: onUserStopAudioCapture');
        try {
          final userId = js_util.getProperty(event, 'userId') ?? '';
          
          // 更新音频状态
          if (userId == config.userId) {
            _isAudioCapturing = false;
            _audioStatusController.add(false);
          }
          
          _stateController.add({
            'type': 'user_stop_audio_capture',
            'userId': userId,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理onUserStopAudioCapture事件出错: $e');
        }
      });

      // 二进制消息接收事件 - 用于处理AIGC消息
      _registerEvent('onRoomBinaryMessageReceived', (event) {
        debugPrint('事件: onRoomBinaryMessageReceived');
        try {
          final userId = js_util.getProperty(event, 'userId') ?? '';
          final message = js_util.getProperty(event, 'message');
          
          // 处理二进制消息 - 尝试解析为字幕或状态消息
          _processBinaryMessage(userId, message);
        } catch (e) {
          debugPrint('处理onRoomBinaryMessageReceived事件出错: $e');
        }
      });

      // 错误事件
      _registerEvent('onError', (event) {
        debugPrint('事件: onError');
        try {
          final errorCode = js_util.getProperty(event, 'errorCode') ?? '';
          final errorMessage = js_util.getProperty(event, 'errorMessage') ?? '';
          
          _connectionStateController.add('error');
          _errorController.add({
            'errorCode': errorCode,
            'errorMessage': errorMessage,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理onError事件出错: $e');
        }
      });

      // 连接状态变化事件
      _registerEvent('onConnectionStateChanged', (event) {
        debugPrint('事件: onConnectionStateChanged');
        try {
          final state = js_util.getProperty(event, 'state') ?? '';
          _connectionState = state.toString();
          _connectionStateController.add(_connectionState);
        } catch (e) {
          debugPrint('处理onConnectionStateChanged事件出错: $e');
        }
      });

      // 自动播放失败事件
      _registerEvent('onAutoplayFailed', (event) {
        debugPrint('事件: onAutoplayFailed');
        try {
          _stateController.add({
            'type': 'autoplay_failed',
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理onAutoplayFailed事件出错: $e');
        }
      });

      // 音频设备状态变化事件
      _registerEvent('onAudioDeviceStateChanged', (event) {
        debugPrint('事件: onAudioDeviceStateChanged');
        try {
          // 获取设备信息
          final deviceId = js_util.getProperty(event, 'mediaDeviceInfo.deviceId') ?? '';
          final deviceLabel = js_util.getProperty(event, 'mediaDeviceInfo.label') ?? '';
          final deviceKind = js_util.getProperty(event, 'mediaDeviceInfo.kind') ?? '';
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
      });

      // 字幕状态变化事件
      _registerEvent('onSubtitleStateChanged', (event) {
        debugPrint('事件: onSubtitleStateChanged');
        try {
          final state = js_util.getProperty(event, 'state') ?? '';
          final errorCode = js_util.getProperty(event, 'errorCode') ?? 0;
          final errorMessage = js_util.getProperty(event, 'errorMessage') ?? '';
          
          final stateData = {
            'type': 'subtitle_state_changed',
            'state': state,
            'errorCode': errorCode,
            'errorMessage': errorMessage,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          };
          
          _subtitleStateController.add(stateData);
          _stateController.add(stateData);
        } catch (e) {
          debugPrint('处理onSubtitleStateChanged事件出错: $e');
        }
      });

      // 字幕消息接收事件
      _registerEvent('onSubtitleMessageReceived', (event) {
        debugPrint('事件: onSubtitleMessageReceived');
        try {
          final userId = js_util.getProperty(event, 'userId') ?? '';
          final text = js_util.getProperty(event, 'text') ?? '';
          final isFinal = js_util.getProperty(event, 'isFinal') ?? false;
          
          // 发送字幕文本
          _subtitleController.add(text);
          
          // 发送详细信息
          _stateController.add({
            'type': 'subtitle_message',
            'userId': userId,
            'text': text,
            'isFinal': isFinal,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理onSubtitleMessageReceived事件出错: $e');
        }
      });

      // 本地音频属性报告
      _registerEvent('onLocalAudioPropertiesReport', (event) {
        try {
          if (event == null) return;
          
          // 处理本地音频属性数据 - 简化处理为音量值
          final dynamic audioInfo = event[0]; // 获取第一个音频信息对象
          if (audioInfo != null) {
            final dynamic properties = js_util.getProperty(audioInfo, 'audioPropertiesInfo');
            if (properties != null) {
              final int volume = js_util.getProperty(properties, 'linearVolume') ?? 0;
              
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
      });

      // 远端音频属性报告
      _registerEvent('onRemoteAudioPropertiesReport', (event) {
        try {
          if (event == null) return;
          
          // 处理多个远端音频
          final List<Map<String, dynamic>> users = [];
          final int length = js_util.getProperty(event, 'length') ?? 0;
          
          for (int i = 0; i < length; i++) {
            final dynamic audioInfo = event[i];
            if (audioInfo != null) {
              final dynamic streamKey = js_util.getProperty(audioInfo, 'streamKey');
              final dynamic properties = js_util.getProperty(audioInfo, 'audioPropertiesInfo');
              
              if (streamKey != null && properties != null) {
                final String userId = js_util.getProperty(streamKey, 'userId') ?? '';
                final int volume = js_util.getProperty(properties, 'linearVolume') ?? 0;
                
                users.add({
                  'userId': userId,
                  'volume': volume
                });
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
      });

      // 网络质量事件
      _registerEvent('onNetworkQuality', (uplink, downlink) {
        try {
          // 确保参数是整数
          final int uplinkQuality = uplink is int ? uplink : 0;
          final int downlinkQuality = downlink is int ? downlink : 0;
          
          // 计算平均网络质量（0-5，0表示最好，5表示最差）
          final int quality = ((uplinkQuality + downlinkQuality) / 2).floor();
          _networkQuality = quality;
          
          _networkQualityController.add({
            'uplinkQuality': uplinkQuality,
            'downlinkQuality': downlinkQuality,
            'overallQuality': quality,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        } catch (e) {
          debugPrint('处理网络质量事件出错: $e');
        }
      });
      
      debugPrint('所有RTC事件处理器注册完成');
    } catch (e) {
      debugPrint('注册RTC事件处理器失败: $e');
    }
  }
  
  /// 处理二进制消息
  void _processBinaryMessage(String userId, dynamic message) {
    if (message == null) return;
    
    try {
      // 尝试解析消息
      final String messageStr = WebUtils.binaryToString(message);
      final Map<String, dynamic> messageJson = jsonDecode(messageStr);
      
      // 检查消息类型
      if (messageJson.containsKey('type')) {
        final String type = messageJson['type'];
        
        // 处理字幕消息
        if (type == 'subtitle') {
          final String text = messageJson['text'] ?? '';
          final bool isFinal = messageJson['isFinal'] ?? false;
          
          _subtitleController.add(text);
          
          if (isFinal) {
            // 清空字幕
            _subtitleController.add('');
          }
        }
        
        // 处理AI状态消息
        if (type == 'state') {
          final String state = messageJson['state'] ?? '';
          
          if (state == 'thinking') {
            _isAIThinking = true;
            _isAITalking = false;
          } else if (state == 'speaking') {
            _isAIThinking = false;
            _isAITalking = true;
          } else if (state == 'idle') {
            _isAIThinking = false;
            _isAITalking = false;
          }
          
          _stateController.add({
            'type': 'ai_state',
            'state': state,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        }
      }
    } catch (e) {
      debugPrint('处理二进制消息出错: $e');
    }
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
  
  /// 销毁资源
  void dispose() {
    _stateController.close();
    _connectionStateController.close();
    _errorController.close();
    _audioDevicesController.close();
    _audioStatusController.close();
    _subtitleController.close();
    _userJoinController.close();
    _userLeaveController.close();
    _subtitleStateController.close();
    _audioPropertiesController.close();
    _networkQualityController.close();
  }
} 