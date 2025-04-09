import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:js' as js;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';
import 'package:rtc_aigc_plugin/src/utils/rtc_message_utils.dart';

/// Handles message processing and TLV parsing
class RtcMessageHandler {
  final RtcConfig config;
  dynamic _rtcClient;

  // Stream controllers for messages
  final StreamController<Map<String, dynamic>?> _subtitleController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final StreamController<Map<String, dynamic>> _messageHistoryController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _functionCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Message history storage
  List<Map<String, dynamic>> _messageHistory = [];

  // Streams
  Stream<Map<String, dynamic>?> get subtitleStream =>
      _subtitleController.stream;
  Stream<Map<String, dynamic>> get messageHistoryStream =>
      _messageHistoryController.stream;
  Stream<Map<String, dynamic>> get functionCallStream =>
      _functionCallController.stream;

  RtcMessageHandler({required this.config});

  void setEngine(dynamic rtcClient) {
    _rtcClient = rtcClient;
  }

  /// 处理二进制消息
  void handleBinaryMessage(dynamic userId, dynamic message) {
    if (message == null || userId == null) {
      debugPrint('【消息处理】无效的二进制消息');
      return;
    }

    try {
      // 处理userId为对象的情况
      final userIdStr = userId is Map
          ? (userId['userId'] ?? 'unknown')
          : (userId is String ? userId : userId.toString());

      // 检查是否允许处理所有消息，默认只处理AI消息
      final bool processAllMessages = config.processAllMessages ?? false;

      // 消息过滤 - 如果不是处理所有消息，则只处理来自AI的消息
      if (!processAllMessages &&
          userIdStr != 'BotName001' &&
          !userIdStr.contains('bot') &&
          userIdStr != 'RobotMan_') {
        debugPrint('【消息处理】跳过非AI消息: $userIdStr');
        return;
      }

      // 记录消息信息，但对于大二进制数据只记录长度
      if (kDebugMode) {
        String lengthInfo = '';
        if (message is ByteBuffer) {
          lengthInfo = '${message.lengthInBytes} bytes';
        } else if (message is js.JsObject &&
            js_util.hasProperty(message, 'byteLength')) {
          lengthInfo = '${js_util.getProperty(message, 'byteLength')} bytes';
        } else {
          lengthInfo = 'unknown size';
        }
        debugPrint('【消息处理】接收到消息 - 来源: $userIdStr, 长度: $lengthInfo');
      }

      // 尝试使用TLV解析
      final parsedData = RtcAigcMessageUtils.parseTlvMessage(message);
      if (parsedData == null) {
        debugPrint('【消息处理】尝试直接解析消息体...');
        // 尝试直接解析二进制消息
        try {
          final String directText = WebUtils.binaryToString(message);
          if (directText.isNotEmpty) {
            try {
              // 尝试解析为JSON
              final jsonData = jsonDecode(directText);
              _handleDirectJsonMessage(userIdStr, jsonData);
              return;
            } catch (jsonError) {
              // 如果不是JSON，直接作为文本消息处理
              final subtitleMap = <String, dynamic>{
                'text': directText,
                'isFinal': true,
                'userId': userIdStr,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
              _subtitleController.add(subtitleMap);
              addMessageToHistory(subtitleMap);
              return;
            }
          }
        } catch (directError) {
          debugPrint('【消息处理】直接解析消息体失败: $directError');
        }

        debugPrint('【消息处理】无法解析消息内容');
        return;
      }

      // 根据消息类型进行处理
      final messageType = parsedData['type'];
      final data = parsedData['data'];

      debugPrint('【消息处理】处理消息类型: $messageType');

      switch (messageType) {
        case 'subv': // SUBTITLE - 字幕消息
          debugPrint('【消息处理】解析到字幕消息');
          handleSubtitleMessage(data);
          break;
        case 'func': // FUNCTION_CALL - 函数调用消息
          debugPrint('【消息处理】解析到函数调用消息');
          _handleFunctionCallMessage(data);
          break;
        case 'ctrl': // CONTROL - 控制消息，包含AI状态变化
          debugPrint('【消息处理】解析到控制消息');
          _handleControlMessage(data);
          break;
        case 'conv': // 在js端对应MESSAGE_TYPE.BRIEF
          debugPrint('【消息处理】解析到会话状态消息');
          _handleStateMessage(data);
          break;
        default:
          debugPrint('【消息处理】未知的消息类型: $messageType');
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('【消息处理】处理二进制消息失败: $e');
      debugPrint('【消息处理】错误堆栈: $stackTrace');
    }
  }

  /// 处理直接的JSON消息（非TLV格式）
  void _handleDirectJsonMessage(String userId, dynamic jsonData) {
    try {
      if (jsonData == null) {
        debugPrint('【消息处理】JSON数据为空');
        return;
      }

      // 尝试检查消息类型
      if (jsonData is Map) {
        // 检查是否包含Stage字段，表示这是一个状态消息
        if (jsonData.containsKey('Stage')) {
          _handleStateMessage(jsonData);
          return;
        }

        // 检查是否包含tool_calls字段，表示这是一个函数调用消息
        if (jsonData.containsKey('tool_calls')) {
          _handleFunctionCallMessage(jsonData);
          return;
        }

        // 检查是否是字幕类型消息
        if (jsonData.containsKey('data') && jsonData['data'] is List) {
          final type = jsonData['type']?.toString() ?? '';
          if (type == 'subv' || type == 'subtitle') {
            handleSubtitleMessage(jsonData);
            return;
          }
        }

        // 如果包含text字段，可能是直接的字幕消息
        if (jsonData.containsKey('text')) {
          final subtitleMap = <String, dynamic>{
            'text': jsonData['text']?.toString() ?? '',
            'isFinal':
                jsonData['isFinal'] == true || jsonData['definite'] == true,
            'userId': userId,
            'timestamp':
                jsonData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          };
          _subtitleController.add(subtitleMap);
          addMessageToHistory(subtitleMap);
          return;
        }
      }

      // 如果无法识别特定类型，记录数据供调试
      debugPrint(
          '【消息处理】无法识别的直接JSON消息: ${jsonEncode(jsonData).substring(0, min(200, jsonEncode(jsonData).length))}...');
    } catch (e) {
      debugPrint('【消息处理】处理直接JSON消息失败: $e');
    }
  }

  /// 处理字幕数据 - 对onSubtitle回调的处理逻辑
  void processSubtitleData(dynamic subtitleData) {
    try {
      String text = '';
      bool isFinal = false;
      String userId = 'BotName001';
      bool paragraph = false;
      String language = 'zh';
      int sequence = 0;
      int timestamp = DateTime.now().millisecondsSinceEpoch;

      // 从JS对象提取数据
      if (subtitleData is js.JsObject) {
        debugPrint('【字幕处理】处理JS对象字幕');
        try {
          text = js_util.getProperty(subtitleData, 'text')?.toString() ?? '';
          isFinal = js_util.getProperty(subtitleData, 'isFinal') == true;
          userId = js_util.getProperty(subtitleData, 'userId')?.toString() ??
              'BotName001';
          paragraph = js_util.getProperty(subtitleData, 'paragraph') == true;
          language =
              js_util.getProperty(subtitleData, 'language')?.toString() ?? 'zh';
          sequence = js_util.getProperty(subtitleData, 'sequence') ?? 0;
          timestamp = js_util.getProperty(subtitleData, 'timestamp') ??
              DateTime.now().millisecondsSinceEpoch;
        } catch (e) {
          debugPrint('【字幕处理】获取JS对象字幕属性出错: $e');
        }
      } else if (subtitleData is Map) {
        debugPrint('【字幕处理】处理Map字幕');
        text = subtitleData['text']?.toString() ?? '';
        isFinal = subtitleData['isFinal'] == true;
        userId = subtitleData['userId']?.toString() ?? 'BotName001';
        paragraph = subtitleData['paragraph'] == true;
        language = subtitleData['language']?.toString() ?? 'zh';
        sequence = subtitleData['sequence'] ?? 0;
        timestamp =
            subtitleData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
      } else {
        // 尝试转为字符串
        debugPrint('【字幕处理】未知类型字幕数据，尝试转为字符串');
        text = subtitleData.toString();
      }

      if (text.isEmpty) {
        debugPrint('【字幕处理】字幕文本为空，跳过处理');
        return;
      }

      // 构建字幕映射对象
      final subtitleMap = <String, dynamic>{
        'text': text,
        'isFinal': isFinal,
        'userId': userId,
        'paragraph': paragraph,
        'language': language,
        'sequence': sequence,
        'timestamp': timestamp,
      };

      debugPrint(
          '【字幕处理】字幕内容: "${text.substring(0, min(30, text.length))}"${text.length > 30 ? "..." : ""} (isFinal: $isFinal)');

      // 发送字幕事件
      _subtitleController.add(subtitleMap);

      // 添加到消息历史
      addMessageToHistory(subtitleMap);
    } catch (e) {
      debugPrint('【字幕处理】处理字幕数据出错: $e');
    }
  }

  /// 处理字幕消息
  void handleSubtitleMessage(dynamic parsedData) {
    try {
      if (parsedData['data'] == null ||
          !(parsedData['data'] is List) ||
          parsedData['data'].isEmpty) {
        debugPrint('【字幕处理】字幕数据格式无效');
        return;
      }

      final subtitleData = parsedData['data'][0];
      debugPrint('【字幕处理】处理字幕消息数据类型: ${subtitleData.runtimeType}');

      // 提取字幕文本和其他属性
      String text = '';
      bool isFinal = false;
      String userId = 'BotName001';
      bool paragraph = false;
      String language = 'zh';
      int sequence = 0;

      if (subtitleData != null) {
        if (subtitleData is Map) {
          // Web demo中使用text和definite作为键名
          text = subtitleData['text']?.toString() ?? '';
          isFinal = subtitleData['definite'] == true;
          userId = subtitleData['userId']?.toString() ?? 'BotName001';
          paragraph = subtitleData['paragraph'] == true;
          language = subtitleData['language']?.toString() ?? 'zh';
          sequence = subtitleData['sequence'] ?? 0;
        } else if (subtitleData is js.JsObject) {
          // 使用js_util安全获取属性
          text = js_util.getProperty(subtitleData, 'text')?.toString() ?? '';
          isFinal = js_util.getProperty(subtitleData, 'definite') == true;
          userId = js_util.getProperty(subtitleData, 'userId')?.toString() ??
              'BotName001';
          paragraph = js_util.getProperty(subtitleData, 'paragraph') == true;
          language =
              js_util.getProperty(subtitleData, 'language')?.toString() ?? 'zh';
          sequence = js_util.getProperty(subtitleData, 'sequence') ?? 0;
        } else if (subtitleData is String) {
          // 如果数据直接是字符串
          text = subtitleData;
        } else {
          // 尝试使用toString
          try {
            text = subtitleData.toString();
            debugPrint('【字幕处理】使用toString()转换字幕: $text');
          } catch (e) {
            debugPrint('【字幕处理】字幕数据转换失败: $e');
          }
        }
      }

      if (text.isEmpty) {
        debugPrint('【字幕处理】字幕文本为空，跳过处理');
        return;
      }

      // 记录提取的字幕文本
      debugPrint(
          '【字幕处理】字幕内容: "${text.substring(0, min(50, text.length))}"${text.length > 50 ? "..." : ""} (isFinal: $isFinal)');

      final subtitleMap = <String, dynamic>{
        'text': text,
        'isFinal': isFinal,
        'userId': userId,
        'paragraph': paragraph,
        'language': language,
        'sequence': sequence,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 发送字幕事件
      _subtitleController.add(subtitleMap);

      // 只有在有内容时才添加到历史
      if (text.isNotEmpty) {
        addMessageToHistory(subtitleMap);
        debugPrint('【字幕处理】字幕已添加到消息历史');
      }
    } catch (e) {
      debugPrint('【字幕处理】处理字幕消息失败: $e');
    }
  }

  /// 处理控制消息
  void _handleControlMessage(dynamic data) {
    try {
      if (data is Map && data['Stage'] != null) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        final Map<String, dynamic> typedData = {};
        data.forEach((key, value) {
          if (key is String) {
            typedData[key] = value;
          }
        });
        _handleStateMessage(typedData);
      } else {
        debugPrint('【消息处理】未知的控制消息格式: $data');
      }
    } catch (e) {
      debugPrint('【消息处理】处理控制消息失败: $e');
    }
  }

  /// 处理状态消息
  void _handleStateMessage(Map<dynamic, dynamic> parsedData) {
    try {
      final stage = parsedData['Stage'];
      if (stage == null) {
        debugPrint('【状态处理】状态数据为空');
        return;
      }

      final code = stage['Code'];
      final description = stage['Description'] ?? '';

      debugPrint('【状态处理】AI状态更新: $code - $description');

      // 构建状态消息
      final stateMap = {
        'state': _getStateStringFromCode(code),
        'stateCode': code,
        'description': description,
        'isThinking': code == 2, // THINKING
        'isTalking': code == 3, // SPEAKING
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 发送状态更新到消息流
      _messageHistoryController.add(stateMap);

      debugPrint('【状态处理】状态已更新并通知UI');
    } catch (e) {
      debugPrint('【状态处理】处理状态消息失败: $e');
    }
  }

  /// 获取状态码对应的字符串
  String _getStateStringFromCode(int code) {
    switch (code) {
      case 1:
        return 'LISTENING';
      case 2:
        return 'THINKING';
      case 3:
        return 'SPEAKING';
      case 4:
        return 'INTERRUPTED';
      case 5:
        return 'FINISHED';
      default:
        return 'UNKNOWN';
    }
  }

  /// 处理函数调用消息
  void _handleFunctionCallMessage(Map<dynamic, dynamic> data) {
    if (data.isEmpty) {
      debugPrint('【函数调用】收到空的函数调用消息');
      return;
    }

    debugPrint(
        '【函数调用】收到函数调用消息: ${jsonEncode(data).substring(0, min(100, jsonEncode(data).length))}...');

    try {
      final toolCalls = data['tool_calls'];
      if (toolCalls is! List || toolCalls.isEmpty) {
        debugPrint('【函数调用】无效的tool_calls格式');
        return;
      }

      // 从第一个工具调用中提取信息
      final toolCall = toolCalls[0];
      final function = toolCall['function'];

      // 提取函数名和参数
      final functionName = function['name'];
      final functionArgs = function['arguments'];
      final toolCallId = toolCall['id'];

      debugPrint('【函数调用】函数名: $functionName, 工具ID: $toolCallId');
      debugPrint('【函数调用】参数: $functionArgs');

      // 发送到函数流
      final functionCallData = {
        'id': toolCallId,
        'name': functionName,
        'arguments':
            functionArgs is String ? jsonDecode(functionArgs) : functionArgs,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _functionCallController.add(functionCallData);

      // 自动响应特定函数调用
      _autoRespondToFunctionCall(toolCallId, functionName,
          functionArgs is String ? jsonDecode(functionArgs) : functionArgs);
    } catch (e) {
      debugPrint('【函数调用】解析函数调用消息失败: $e');
    }
  }

  /// 自动响应特定函数调用
  void _autoRespondToFunctionCall(
      String toolCallId, String functionName, dynamic args) {
    try {
      // 构造标准响应格式
      Map<String, dynamic> responseContent = {
        'ToolCallID': toolCallId,
        'Content': {}
      };

      // 根据函数名生成响应
      switch (functionName) {
        case 'get_time':
          final now = DateTime.now();
          responseContent['Content'] = {
            'current_time': now.toIso8601String(),
            'timezone': now.timeZoneName,
          };
          break;

        case 'get_user_info':
          responseContent['Content'] = {
            'name': 'Flutter用户',
            'id': config.userId,
            'platform': 'Flutter',
            'device': 'Mobile/Desktop',
          };
          break;

        default:
          responseContent['Content'] = {
            'error': '未实现的功能',
            'message': '当前Flutter插件未实现该功能的自动响应',
          };
          break;
      }

      // 发送响应给AIGC
      if (_rtcClient != null) {
        final tlvData = jsonEncode(responseContent);

        // 调用JavaScript方法发送响应
        WebUtils.safeJsCall(_rtcClient, 'sendMessageToBot', [tlvData]);

        debugPrint(
            '【函数调用】已发送自动响应: ${jsonEncode(responseContent).substring(0, min(100, jsonEncode(responseContent).length))}...');
      } else {
        debugPrint('【函数调用】无法发送响应：RTC客户端未初始化');
      }
    } catch (e) {
      debugPrint('【函数调用】发送自动响应失败: $e');
    }
  }

  /// 添加消息到历史记录
  void addMessageToHistory(Map<String, dynamic> messageData) {
    // 如果是临时消息且历史记录中已有消息
    if (messageData['isFinal'] == false && _messageHistory.isNotEmpty) {
      final lastMessage = _messageHistory.last;

      // 如果最后一条是同一用户的消息且不是最终消息，则更新它
      if (lastMessage['userId'] == messageData['userId'] &&
          lastMessage['isFinal'] == false) {
        lastMessage['text'] = messageData['text'];
        lastMessage['timestamp'] = messageData['timestamp'];
        _messageHistoryController.add(lastMessage);
        return;
      }
    }

    // 如果是最终消息或不同用户的消息，则添加新消息
    if (messageData['isFinal'] == true ||
        _messageHistory.isEmpty ||
        _messageHistory.last['userId'] != messageData['userId']) {
      _messageHistory.add(Map<String, dynamic>.from(messageData));

      // 如果历史记录超过50条，移除最早的
      if (_messageHistory.length > 50) {
        _messageHistory.removeAt(0);
      }

      _messageHistoryController.add(messageData);
    }
  }

  /// 获取消息历史
  List<Map<String, dynamic>> getMessageHistory() {
    return _messageHistory;
  }

  /// 清空消息缓存
  void clearMessageCache() {
    // 保留最近的任务开始/结束消息，清除其他消息
    final latestMessages = _messageHistory
        .where((msg) =>
            msg['type'] == 'task_started' || msg['type'] == 'task_stopped')
        .toList();

    if (latestMessages.length > 10) {
      // 只保留最近的10个任务记录
      latestMessages.removeRange(0, latestMessages.length - 10);
    }

    _messageHistory = latestMessages;
  }

  /// 发送函数调用结果
  Future<bool> sendFunctionCallResult(
      String toolCallId, Map<String, dynamic> content) async {
    if (_rtcClient == null) {
      debugPrint('【函数调用】无法发送函数调用结果：RTC客户端未初始化');
      return false;
    }

    try {
      // 构造标准响应格式
      Map<String, dynamic> responseContent = {
        'ToolCallID': toolCallId,
        'Content': content
      };

      final tlvData = jsonEncode(responseContent);

      // 调用JavaScript方法发送响应
      WebUtils.safeJsCall(_rtcClient, 'sendMessageToBot', [tlvData]);

      debugPrint('【函数调用】已发送函数调用结果');
      return true;
    } catch (e) {
      debugPrint('【函数调用】发送函数调用结果失败: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      await _subtitleController.close();
      await _messageHistoryController.close();
      await _functionCallController.close();

      debugPrint('RTC消息处理器已清理');
    } catch (e) {
      debugPrint('清理RTC消息处理器时出错: $e');
    }
  }
}
