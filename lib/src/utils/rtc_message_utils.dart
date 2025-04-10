import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Message type constants matching web implementation
class MessageType {
  static const String BRIEF = 'conv';
  static const String SUBTITLE = 'subv';
  static const String FUNCTION_CALL = 'func';
}

/// Agent state constants matching web implementation
class AgentBrief {
  static const int UNKNOWN = 0;
  static const int LISTENING = 1;
  static const int THINKING = 2;
  static const int SPEAKING = 3;
  static const int INTERRUPTED = 4;
  static const int FINISHED = 5;
}

/// Command type constants
class CommandType {
  static const String INTERRUPT = 'interrupt';
  static const String EXTERNAL_TEXT_TO_SPEECH = 'ExternalTextToSpeech';
  static const String EXTERNAL_TEXT_TO_LLM = 'ExternalTextToLLM';
}

/// Interrupt priority constants
class InterruptPriority {
  static const int NONE = 0;
  static const int HIGH = 1;
  static const int MEDIUM = 2;
  static const int LOW = 3;
}

/// Utility class for handling RTC AIGC messages
class RtcAigcMessageUtils {
  /// Message type codes
  static const Map<String, int> MESSAGE_TYPE_CODE = {
    MessageType.SUBTITLE: 1,
    MessageType.FUNCTION_CALL: 2,
    MessageType.BRIEF: 3,
  };

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
        'type': MessageType.SUBTITLE,
        'text': message['text'] ?? '',
        'timestamp': message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        'isFinal': message['isFinal'] ?? message['definite'] ?? true,
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
      if (formatted['type'] == MessageType.SUBTITLE &&
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
        if (typeBytes[i] == 0) break; // Stop at null terminator
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

      debugPrint('【TLV解析】类型: $type, 长度: $length');
      
      // Try to parse as JSON
      try {
        final jsonData = jsonDecode(value);
        return {'type': type, 'data': jsonData};
      } catch (e) {
        debugPrint('【TLV解析】JSON解析失败，以文本形式返回: $e');
        return {'type': type, 'data': value};
      }
    } catch (e) {
      debugPrint('【TLV解析】解析TLV消息失败: $e');
      return null;
    }
  }

  /// Create TLV data from string content and type
  static ByteBuffer string2tlv(String content, String type) {
    try {
      // Validate type is 4 characters or less
      if (type.length > 4) {
        type = type.substring(0, 4);
      } else if (type.length < 4) {
        // Pad with nulls
        type = type.padRight(4, '\u0000');
      }
      
      // Convert content to UTF-8 bytes
      final contentBytes = Uint8List.fromList(utf8.encode(content));
      final contentLength = contentBytes.length;
      
      // Create type bytes (4 bytes)
      final typeBytes = Uint8List(4);
      for (var i = 0; i < 4; i++) {
        if (i < type.length) {
          typeBytes[i] = type.codeUnitAt(i);
        } else {
          typeBytes[i] = 0; // null padding
        }
      }
      
      // Create length bytes (4 bytes, big-endian)
      final lengthBytes = Uint8List(4);
      lengthBytes[0] = (contentLength >> 24) & 0xFF;
      lengthBytes[1] = (contentLength >> 16) & 0xFF;
      lengthBytes[2] = (contentLength >> 8) & 0xFF;
      lengthBytes[3] = contentLength & 0xFF;
      
      // Combine all parts
      final resultBytes = Uint8List(4 + 4 + contentLength);
      resultBytes.setRange(0, 4, typeBytes);
      resultBytes.setRange(4, 8, lengthBytes);
      resultBytes.setRange(8, 8 + contentLength, contentBytes);
      
      return resultBytes.buffer;
    } catch (e) {
      debugPrint('【TLV创建】创建TLV数据失败: $e');
      throw Exception('Failed to create TLV data: $e');
    }
  }
} 