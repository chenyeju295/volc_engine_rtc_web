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
  /// 魔术数字常量 - 各种消息类型的头部标识
  static const int MAGIC_NUMBER_SUBV = 0x73756276; // 'subv'
  static const int MAGIC_NUMBER_CONV = 0x636F6E76; // 'conv'
  static const int MAGIC_NUMBER_FUNC = 0x66756E63; // 'func'
  
  /// 消息类型常量
  static const String TYPE_SUBTITLE = 'subtitle';
  static const String TYPE_STATE = 'state';
  static const String TYPE_FUNCTION_CALL = 'function_call';
  static const String TYPE_FUNCTION_RESULT = 'function_result';
  
  /// 解析TLV格式的消息
  /// 
  /// 格式: 
  /// - 4字节魔术数字 'subv', 'conv', 或 'func'
  /// - 4字节内容长度
  /// - N字节JSON内容
  static Map<String, dynamic>? parseTlvMessage(Uint8List bytes) {
    try {
      // 检查长度
      if (bytes.length < 8) {
        debugPrint('RtcMessageUtils: TLV消息太短，不到8字节');
        return null;
      }
      
      // 记录前几个字节用于调试
      final magicBytes = [bytes[0], bytes[1], bytes[2], bytes[3]];
      final magicString = String.fromCharCodes(magicBytes);
      
      // 检查魔术数字
      final int magic = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      bool validMagic = false;
      bool isSubtitle = false;
      
      if (magic == MAGIC_NUMBER_SUBV) {
        validMagic = true;
        isSubtitle = true;
        // 只有在非字幕消息时才输出类型日志
      } else if (magic == MAGIC_NUMBER_CONV) {
        validMagic = true;
        debugPrint('RtcMessageUtils: 检测到对话状态消息 (conv)');
      } else if (magic == MAGIC_NUMBER_FUNC) {
        validMagic = true;
        debugPrint('RtcMessageUtils: 检测到函数调用消息 (func)');
      }
      
      if (!validMagic) {
        debugPrint('RtcMessageUtils: 无效的魔术数字: 0x${magic.toRadixString(16)}');
        return null;
      }
      
      // 获取内容长度
      final int length = (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
      
      // 只在非字幕消息时输出长度日志
      if (!isSubtitle) {
        debugPrint('RtcMessageUtils: 消息头部标识: $magicString');
        debugPrint('RtcMessageUtils: 内容长度: $length');
      }
      
      if (length <= 0 || length > 100000) {  // 设置一个合理的最大值
        debugPrint('RtcMessageUtils: 非法内容长度: $length');
        return null;
      }
      
      if (bytes.length - 8 < length) {
        // 只在严重不匹配或非字幕消息时输出警告
        if (!isSubtitle || (bytes.length - 8 < length * 0.5)) {
          debugPrint('RtcMessageUtils: TLV长度不匹配，标记长度:$length，实际可用:${bytes.length - 8}');
        }
        
        // 如果只是轻微不匹配，尝试使用可用的数据
        if (bytes.length - 8 > 5 && bytes.length - 8 >= length * 0.8) {
          // 减少日志输出
        } else {
          return null;
        }
      }
      
      // 计算实际可用内容长度
      final int actualLength = bytes.length - 8 < length ? bytes.length - 8 : length;
      
      // 提取内容
      try {
        final String content = utf8.decode(bytes.sublist(8, 8 + actualLength), allowMalformed: true);
        
        // 只在非字幕消息时输出内容解码日志
        if (!isSubtitle) {
          debugPrint('RtcMessageUtils: 成功解码TLV内容: ${content.length} 字符');
        }
        
        // 尝试解析JSON内容
        final result = safeParseJson(content);
        
        // 检查是否为最终字幕
        if (isSubtitle && result != null) {
          bool isDefiniteSubtitle = false;
          if (result.containsKey('data')) {
            var subtitleData = result['data'];
            if (subtitleData is List && subtitleData.isNotEmpty) {
              var firstItem = subtitleData.first;
              if (firstItem is Map && firstItem.containsKey('definite')) {
                isDefiniteSubtitle = firstItem['definite'] == true && firstItem['paragraph'] == true;
              }
            }
          }
          
          // 只有最终字幕才输出日志
          if (isDefiniteSubtitle) {
            debugPrint('RtcMessageUtils: 检测到最终字幕消息 (subv)');
          }
        }
        
        return result;
      } catch (decodeError) {
        debugPrint('RtcMessageUtils: UTF-8解码失败: $decodeError，尝试latin1');
        // 尝试使用latin1编码
        try {
          final String content = latin1.decode(bytes.sublist(8, 8 + actualLength));
          return safeParseJson(content);
        } catch (latin1Error) {
          debugPrint('RtcMessageUtils: latin1解码也失败: $latin1Error');
          return null;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('RtcMessageUtils: 解析TLV消息出错: $e');
      debugPrint('堆栈: $stackTrace');
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
      result[0] = (MAGIC_NUMBER_SUBV >> 24) & 0xFF;
      result[1] = (MAGIC_NUMBER_SUBV >> 16) & 0xFF;
      result[2] = (MAGIC_NUMBER_SUBV >> 8) & 0xFF;
      result[3] = MAGIC_NUMBER_SUBV & 0xFF;
      
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

/// 音频设备测试工具类
/// 提供音频设备测试相关的方法
class RtcDeviceTestUtils {
  /// 启动音频播放设备测试
  /// 
  /// 测试启动后，循环播放指定的音频文件，同时会触发音量回调
  /// 
  /// @param rtcEngine RTC引擎实例
  /// @param filePath 指定播放设备检测的音频文件网络地址。包括格式 wav 和 mp3
  /// @param indicationInterval 音量回调的时间间隔，单位为毫秒，推荐设置200毫秒以上
  /// @return 测试结果 Future
  static Future<void> startAudioPlaybackDeviceTest(
      dynamic rtcEngine, 
      String filePath, 
      int indicationInterval) async {
    try {
      if (rtcEngine == null) {
        throw Exception('RTC引擎未初始化');
      }
      
      debugPrint('开始音频播放设备测试，文件: $filePath, 间隔: $indicationInterval ms');
      
      // 调用SDK方法
      final result = js_util.callMethod(
          rtcEngine, 
          'startAudioPlaybackDeviceTest', 
          [filePath, indicationInterval]);
      
      // 处理返回的Promise
      return js_util.promiseToFuture(result);
    } catch (e) {
      debugPrint('启动音频播放设备测试失败: $e');
      throw Exception('启动音频播放设备测试失败: $e');
    }
  }
  
  /// 停止音频播放设备测试
  /// 
  /// @param rtcEngine RTC引擎实例
  static void stopAudioPlaybackDeviceTest(dynamic rtcEngine) {
    try {
      if (rtcEngine == null) {
        throw Exception('RTC引擎未初始化');
      }
      
      debugPrint('停止音频播放设备测试');
      
      // 调用SDK方法
      js_util.callMethod(rtcEngine, 'stopAudioPlaybackDeviceTest', []);
    } catch (e) {
      debugPrint('停止音频播放设备测试失败: $e');
      throw Exception('停止音频播放设备测试失败: $e');
    }
  }
  
  /// 开始音频采集设备和播放设备测试
  /// 
  /// 测试开始后，音频设备开始采集本地声音，30秒后自动停止采集并播放
  /// 
  /// @param rtcEngine RTC引擎实例
  /// @param indicationInterval 音量回调的时间间隔，单位为毫秒，推荐设置200毫秒以上
  /// @param onAutoplayFailed 由于浏览器自动播放策略影响，导致录制音频播放失败时回调
  /// @return 测试结果 Future
  static Future<void> startAudioDeviceRecordTest(
      dynamic rtcEngine, 
      int indicationInterval,
      [Function? onAutoplayFailed]) async {
    try {
      if (rtcEngine == null) {
        throw Exception('RTC引擎未初始化');
      }
      
      debugPrint('开始音频设备录制测试，间隔: $indicationInterval ms');
      
      // 处理回调函数
      dynamic wrappedCallback;
      if (onAutoplayFailed != null) {
        wrappedCallback = js_util.allowInterop((resume) {
          // 包装resume函数为Future
          final Future<dynamic> Function() wrappedResume = () async {
            try {
              final jsResult = resume();
              return js_util.promiseToFuture(jsResult);
            } catch (e) {
              debugPrint('恢复播放失败: $e');
              return null;
            }
          };
          
          // 调用回调
          onAutoplayFailed(wrappedResume);
        });
      }
      
      // 调用SDK方法
      List<dynamic> args = [indicationInterval];
      if (wrappedCallback != null) {
        args.add(wrappedCallback);
      }
      
      final result = js_util.callMethod(rtcEngine, 'startAudioDeviceRecordTest', args);
      
      // 处理返回的Promise
      return js_util.promiseToFuture(result);
    } catch (e) {
      debugPrint('开始音频设备录制测试失败: $e');
      throw Exception('开始音频设备录制测试失败: $e');
    }
  }
  
  /// 停止采集本地音频，并开始播放采集到的声音
  /// 
  /// 在startAudioDeviceRecordTest调用后30秒内调用，可以提前结束录制并开始播放
  /// 
  /// @param rtcEngine RTC引擎实例
  static void stopAudioDeviceRecordAndPlayTest(dynamic rtcEngine) {
    try {
      if (rtcEngine == null) {
        throw Exception('RTC引擎未初始化');
      }
      
      debugPrint('停止录制并开始播放测试音频');
      
      // 调用SDK方法
      js_util.callMethod(rtcEngine, 'stopAudioDeviceRecordAndPlayTest', []);
    } catch (e) {
      debugPrint('停止录制并播放测试失败: $e');
      throw Exception('停止录制并播放测试失败: $e');
    }
  }
  
  /// 停止音频设备播放测试
  /// 
  /// @param rtcEngine RTC引擎实例
  static void stopAudioDevicePlayTest(dynamic rtcEngine) {
    try {
      if (rtcEngine == null) {
        throw Exception('RTC引擎未初始化');
      }
      
      debugPrint('停止音频设备播放测试');
      
      // 调用SDK方法
      js_util.callMethod(rtcEngine, 'stopAudioDevicePlayTest', []);
    } catch (e) {
      debugPrint('停止音频设备播放测试失败: $e');
      throw Exception('停止音频设备播放测试失败: $e');
    }
  }
} 