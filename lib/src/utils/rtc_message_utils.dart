import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Utility class for handling RTC AIGC messages
class RtcAigcMessageUtils {
  /// Format a message for UI display
  static Map<String, dynamic> formatMessageForUI(Map<String, dynamic> message) {
    if (message.isEmpty) {
      return {'type': 'unknown', 'text': '', 'timestamp': DateTime.now().millisecondsSinceEpoch};
    }

    // Handle different message types
    if (message['type'] == 'task_started') {
      return {
        'type': 'system',
        'text': '对话已开始',
        'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'taskId': message['taskId'],
        'isFinal': true,
        'isUser': false,
        'userId': 'system',
      };
    } else if (message['type'] == 'task_stopped') {
      return {
        'type': 'system',
        'text': '对话已结束',
        'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'taskId': message['taskId'],
        'isFinal': true,
        'isUser': false,
        'userId': 'system',
      };
    } else if (message['state'] != null) {
      // Handle state messages
      final state = message['state'];
      final stateText = state == 'THINKING' 
          ? '思考中...' 
          : (state == 'SPEAKING' 
              ? '说话中...' 
              : (state == 'FINISHED' ? '已完成' : ''));
      
      return {
        'type': 'state',
        'text': stateText,
        'state': state,
        'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'isThinking': message['isThinking'] ?? false,
        'isTalking': message['isTalking'] ?? false,
        'isFinal': true,
        'isUser': false,
        'userId': 'system',
      };
    } else if (message['text'] != null) {
      // Handle subtitle/text messages
      final isUser = message['userId'] != 'BotName001' && 
                    message['userId'] != 'RobotMan_' &&
                    !message['userId'].toString().contains('bot');
      
      return {
        'type': 'subv',
        'text': message['text'] ?? '',
        'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'isFinal': message['isFinal'] ?? true,
        'isUser': isUser,
        'userId': message['userId'] ?? (isUser ? 'user' : 'bot'),
        'language': message['language'] ?? 'zh',
      };
    }

    // Default unknown format
    return {
      'type': 'unknown',
      'text': jsonEncode(message),
      'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'isFinal': true,
      'isUser': false,
      'userId': 'system',
    };
  }
  
  /// Extract conversation history from message list
  static List<Map<String, dynamic>> extractConversationHistory(
      List<Map<String, dynamic>> messages) {
    final result = <Map<String, dynamic>>[];

    for (final message in messages) {
      // Format message for UI
      final formatted = formatMessageForUI(message);

      // Filter out non-subtitle or empty text messages
      if (formatted['type'] == 'subv' &&
          formatted['text'].toString().isNotEmpty) {
        result.add({
          'userId': formatted['userId'],
          'text': formatted['text'],
          'timestamp': formatted['timestamp'],
          'isFinal': formatted['isFinal'],
          'isUser': formatted['isUser'],
        });
      }
    }

    return result;
  }
  
  /// Parse TLV message
  /// TLV format: | type (4 bytes) | length (4 bytes) | value |
  static Map<String, dynamic>? parseTlvMessage(ByteBuffer buffer) {
    if (buffer == null || buffer.lengthInBytes < 8) {
      debugPrint('【TLV解析】消息无效或长度不足');
      return null;
    }

    try {
      // Read type (first 4 bytes)
      final typeBytes = Uint8List.view(buffer, 0, 4);
      String type = '';
      for (var i = 0; i < 4; i++) {
        type += String.fromCharCode(typeBytes[i]);
      }

      // Read length (next 4 bytes, big-endian)
      final lengthBytes = Uint8List.view(buffer, 4, 4);
      final length = (lengthBytes[0] << 24) |
          (lengthBytes[1] << 16) |
          (lengthBytes[2] << 8) |
          lengthBytes[3];

      // Verify message length
      if (buffer.lengthInBytes < 8 + length) {
        debugPrint(
            '【TLV解析】消息内容长度不足，期望${length}字节，实际${buffer.lengthInBytes - 8}字节');
        return null;
      }

      // Read and decode value
      final valueBytes = Uint8List.view(buffer, 8, length);
      final utf8Decoder = const Utf8Decoder();
      final value = utf8Decoder.convert(valueBytes);

      // Try to parse as JSON
      try {
        final jsonData = jsonDecode(value);
        return {'type': type, 'data': jsonData};
      } catch (e) {
        return {'type': type, 'data': value};
      }
    } catch (e) {
      debugPrint('【TLV解析】解析TLV消息失败: $e');
      return null;
    }
  }

  /// Message type codes
  static const Map<String, int> MESSAGE_TYPE_CODE = {
    'subv': 1, // 字幕消息
    'func': 2, // 函数调用消息
    'ctrl': 3, // 控制消息
  };

  /// AI state codes
  static const Map<String, int> AGENT_STATE_CODE = {
    'UNKNOWN': 0,
    'LISTENING': 1,
    'THINKING': 2,
    'SPEAKING': 3,
    'INTERRUPTED': 4,
    'FINISHED': 5,
  };
} 