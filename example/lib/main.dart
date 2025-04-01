import 'dart:async';
import 'dart:js';
import 'dart:js_util' as js_util;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

// 临时的RtcEventHandler类，直到SDK中的类可用
class RtcEventHandler {
  final Function(dynamic error)? onError;
  final Function(dynamic event)? onUserJoined;
  final Function(dynamic event)? onUserLeave;
  final Function(String userId, int mediaType)? onUserPublishStream;
  final Function(String userId, int mediaType, dynamic reason)? onUserUnpublishStream;
  final Function(List<dynamic> reports)? onLocalAudioPropertiesReport;
  final Function(List<dynamic> reports)? onRemoteAudioPropertiesReport;
  final Function(String userId)? onUserStartAudioCapture;
  final Function(String userId)? onUserStopAudioCapture;

  RtcEventHandler({
    this.onError,
    this.onUserJoined,
    this.onUserLeave,
    this.onUserPublishStream,
    this.onUserUnpublishStream,
    this.onLocalAudioPropertiesReport,
    this.onRemoteAudioPropertiesReport,
    this.onUserStartAudioCapture,
    this.onUserStopAudioCapture,
  });
  
  // 添加registerWith方法，用于注册事件处理器
  void registerWith(JsObject engine, JsObject vertc) {
    if (onError != null) {
      engine.callMethod('on', [
        vertc['events']['onError'],
        allowInterop((e) => onError!(e))
      ]);
    }
    
    if (onUserJoined != null) {
      engine.callMethod('on', [
        vertc['events']['onUserJoined'],
        allowInterop((e) => onUserJoined!(e))
      ]);
    }
    
    if (onUserLeave != null) {
      engine.callMethod('on', [
        vertc['events']['onUserLeave'],
        allowInterop((e) => onUserLeave!(e))
      ]);
    }
    
    if (onUserPublishStream != null) {
      engine.callMethod('on', [
        vertc['events']['onUserPublishStream'],
        allowInterop((e) {
          final userId = e['userId'] as String;
          final mediaType = e['mediaType'] as int;
          onUserPublishStream!(userId, mediaType);
        })
      ]);
    }
    
    if (onUserUnpublishStream != null) {
      engine.callMethod('on', [
        vertc['events']['onUserUnpublishStream'],
        allowInterop((e) {
          final userId = e['userId'] as String;
          final mediaType = e['mediaType'] as int;
          final reason = e['reason'];
          onUserUnpublishStream!(userId, mediaType, reason);
        })
      ]);
    }
    
    if (onLocalAudioPropertiesReport != null) {
      engine.callMethod('on', [
        vertc['events']['onLocalAudioPropertiesReport'],
        allowInterop((e) => onLocalAudioPropertiesReport!(e))
      ]);
    }
    
    if (onRemoteAudioPropertiesReport != null) {
      engine.callMethod('on', [
        vertc['events']['onRemoteAudioPropertiesReport'],
        allowInterop((e) => onRemoteAudioPropertiesReport!(e))
      ]);
    }
    
    if (onUserStartAudioCapture != null) {
      engine.callMethod('on', [
        vertc['events']['onUserStartAudioCapture'],
        allowInterop((e) => onUserStartAudioCapture!(e['userId'] as String))
      ]);
    }
    
    if (onUserStopAudioCapture != null) {
      engine.callMethod('on', [
        vertc['events']['onUserStopAudioCapture'],
        allowInterop((e) => onUserStopAudioCapture!(e['userId'] as String))
      ]);
    }
  }
  
  // 辅助方法，用于创建允许互操作的JavaScript函数
  dynamic allowInterop(Function function) {
    return js_util.allowInterop(function);
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  bool _isInitialized = false;
  bool _isInRoom = false;
  bool _isAudioCaptureStarted = false;
  bool _isStreamPublished = false;
  bool _isVoiceChatStarted = false;
  String _voiceChatSessionId = '';
  
  // 添加事件日志
  List<String> _eventLogs = [];
  
  final VolcEngineRtcWebPlatform _plugin = VolcEngineRtcWebPlatform.instance;
  
  // 示例应用ID和房间信息，实际使用时请替换为您的有效凭证
  final String _appId = '67eb953062b4b601a6df1348';
  final String _roomId = 'room1';
  final String _userId = 'user1';
  final String _token = '00167eb953062b4b601a6df1348QAD+zlIF1rzrZ1b39GcFAHJvb20xBQB1c2VyMQYAAABW9/RnAQBW9/RnAgBW9/RnAwBW9/RnBABW9/RnBQBW9/RnIAD6T2vV6iui9SlU2USQJp2AiER6B4Sjr6Vui4qAn6S/JA=='; // 如需鉴权，请填入有效token

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _setupEventHandler();
  }

  // 获取平台版本
  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await _plugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }
  
  // 初始化引擎
  Future<void> _initializeEngine() async {
    try {
      final result = await _plugin.initializeEngine(_appId);
      setState(() {
        _isInitialized = result;
      });
      debugPrint('Engine initialized: $result');
      _logEvent('Engine initialized: $result');
    } catch (e) {
      debugPrint('Error initializing engine: $e');
      _logEvent('Error initializing engine: $e');
    }
  }
  
  // 加入房间
  Future<void> _joinRoom() async {
    if (!_isInitialized) {
      debugPrint('Engine not initialized');
      _logEvent('Engine not initialized');
      return;
    }
    
    try {
      final result = await _plugin.joinRoom(_roomId, _userId, _token);
      setState(() {
        _isInRoom = result;
      });
      debugPrint('Joined room: $result');
      _logEvent('Joined room: $result');
    } catch (e) {
      debugPrint('Error joining room: $e');
      _logEvent('Error joining room: $e');
    }
  }
  
  // 离开房间
  Future<void> _leaveRoom() async {
    if (!_isInRoom) {
      debugPrint('Not in room');
      _logEvent('Not in room');
      return;
    }
    
    try {
      final result = await _plugin.leaveRoom();
      setState(() {
        _isInRoom = !result;
        _isAudioCaptureStarted = false;
        _isStreamPublished = false;
        _isVoiceChatStarted = false;
        _voiceChatSessionId = '';
      });
      debugPrint('Left room: $result');
      _logEvent('Left room: $result');
    } catch (e) {
      debugPrint('Error leaving room: $e');
      _logEvent('Error leaving room: $e');
    }
  }
  
  // 开始音频采集
  Future<void> _toggleAudioCapture() async {
    if (!_isInRoom) {
      debugPrint('Not in room');
      _logEvent('Not in room');
      return;
    }
    
    try {
      bool result;
      if (_isAudioCaptureStarted) {
        result = await _plugin.stopAudioCapture();
        setState(() {
          _isAudioCaptureStarted = !result;
          if (result) {
            _isStreamPublished = false;
          }
        });
        debugPrint('Audio capture stopped: $result');
        _logEvent('Audio capture stopped: $result');
      } else {
        result = await _plugin.startAudioCapture();
        setState(() {
          _isAudioCaptureStarted = result;
        });
        debugPrint('Audio capture started: $result');
        _logEvent('Audio capture started: $result');
      }
    } catch (e) {
      debugPrint('Error toggling audio capture: $e');
      _logEvent('Error toggling audio capture: $e');
    }
  }
  
  // 发布/取消发布音频流
  Future<void> _togglePublishStream() async {
    if (!_isInRoom || !_isAudioCaptureStarted) {
      debugPrint('Not in room or audio capture not started');
      _logEvent('Not in room or audio capture not started');
      return;
    }
    
    try {
      bool result;
      if (_isStreamPublished) {
        result = await _plugin.unpublishStream(MediaType.AUDIO);
        setState(() {
          _isStreamPublished = !result;
        });
        debugPrint('Audio stream unpublished: $result');
        _logEvent('Audio stream unpublished: $result');
      } else {
        result = await _plugin.publishStream(MediaType.AUDIO);
        setState(() {
          _isStreamPublished = result;
        });
        debugPrint('Audio stream published: $result');
        _logEvent('Audio stream published: $result');
      }
    } catch (e) {
      debugPrint('Error toggling publish stream: $e');
      _logEvent('Error toggling publish stream: $e');
    }
  }
  
  // 开始/停止语音聊天
  Future<void> _toggleVoiceChat() async {
    if (!_isInRoom) {
      debugPrint('Not in room');
      _logEvent('Not in room');
      return;
    }
    
    try {
      if (_isVoiceChatStarted) {
        final Map<String, dynamic> response = await _plugin.stopVoiceChat(_voiceChatSessionId);
        final bool success = response['success'] as bool;
        setState(() {
          _isVoiceChatStarted = !success;
          if (success) {
            _voiceChatSessionId = '';
          }
        });
        debugPrint('Voice chat stopped: $success');
        _logEvent('Voice chat stopped: $success');
      } else {
        final agentConfig = AgentConfig(
          targetUserIds: [_userId],
          welcomeMessage: 'Hello from Flutter plugin!',
          userId: 'ai_assistant',
        );
        
        final options = VoiceChatOptions(
          appId: _appId,
          roomId: _roomId,
          taskId: _userId,
          agentConfig: agentConfig,
        );
        
        final Map<String, dynamic> response = await _plugin.startVoiceChat(options.toMap());
        final String sessionId = response['sessionId'] as String;
        setState(() {
          _isVoiceChatStarted = sessionId.isNotEmpty;
          _voiceChatSessionId = sessionId;
        });
        debugPrint('Voice chat started with session ID: $sessionId');
        _logEvent('Voice chat started with session ID: $sessionId');
      }
    } catch (e) {
      debugPrint('Error toggling voice chat: $e');
      _logEvent('Error toggling voice chat: $e');
    }
  }
  
  // 发送命令到语音聊天
  Future<void> _sendCommand() async {
    if (!_isVoiceChatStarted) {
      debugPrint('Voice chat not started');
      _logEvent('Voice chat not started');
      return;
    }
    
    try {
      final options = VoiceChatCommandOptions(
        appId: _appId,
        roomId: _roomId,
        taskId: _userId,
        command: VoiceChatCommands.INTERRUPT,
      );
      
      final Map<String, dynamic> response = await _plugin.updateVoiceChat(_voiceChatSessionId, options.toMap());
      final String result = response['result'] as String;
      debugPrint('Command sent with result: $result');
      _logEvent('Command sent with result: $result');
    } catch (e) {
      debugPrint('Error sending command: $e');
      _logEvent('Error sending command: $e');
    }
  }

  // 设置事件处理器
  void _setupEventHandler() {
    final eventHandler = RtcEventHandler(
      onError: (error) {
        _logEvent('Error: $error');
      },
      onUserJoined: (event) {
        _logEvent('User joined: ${event['userId']}');
      },
      onUserLeave: (event) {
        _logEvent('User left: ${event['userId']}');
      },
      onUserPublishStream: (userId, mediaType) {
        _logEvent('User $userId published stream with mediaType: $mediaType');
      },
      onUserUnpublishStream: (userId, mediaType, reason) {
        String reasonStr = reason is String ? reason : reason.toString();
        _logEvent('User $userId unpublished stream with mediaType: $mediaType, reason: $reasonStr');
      },
      onLocalAudioPropertiesReport: (reports) {
        for (final report in reports) {
          _logEvent('Local audio properties: ${report['captureVolume']}');
        }
      },
      onRemoteAudioPropertiesReport: (reports) {
        for (final report in reports) {
          _logEvent('Remote audio properties for user ${report['userId']}: ${report['audioPropertiesInfo']}');
        }
      },
      onUserStartAudioCapture: (userId) {
        _logEvent('User $userId started audio capture');
      },
      onUserStopAudioCapture: (userId) {
        _logEvent('User $userId stopped audio capture');
      },
    );
    
    _plugin.setEventHandler(eventHandler);
  }

  // 记录事件
  void _logEvent(String event) {
    setState(() {
      final timestamp = DateTime.now().toString().split('.').first;
      _eventLogs.add('[$timestamp] $event');
      // 限制日志数量
      if (_eventLogs.length > 100) {
        _eventLogs.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('VolcEngine RTC Web Plugin Example'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 20),
              
              // 初始化引擎
              ElevatedButton(
                onPressed: _isInitialized ? null : _initializeEngine,
                child: Text(_isInitialized ? 'Engine Initialized' : 'Initialize Engine'),
              ),
              const SizedBox(height: 8),
              
              // 加入/离开房间
              ElevatedButton(
                onPressed: !_isInitialized ? null : (_isInRoom ? _leaveRoom : _joinRoom),
                child: Text(_isInRoom ? 'Leave Room' : 'Join Room'),
              ),
              const SizedBox(height: 8),
              
              // 开始/停止音频采集
              ElevatedButton(
                onPressed: !_isInRoom ? null : _toggleAudioCapture,
                child: Text(_isAudioCaptureStarted ? 'Stop Audio Capture' : 'Start Audio Capture'),
              ),
              const SizedBox(height: 8),
              
              // 发布/取消发布音频流
              ElevatedButton(
                onPressed: (!_isInRoom || !_isAudioCaptureStarted) ? null : _togglePublishStream,
                child: Text(_isStreamPublished ? 'Unpublish Audio Stream' : 'Publish Audio Stream'),
              ),
              const SizedBox(height: 20),
              
              const Divider(),
              const SizedBox(height: 20),
              
              // 开始/停止语音聊天
              ElevatedButton(
                onPressed: !_isInRoom ? null : _toggleVoiceChat,
                child: Text(_isVoiceChatStarted ? 'Stop Voice Chat' : 'Start Voice Chat'),
              ),
              const SizedBox(height: 8),
              
              // 发送命令
              ElevatedButton(
                onPressed: !_isVoiceChatStarted ? null : _sendCommand,
                child: const Text('Send Interrupt Command'),
              ),
              
              const SizedBox(height: 20),
              if (_voiceChatSessionId.isNotEmpty)
                Text('Voice Chat Session ID: $_voiceChatSessionId'),
                
              // 事件日志部分
              const Divider(),
              const SizedBox(height: 10),
              const Text('Event Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  reverse: true,
                  itemCount: _eventLogs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _eventLogs[_eventLogs.length - 1 - index],
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _eventLogs.clear();
                  });
                },
                child: const Text('Clear Logs'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
