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
      final dynamic result = jsonDecode(text);
      if (result is Map<String, dynamic>) {
        return result;
      }
    } catch (e) {
      debugPrint('RtcMessageUtils: 解析JSON出错: $e');
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