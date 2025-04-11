import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Message type constants matching web implementation
class RtcMessageType {
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

/// RTC消息工具类 - 处理TLV格式的消息和其他消息处理功能
class RtcMessageUtils {
  /// 魔术数字 - 'subv'
  static const int MAGIC_NUMBER = 0x73756276;
  
  /// 消息类型常量
  static const String TYPE_SUBTITLE = 'subtitle';
  static const String TYPE_STATE = 'state';
  static const String TYPE_FUNCTION_CALL = 'function_call';
  static const String TYPE_FUNCTION_RESULT = 'function_result';
  
  /// 解析TLV格式的消息
  /// 
  /// 格式: 
  /// - 4字节魔术数字 'subv'
  /// - 4字节内容长度
  /// - N字节JSON内容
  static Map<String, dynamic>? parseTlvMessage(Uint8List bytes) {
    try {
      // 检查长度
      if (bytes.length < 8) {
        return null;
      }
      
      // 检查魔术数字 "subv"
      final int magic = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      if (magic != MAGIC_NUMBER) {
        return null;
      }
      
      // 获取内容长度
      final int length = (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
      if (bytes.length - 8 < length) {
        debugPrint('RtcMessageUtils: TLV长度不匹配');
        return null;
      }
      
      // 提取内容
      final String content = utf8.decode(bytes.sublist(8, 8 + length));
      
      // 尝试解析JSON内容
      return safeParseJson(content);
    } catch (e) {
      debugPrint('RtcMessageUtils: 解析TLV消息出错: $e');
      return null;
    }
  }
  
  /// 创建TLV格式的消息
  static dynamic createTlvMessage(Map<String, dynamic> data) {
    try {
      // 转换为JSON字符串
      final String jsonStr = jsonEncode(data);
      
      // 获取UTF8编码的字节
      final Uint8List contentBytes = utf8.encode(jsonStr);
      final int contentLength = contentBytes.length;
      
      // 创建结果缓冲区 (8字节头部 + 内容长度)
      final Uint8List result = Uint8List(8 + contentLength);
      
      // 写入魔术数字 'subv'
      result[0] = (MAGIC_NUMBER >> 24) & 0xFF;
      result[1] = (MAGIC_NUMBER >> 16) & 0xFF;
      result[2] = (MAGIC_NUMBER >> 8) & 0xFF;
      result[3] = MAGIC_NUMBER & 0xFF;
      
      // 写入内容长度
      result[4] = (contentLength >> 24) & 0xFF;
      result[5] = (contentLength >> 16) & 0xFF;
      result[6] = (contentLength >> 8) & 0xFF;
      result[7] = contentLength & 0xFF;
      
      // 写入内容
      for (int i = 0; i < contentLength; i++) {
        result[8 + i] = contentBytes[i];
      }
      
      // 转换为ArrayBuffer (Web平台)
      return _uint8ListToArrayBuffer(result);
    } catch (e) {
      debugPrint('RtcMessageUtils: 创建TLV消息出错: $e');
      return null;
    }
  }
  
  /// 创建字幕消息
  static dynamic createSubtitleMessage(String text, {bool isFinal = true}) {
    final Map<String, dynamic> data = {
      'type': TYPE_SUBTITLE,
      'text': text,
      'isFinal': isFinal,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    
    return createTlvMessage(data);
  }
  
  /// 创建状态消息
  static dynamic createStateMessage(String state) {
    final Map<String, dynamic> data = {
      'type': TYPE_STATE,
      'state': state,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    
    return createTlvMessage(data);
  }
  
  /// 创建函数调用消息
  static dynamic createFunctionCallMessage(String name, Map<String, dynamic> args) {
    final Map<String, dynamic> data = {
      'type': TYPE_FUNCTION_CALL,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'arguments': args,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    
    return createTlvMessage(data);
  }
  
  /// 创建函数调用结果消息
  static dynamic createFunctionResultMessage(String name, Map<String, dynamic> result) {
    final Map<String, dynamic> data = {
      'type': TYPE_FUNCTION_RESULT,
      'name': name,
      'result': result,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    
    return createTlvMessage(data);
  }
  
  /// 安全解析JSON
  static Map<String, dynamic>? safeParseJson(String text) {
    if (text.isEmpty) return null;
    
    try {
      // 检查文本是否以'conv{'开头 - 这是一种常见的错误格式
      if (text.startsWith('conv') && !text.startsWith('conv"') && !text.startsWith('conv:')) {
        // 尝试修复格式，将conv{替换为{"type":"conv",
        String fixedText = text.replaceFirst('conv{', '{"type":"conv",');
        try {
          final dynamic result = jsonDecode(fixedText);
          if (result is Map<String, dynamic>) {
            debugPrint('RtcMessageUtils: 成功修复并解析了conv格式的JSON消息');
            return result;
          }
        } catch (innerError) {
          // 修复失败，尝试从conv之后的部分解析
          if (text.contains('{')) {
            String jsonPart = text.substring(text.indexOf('{'));
            try {
              final dynamic result = jsonDecode(jsonPart);
              if (result is Map<String, dynamic>) {
                debugPrint('RtcMessageUtils: 成功提取并解析了JSON部分');
                // 将消息类型添加到返回的Map中
                if (result is Map<String, dynamic>) {
                  result['type'] = 'conv';
                  return result;
                }
              }
            } catch (e) {
              // 继续使用原始解析逻辑
            }
          }
        }
      }
      
      // 标准解析尝试
      final dynamic result = jsonDecode(text);
      if (result is Map<String, dynamic>) {
        return result;
      } else if (result is List) {
        // 如果是数组，尝试将其包装在一个对象中
        return {'data': result};
      } else {
        debugPrint('RtcMessageUtils: JSON解析结果不是Map或List: ${result.runtimeType}');
      }
    } catch (e) {
      debugPrint('RtcMessageUtils: 解析JSON出错: $e');
      
      // 尝试检测并修复常见JSON格式错误
      if (text.contains('{') && text.contains('}')) {
        try {
          // 尝试从第一个'{'到最后一个'}'提取JSON
          int start = text.indexOf('{');
          int end = text.lastIndexOf('}') + 1;
          
          if (start >= 0 && end > start) {
            String possibleJson = text.substring(start, end);
            try {
              final dynamic extractedResult = jsonDecode(possibleJson);
              if (extractedResult is Map<String, dynamic>) {
                debugPrint('RtcMessageUtils: 成功从部分文本中提取JSON');
                return extractedResult;
              }
            } catch (extractError) {
              // 提取失败，继续
            }
          }
        } catch (fixError) {
          // 修复失败，继续
        }
      }
      
      // 检查是否包含不可见字符或非UTF8字符
      if (text.contains('\u{FFFD}')) {
        debugPrint('RtcMessageUtils: 文本包含替换字符(U+FFFD)，可能是编码问题');
      }
    }
    
    return null;
  }
  
  /// Uint8List转ArrayBuffer (Web平台)
  static dynamic _uint8ListToArrayBuffer(Uint8List bytes) {
    try {
      // 创建ArrayBuffer
      final buffer = js_util.callConstructor(
          js_util.getProperty(js_util.globalThis, 'ArrayBuffer'), [bytes.length]);
      
      // 创建Uint8Array视图
      final uint8Array = js_util.callConstructor(
          js_util.getProperty(js_util.globalThis, 'Uint8Array'), [buffer]);
      
      // 复制数据
      for (int i = 0; i < bytes.length; i++) {
        js_util.setProperty(uint8Array, i, bytes[i]);
      }
      
      return buffer;
    } catch (e) {
      debugPrint('RtcMessageUtils: 转换Uint8List到ArrayBuffer出错: $e');
      
      // 如果转换失败，尝试使用TextEncoder
      try {
        final encoder = js_util.callConstructor(
            js_util.getProperty(js_util.globalThis, 'TextEncoder'), []);
        
        return js_util.callMethod(encoder, 'encode', [utf8.decode(bytes)]);
      } catch (e2) {
        debugPrint('RtcMessageUtils: 备用转换也失败: $e2');
        return null;
      }
    }
  }
} 