import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';

/// API 操作类型
enum ActionType {
  /// 开始语音对话
  startVoiceChat('StartVoiceChat'),

  /// 更新语音对话
  updateVoiceChat('UpdateVoiceChat'),

  /// 停止语音对话
  stopVoiceChat('StopVoiceChat');

  final String value;
  const ActionType(this.value);
}

/// AIGC 客户端 - 统一管理与火山引擎API的交互
class AigcClient {
  /// 服务器基础URL
  final String baseUrl;

  /// 应用ID
  final String appId;

  final AsrConfig asrConfig;

  final TtsConfig ttsConfig;

  final LlmConfig llmConfig;

  /// API 版本
  final String apiVersion;

  /// HTTP 客户端
  final http.Client _httpClient;

  /// 当前房间ID
  String roomId;

  /// 当前用户ID
  String userId;

  /// 当前任务ID
  String taskId;

  String token;

  /// 是否已连接
  bool _isConnected = false;

  /// 客户端状态
  AigcClientState _state = AigcClientState.initial;

  /// 消息流控制器
  final StreamController<RtcAigcMessage> _messageController =
      StreamController<RtcAigcMessage>.broadcast();

  /// 状态流控制器
  final StreamController<AigcClientState> _stateController =
      StreamController<AigcClientState>.broadcast();

  /// 消息历史记录
  final List<RtcAigcMessage> _messageHistory = [];

  /// 构造函数
  AigcClient({
    required this.baseUrl,
    required this.appId,
    required this.roomId,
    required this.userId,
    required this.token,
    required this.taskId,
    required this.asrConfig,
    required this.ttsConfig,
    required this.llmConfig,
    this.apiVersion = '2024-12-01',
  }) : _httpClient = http.Client();

  /// 消息流
  Stream<RtcAigcMessage> get messageStream => _messageController.stream;

  /// 状态流
  Stream<AigcClientState> get stateStream => _stateController.stream;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 当前状态
  AigcClientState get state => _state;

  /// 消息历史
  List<RtcAigcMessage> get messageHistory => List.unmodifiable(_messageHistory);

  /// 设置状态并广播
  void _setState(AigcClientState newState) {
    if (_state != newState) {
      _state = newState;
      debugPrint('[AigcClient] 状态变更: $_state');
      _stateController.add(_state);
    }
  }

  /// 添加消息并广播
  void _addMessage(RtcAigcMessage message) {
    _messageHistory.add(message);
    _messageController.add(message);
    debugPrint('[AigcClient] 新消息: ${message.content}');
  }

  /// 生成唯一请求ID
  String _generateRequestId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${(1000 + Random().nextInt(9000))}';
  }

  /// 发送POST请求
  Future<Map<String, dynamic>> _post({
    required ActionType action,
    required String name,
    required Map<String, dynamic> params,
  }) async {
    try {
      // 构建API URL - 与api.ts保持一致的格式
      final Uri uri = Uri.parse(
          '$baseUrl/proxyAIGCFetch?Name=$name&Action=${action.value}&Version=$apiVersion');

      // 确保请求中包含AppId
      if (!params.containsKey('AppId')) {
        params['AppId'] = appId;
      }

      // 添加请求ID
      if (!params.containsKey('RequestId')) {
        params['RequestId'] = _generateRequestId();
      }

      // 发送请求
      debugPrint('[AigcClient] 发送请求: $uri');
      debugPrint('[AigcClient] 请求参数: ${jsonEncode(params)}');

      final response = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(params),
      );

      // 解析响应
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      debugPrint('[AigcClient] 接收响应: ${response.statusCode}');
      debugPrint('[AigcClient] 响应数据: ${jsonEncode(responseData)}');

      // 处理响应结果
      return _handleResponse(responseData, action);
    } catch (e) {
      debugPrint('[AigcClient] 请求错误: $e');
      _setState(AigcClientState.error);
      rethrow;
    }
  }

  /// 处理响应结果
  Map<String, dynamic> _handleResponse(
      Map<String, dynamic> response, ActionType action) {
    // 检查响应中是否包含错误信息
    if (response.containsKey('ResponseMetadata') &&
        response['ResponseMetadata'] is Map &&
        (response['ResponseMetadata'] as Map).containsKey('Error')) {
      final error = response['ResponseMetadata']['Error'];
      _setState(AigcClientState.error);
      throw Exception(
        '[${action.value}] 请求失败: ${error['Code']} - ${error['Message']}',
      );
    }

    // 检查结果
    if (response.containsKey('Result') && response['Result'] == 'ok') {
      return response;
    } else if (response.containsKey('Data')) {
      return response;
    } else {
      _setState(AigcClientState.error);
      throw Exception('未知响应格式: ${jsonEncode(response)}');
    }
  }

  /// 断开AIGC服务连接
  Future<bool> disconnect() async {
    if (!_isConnected) {
      debugPrint('[AigcClient] 未连接，无需断开');
      return true;
    }

    try {
      final result = await stopVoiceChat(
        roomId: roomId,
        userId: userId,
        taskId: taskId,
      );

      _isConnected = false;
      _setState(AigcClientState.initial);

      return result['Result'] == 'ok';
    } catch (e) {
      debugPrint('[AigcClient] 断开连接失败: $e');
      _setState(AigcClientState.error);
      return false;
    }
  }

  /// 发送消息给AI
  Future<bool> sendMessage(String text) async {
    if (!_isConnected) {
      debugPrint('[AigcClient] 未连接，无法发送消息');
      return false;
    }

    try {
      // 添加用户消息到历史记录
      final userMessage = RtcAigcMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        type: MessageType.user,
        content: text,
        senderId: userId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addMessage(userMessage);

      // 更新状态为等待响应
      _setState(AigcClientState.responding);

      // 发送更新命令给AI
      final params = {
        'AppId': appId,
        'RoomId': roomId,
        'TaskId': taskId,
        'Command': 'Text',
        'Message': text,
      };

      final result = await _post(
        action: ActionType.updateVoiceChat,
        name: 'update',
        params: params,
      );

      return result['Result'] == 'ok';
    } catch (e) {
      debugPrint('[AigcClient] 发送消息失败: $e');
      _setState(AigcClientState.error);
      return false;
    }
  }

  /// 取消AI响应（打断）
  Future<bool> cancelResponse() async {
    if (!_isConnected) {
      debugPrint('[AigcClient] 未连接，无法取消响应');
      return false;
    }

    try {
      // 发送中断命令
      final params = {
        'AppId': appId,
        'RoomId': roomId,
        'TaskId': taskId,
        'Command': 'interrupt',
      };

      final result = await _post(
        action: ActionType.updateVoiceChat,
        name: 'update',
        params: params,
      );

      // 更新最后一条AI消息为中断状态
      for (int i = _messageHistory.length - 1; i >= 0; i--) {
        final message = _messageHistory[i];
        if (message.type == MessageType.ai) {
          final updatedMessage = message.copyWith(isInterrupted: true);
          _messageHistory[i] = updatedMessage;
          _messageController.add(updatedMessage);
          break;
        }
      }

      // 更新状态为准备就绪
      _setState(AigcClientState.ready);

      return result['Result'] == 'ok';
    } catch (e) {
      debugPrint('[AigcClient] 取消响应失败: $e');
      return false;
    }
  }

  /// 开始语音对话
  Future<Map<String, dynamic>> startVoiceChat({
    String? businessId,
    String? welcomeMessage,
  }) async {
    _isConnected = true;
    // 使用与Web Demo一致的参数结构
    final Map<String, dynamic> params = {
      'AppId': appId,
      'RoomId': roomId,
      'TaskId': taskId, // TaskId实际上是用户ID
      'BusinessId': businessId,

      // 添加AgentConfig，与Web Demo保持一致
      'AgentConfig': {
        'UserId': 'RobotMan_', // 使用固定的机器人ID
        'WelcomeMessage': welcomeMessage ?? '你好，我是你的AI小助手，有什么可以帮你的吗？',
        'EnableConversationStateCallback': true,
        'ServerMessageSignatureForRTS': 'conversation',
        'TargetUserId': [userId], // TargetUserId是一个数组，包含用户ID
      },

      // 添加Config配置，保持与Web Demo结构一致
      'Config': {
        'LLMConfig': {
          'Mode': 'ArkV3',
          'ModelName': llmConfig?.modelName ?? 'Doubao-pro-32k',
          'MaxTokens': 1024,
          'Temperature': 0.1,
          'TopP': 0.3,
          'SystemMessages':
              llmConfig?.systemMessages ?? ['你是一个智能助手，性格温和，善解人意，喜欢帮助别人，非常热心。'],
          'ModelVersion': llmConfig?.modelVersion ?? '1.0',
        },

        'ASRConfig': {
          'Provider': 'volcano',
          'ProviderParams': {
            'Mode': 'smallmodel',
            'AppId': asrConfig?.appId ?? this.asrConfig.appId,
            'Cluster': 'volcengine_streaming_common'
          },
          'VADConfig': {
            'SilenceTime': 600,
            'SilenceThreshold': 200,
          },
          'VolumeGain': 0.3,
        },

        'TTSConfig': {
          'Provider': 'volcano',
          'ProviderParams': {
            'app': {
              'AppId': ttsConfig?.appId ?? this.ttsConfig.appId,
              'Cluster': 'streaming_tts', // 使用火山引擎流式TTS服务
            },
            'audio': {
              'voice_type': ttsConfig?.voiceType ?? this.ttsConfig.voiceType,
              'speed_ratio': 1.0,
            },
          },
          'IgnoreBracketText': [1, 2, 3, 4, 5],
        },

        'InterruptMode': 0, // 0表示启用中断模式

        'SubtitleConfig': {
          'SubtitleMode': 0,
        },
      },
    };

    return _post(
      action: ActionType.startVoiceChat,
      name: 'start',
      params: params,
    );
  }

  /// 更新语音对话
  Future<Map<String, dynamic>> updateVoiceChat({
    Map<String, dynamic>? asrConfig,
    Map<String, dynamic>? ttsConfig,
    Map<String, dynamic>? llmConfig,
  }) async {
    final Map<String, dynamic> params = {
      'AppId': appId,
      'RoomId': roomId,
      'TaskId': taskId,
      'Command': 'interrupt'
    };

    return _post(
      action: ActionType.updateVoiceChat,
      name: 'update',
      params: params,
    );
  }

  /// 停止语音对话
  Future<Map<String, dynamic>> stopVoiceChat({
    required String roomId,
    required String userId,
    required String taskId,
    String? businessId,
  }) async {
    final params = {
      'AppId': appId,
      'RoomId': roomId,
      'TaskId': taskId,
    };

    if (businessId != null) {
      params['BusinessId'] = businessId;
    }

    return _post(
      action: ActionType.stopVoiceChat,
      name: 'stop',
      params: params,
    );
  }

  /// 销毁资源
  void dispose() {
    debugPrint('[AigcClient] 销毁资源');
    _httpClient.close();
    _messageController.close();
    _stateController.close();
  }
}
