import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';

import 'package:rtc_aigc_plugin/src/models/models.dart';

import '../config/aigc_config.dart';

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

  /// API 版本
  final String apiVersion = '2024-12-01';

  /// HTTP 客户端
  final http.Client _httpClient;

  final AigcConfig config;

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
    required this.config,
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
    debugPrint('[AigcClient] 新消息: ${message.text}');
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

      try {
        // 解析响应
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        debugPrint('[AigcClient] 接收响应: ${response.statusCode}');
        debugPrint('[AigcClient] 响应数据: ${jsonEncode(responseData)}');

        // 处理响应结果
        return _handleResponse(responseData, action);
      } catch (parseError) {
        debugPrint('[AigcClient] 解析响应JSON出错: $parseError');
        debugPrint('[AigcClient] 原始响应内容: ${response.body}');
        _setState(AigcClientState.error);
        throw Exception('解析响应JSON出错: $parseError，原始内容: ${response.body.substring(0, min(100, response.body.length))}...');
      }
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

    // 根据不同Action类型处理不同响应格式
    if (action == ActionType.startVoiceChat) {
      // 处理StartVoiceChat特定响应格式
      if (response.containsKey('Result')) {
        String result = response['Result'];
        
        // 任务已经开始的消息是正常的
        if (result.contains('The task has been started')) {
          debugPrint('[AigcClient] 任务已经启动，这是正常的响应');
          return response;
        } else if (result == 'ok') {
          return response;
        }
      }
      
      // 有Data字段的情况
      if (response.containsKey('Data')) {
        return response;
      }
    } else {
      // 其他Action类型的响应处理
      if (response.containsKey('Result') && response['Result'] == 'ok') {
        return response;
      } else if (response.containsKey('Data')) {
        return response;
      }
    }
    
    // 未知响应格式时的处理（不修改状态，只记录警告）
    // 注：移除直接抛出异常，以更宽容地处理各种响应格式
    debugPrint('[AigcClient] 警告：未知响应格式，但将继续处理: ${jsonEncode(response)}');
    return response;
  }

  /// 断开AIGC服务连接
  Future<bool> disconnect() async {
    if (!_isConnected) {
      debugPrint('[AigcClient] 未连接，无需断开');
      return true;
    }

    try {
      final result = await stopVoiceChat();

      _isConnected = false;
      _setState(AigcClientState.initial);

      // 对于特定响应格式，我们需要更灵活地处理
      if (result.containsKey('Result')) {
        return true;
      }
      return false;
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
        senderId: config.agentConfig?.userId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        text: text, // 添加文本内容到消息
      );
      _addMessage(userMessage);

      // 更新状态为等待响应
      _setState(AigcClientState.responding);

      // 发送更新命令给AI
      final params = {
        'AppId': config.appId,
        'RoomId': config.roomId,
        'TaskId': config.taskId,
        'Command': 'Text',
        'Message': text,
      };

      final result = await _post(
        action: ActionType.updateVoiceChat,
        name: 'update',
        params: params,
      );

      // 更灵活地处理成功响应
      if (result.containsKey('Result')) {
        return true;
      }
      return false;
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
        'AppId': config.appId,
        'RoomId': config.roomId,
        'TaskId': config.taskId,
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

      // 更灵活地处理成功响应
      if (result.containsKey('Result')) {
        return true;
      }
      return false;
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
    try {
      _isConnected = true;
      // 使用与Web Demo一致的参数结构
      final Map<String, dynamic> params = config.toJson();
      params['Config']['LLMConfig']['BotId'] = "BotId12";
      final result = await _post(
        action: ActionType.startVoiceChat,
        name: 'start',
        params: params,
      );
      
      // 如果成功启动，则更新状态为就绪
      _setState(AigcClientState.ready);
      
      return result;
    } catch (e) {
      _isConnected = false;
      _setState(AigcClientState.error);
      rethrow;
    }
  }

  /// 更新语音对话
  Future<Map<String, dynamic>> updateVoiceChat() async {
    final Map<String, dynamic> params = {
      'AppId': config.appId,
      'RoomId': config.roomId,
      'TaskId': config.taskId,
      'Command': 'interrupt'
    };

    return _post(
      action: ActionType.updateVoiceChat,
      name: 'update',
      params: params,
    );
  }

  /// 停止语音对话
  Future<Map<String, dynamic>> stopVoiceChat() async {
    final params = {
      'AppId': config.appId,
      'RoomId': config.roomId,
      'TaskId': config.taskId,
    };

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
