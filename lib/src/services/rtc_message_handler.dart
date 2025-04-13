import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';
import 'package:rtc_aigc_plugin/src/utils/rtc_message_utils.dart';
import 'package:rtc_aigc_plugin/src/models/models.dart';

import '../../rtc_aigc_plugin.dart';

/// RTC消息处理器 - 专门处理RTC二进制消息、字幕和函数调用
class RtcMessageHandler {
  /// RTC引擎实例
  dynamic _rtcClient;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 字幕流控制器
  final StreamController<Map<String, dynamic>> _subtitleController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 状态消息流控制器
  final StreamController<Map<String, dynamic>> _stateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 函数调用流控制器
  final StreamController<Map<String, dynamic>> _functionCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 消息历史流控制器
  final StreamController<List<RtcAigcMessage>> _messageHistoryController =
      StreamController<List<RtcAigcMessage>>.broadcast();

  /// 消息历史列表
  final List<RtcAigcMessage> _messageHistory = [];

  /// 字幕流
  Stream<Map<String, dynamic>> get subtitleStream => _subtitleController.stream;

  /// 状态消息流
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  /// 函数调用流
  Stream<Map<String, dynamic>> get functionCallStream =>
      _functionCallController.stream;

  /// 消息历史流
  Stream<List<RtcAigcMessage>> get messageHistoryStream =>
      _messageHistoryController.stream;

  /// 回调属性
  void Function(Map<String, dynamic>)? onSubtitle;
  void Function(Map<String, dynamic>)? onFunctionCall;
  void Function(Map<String, dynamic>)? onState;

  /// 构造函数
  RtcMessageHandler() {
    _isInitialized = true;
    debugPrint('RtcMessageHandler: 初始化完成');
  }

  /// 设置引擎
  void setEngine(dynamic rtcClient) {
    _rtcClient = rtcClient;
    debugPrint('RtcMessageHandler: 设置引擎完成');
  }

  /// 处理二进制消息
  void handleBinaryMessage(String userId, dynamic message) {
    try {
      // 避免为每条消息都输出处理开始日志
      // debugPrint('【消息处理器】开始处理二进制消息，用户ID: $userId');

      if (message == null) {
        debugPrint('【消息处理器】收到null消息，无法处理');
        return;
      }

      // 将消息转换为Uint8List
      final bytes = WebUtils.binaryToUint8List(message);
      if (bytes.isEmpty) {
        debugPrint('【消息处理器】消息转换失败，无法处理');
        return;
      }

      // 检查是否为字幕消息 - 字幕消息以 'subv' 开头
      bool isSubtitle = false;
      String magicString = "";
      if (bytes.length >= 4) {
        final magicBytes = [bytes[0], bytes[1], bytes[2], bytes[3]];
        magicString = String.fromCharCodes(magicBytes);
        isSubtitle = magicString == 'subv';
      }

      // 只为非字幕消息输出处理日志
      if (!isSubtitle) {
        debugPrint('【消息处理器】开始处理二进制消息，用户ID: $userId');
        debugPrint('【消息处理器】消息长度: ${bytes.length} 字节');
        debugPrint('【消息处理器】消息头部标识: $magicString');
      }

      // 尝试多种方式解析消息
      Map<String, dynamic>? parsedData;
      
      // 1. 首先尝试作为TLV消息解析
      final parsedTlvMessage = RtcMessageUtils.parseTlvMessage(bytes);
      if (parsedTlvMessage != null) {
        // 只为非字幕消息或最终字幕输出解析成功日志
        bool isDefiniteSubtitle = false;
        if (isSubtitle && parsedTlvMessage.containsKey('data')) {
          var subtitleData = parsedTlvMessage['data'];
          if (subtitleData is List && subtitleData.isNotEmpty) {
            var firstItem = subtitleData.first;
            if (firstItem is Map && firstItem.containsKey('definite')) {
              isDefiniteSubtitle = firstItem['definite'] == true && firstItem['paragraph'] == true;
            }
          }
        }

        if (!isSubtitle || isDefiniteSubtitle) {
          debugPrint('【消息处理器】TLV消息解析成功，类型: ${parsedTlvMessage["type"]}');
        }
        parsedData = parsedTlvMessage;
      } 
      // 2. 如果TLV解析失败，尝试直接作为字符串处理
      else {
        // 通过预检查判断是否可能是已知格式
        final bool mightBeJson = magicString == "{\"st" || 
                                  magicString == "conv" || 
                                  magicString == "subv" || 
                                  magicString == "func" || 
                                  bytes.indexOf(123) >= 0; // 123是'{'的ASCII
        
        if (mightBeJson) {
          // 只为非字幕消息输出尝试处理日志
          if (!isSubtitle) {
            debugPrint('【消息处理器】尝试作为JSON字符串处理');
          }
          
          final jsonString = WebUtils.binaryToString(message);
          if (jsonString.isNotEmpty) {
            // 只为非字幕消息输出预览日志
            if (!isSubtitle) {
              final int previewLength = jsonString.length > 100 ? 100 : jsonString.length;
              debugPrint('【消息处理器】字符串预览: ${jsonString.substring(0, previewLength)}...');
            }
            
            // 如果字符串包含JSON对象的起始和结束标记，尝试提取
            if (jsonString.contains('{') && jsonString.contains('}')) {
              final int jsonStart = jsonString.indexOf('{');
              final int jsonEnd = jsonString.lastIndexOf('}') + 1;
              if (jsonStart >= 0 && jsonEnd > jsonStart) {
                final String jsonPart = jsonString.substring(jsonStart, jsonEnd);
                try {
                  parsedData = RtcMessageUtils.safeParseJson(jsonPart);
                  if (parsedData != null && !isSubtitle) {
                    debugPrint('【消息处理器】成功提取并解析JSON部分');
                  }
                } catch (e) {
                  // 只为非字幕消息输出错误日志
                  if (!isSubtitle) {
                    debugPrint('【消息处理器】JSON部分提取失败: $e');
                  }
                }
              }
            }
            
            // 如果上面的提取失败，尝试直接解析整个字符串
            if (parsedData == null) {
              parsedData = RtcMessageUtils.safeParseJson(jsonString);
              if (parsedData != null && !isSubtitle) {
                debugPrint('【消息处理器】字符串JSON解析成功');
              }
            }
          }
        }
      }

      // 处理解析结果
      if (parsedData != null) {
        _processTextOrJson(parsedData);
      } else {
        // 最后尝试作为原始字符串尝试查找 status 等字段
        if (!isSubtitle) {
          final String rawString = WebUtils.binaryToString(message);
          if (rawString.contains("status") || rawString.contains("state")) {
            debugPrint('【消息处理器】尝试作为含状态信息的原始字符串处理');
            // 创建一个简单的状态消息
            final Map<String, dynamic> stateMessage = {
              'type': 'conv',
              'status': rawString.contains("THINKING") ? "THINKING" :
                      rawString.contains("SPEAKING") ? "SPEAKING" : 
                      rawString.contains("FINISHED") ? "FINISHED" : 
                      rawString.contains("INTERRUPTED") ? "INTERRUPTED" : "UNKNOWN",
              'timestamp': DateTime.now().millisecondsSinceEpoch
            };
            _processTextOrJson(stateMessage);
          } else {
            debugPrint('【消息处理器】消息无法解析为任何已知格式');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('【消息处理器】处理二进制消息异常: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  /// 处理文本或JSON消息
  void _processTextOrJson(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString().toLowerCase();

      // 只对非字幕消息或最终字幕(definite=true)进行日志记录
      bool isSubtitle = type == 'subv';
      bool isDefiniteSubtitle = false;
      
      if (isSubtitle && data.containsKey('data')) {
        var subtitleData = data['data'];
        if (subtitleData is List && subtitleData.isNotEmpty) {
          var firstItem = subtitleData.first;
          if (firstItem is Map && firstItem.containsKey('definite')) {
            isDefiniteSubtitle = firstItem['definite'] == true && firstItem['paragraph'] == true;
          }
        }
      }

      switch (type) {
        case 'conv':
          _handleConvMessage(data);
          break;
        case 'subv':
          _handleSubtitleMessage(data);
          break;
        case 'func':
          _handleFunctionCallMessage(data);
          break;
        default:
          // 检查是否有state字段，某些消息使用state字段表示类型
          if (data.containsKey('state')) {
            _handleStateMessage(data);
          } else {
            // 只对非字幕消息或最终字幕输出未知类型日志
            if (!isSubtitle || isDefiniteSubtitle) {
              // debugPrint('【消息处理器】未知消息类型: $type，完整数据: $data');
            }
          }
      }
    } catch (e, stackTrace) {
      debugPrint('【消息处理器】处理消息异常: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  /// 处理对话状态消息
  void _handleConvMessage(Map<String, dynamic> data) {
    try {
      debugPrint('【消息处理器】处理对话状态消息: $data');

      final state = data['status']?.toString().toUpperCase();
      if (state != null) {
        // 处理状态更新
        final stateData = {
          'state': state,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        if (onState != null) {
          onState!(stateData);
        }

        // 添加到消息历史
        _addMessage(RtcAigcMessage.status(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          status: state,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } catch (e) {
      debugPrint('【消息处理器】处理对话状态消息异常: $e');
    }
  }

  /// 处理字幕消息
  void _handleSubtitleMessage(Map<String, dynamic> data) {
    try {
      // 检查是否为最终字幕
      bool isDefiniteSubtitle = false;
      String subtitleText = "";
      
      // 解析字幕数据
      if (data.containsKey('data')) {
        var subtitleData = data['data'];
        if (subtitleData is List && subtitleData.isNotEmpty) {
          var firstItem = subtitleData.first;
          if (firstItem is Map) {
            if (firstItem.containsKey('definite')) {
              isDefiniteSubtitle = firstItem['definite'] == true && firstItem['paragraph'] == true;
            }
            if (firstItem.containsKey('text')) {
              subtitleText = firstItem['text'] ?? '';
            }
          }
        }
      }
      
      // 只有最终字幕才输出日志
      if (isDefiniteSubtitle) {
        debugPrint('【消息处理器】处理最终字幕: $subtitleText');
      }

      // 提取字幕内容 - 这部分保持不变，正常处理所有字幕
      final textData = data['text'];
      if (textData != null) {
        final subtitle = {
          'text': textData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        if (onSubtitle != null) {
          onSubtitle!(subtitle);
        }

        // 添加到消息历史
        _addMessage(RtcAigcMessage.text(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: textData,
          isUser: false,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } catch (e) {
      debugPrint('【消息处理器】处理字幕消息异常: $e');
    }
  }

  /// 处理函数调用消息
  void _handleFunctionCallMessage(Map<String, dynamic> data) {
    try {
      debugPrint('【消息处理器】处理函数调用消息');

      // 提取函数名和参数
      final name = data['name'];
      final args = data['arguments'];

      if (name != null) {
        final functionCall = {
          'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'name': name,
          'arguments': args ?? {},
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        if (onFunctionCall != null) {
          onFunctionCall!(functionCall);
        }

        // 添加到消息历史
        _addMessage(RtcAigcMessage.functionCall(
          id: functionCall['id'],
          name: name,
          arguments: args ?? {},
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } catch (e) {
      debugPrint('【消息处理器】处理函数调用消息异常: $e');
    }
  }

  /// 处理状态消息
  void _handleStateMessage(Map<String, dynamic> data) {
    try {
      debugPrint('【消息处理器】处理状态消息: $data');

      if (onState != null) {
        onState!(data);
      }

      // 添加到消息历史
      _addMessage(RtcAigcMessage.status(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        status: data['state'] ?? 'unknown',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      debugPrint('【消息处理器】处理状态消息异常: $e');
    }
  }

  /// 添加消息到历史记录
  void _addMessage(RtcAigcMessage message) {
    _messageHistory.add(message);
    _messageHistoryController.add(_messageHistory);
  }

  /// 发送用户二进制消息
  Future<bool> sendUserBinaryMessage(String userId, dynamic message) async {
    if (_rtcClient == null) {
      debugPrint('RtcMessageHandler: RTC引擎未初始化，无法发送消息');
      return false;
    }

    try {
      debugPrint('【RtcMessageHandler】准备发送二进制消息给用户ID: $userId');

      // 检查消息是否为null
      if (message == null) {
        debugPrint('【RtcMessageHandler】错误: 消息内容为null');
        return false;
      }

      // 如果传入的是字符串，创建正确的TLV消息格式
      dynamic msgToSend;
      if (message is String) {
        debugPrint('【RtcMessageHandler】消息类型: 字符串，内容预览: ${message.length > 50 ? message.substring(0, 50) + "..." : message}');
        
        // 创建命令格式消息
        var commandData = {
          "Command": "ExternalTextToLLM",
          "InterruptMode": 0,
          "Message": message
        };
        
        // 转换为TLV格式
        msgToSend = RtcMessageUtils.createTlvMessage(commandData);
        debugPrint('【RtcMessageHandler】已创建TLV消息, 类型: ctrl');
      } else if (message is Map<String, dynamic>) {
        debugPrint('【RtcMessageHandler】消息类型: Map, 键: ${message.keys.join(", ")}');
        msgToSend = RtcMessageUtils.createTlvMessage(message);
        debugPrint('【RtcMessageHandler】已创建TLV消息');
      } else {
        // 对于已经是二进制数据的消息直接发送
        msgToSend = message;
        debugPrint('【RtcMessageHandler】使用原始消息数据');
      }
      
      // 确保消息转换成功
      if (msgToSend == null) {
        debugPrint('【RtcMessageHandler】错误: 消息转换失败');
        return false;
      }

      // 调用发送接口
      debugPrint('【RtcMessageHandler】调用RTC引擎发送消息...');
      final result = await WebUtils.callMethodAsync(
          _rtcClient, 'sendUserBinaryMessage', [userId, msgToSend]);
      
      // 检查结果
      if (result == 0) {
        debugPrint('【RtcMessageHandler】消息发送成功');
        return true;
      } else {
        debugPrint('【RtcMessageHandler】消息发送失败，错误代码: $result');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('【RtcMessageHandler】发送二进制消息出错: $e');
      debugPrint('【RtcMessageHandler】堆栈信息: $stackTrace');
      return false;
    }
  }

  /// 发送房间二进制消息
  Future<bool> sendRoomBinaryMessage(dynamic message) async {
    if (_rtcClient == null) {
      debugPrint('RtcMessageHandler: RTC引擎未初始化，无法发送消息');
      return false;
    }

    try {
      final result = await WebUtils.callMethodAsync(
          _rtcClient, 'sendRoomBinaryMessage', [message]);
      return result == 0;
    } catch (e) {
      debugPrint('RtcMessageHandler: 发送房间二进制消息出错: $e');
      return false;
    }
  }

  /// 发送字幕消息
  Future<bool> sendSubtitleMessage(String text, {bool isFinal = true}) async {
    try {
      final data =
          RtcMessageUtils.createSubtitleMessage(text, isFinal: isFinal);
      return await sendRoomBinaryMessage(data);
    } catch (e) {
      debugPrint('RtcMessageHandler: 发送字幕消息出错: $e');
      return false;
    }
  }

  /// 发送函数调用结果
  Future<bool> sendFunctionCallResult(
      String name, Map<String, dynamic> result) async {
    try {
      final data = RtcMessageUtils.createFunctionResultMessage(name, result);
      return await sendRoomBinaryMessage(data);
    } catch (e) {
      debugPrint('RtcMessageHandler: 发送函数调用结果出错: $e');
      return false;
    }
  }

  /// 发送状态消息
  Future<bool> sendStateMessage(String state) async {
    try {
      final data = RtcMessageUtils.createStateMessage(state);
      return await sendRoomBinaryMessage(data);
    } catch (e) {
      debugPrint('RtcMessageHandler: 发送状态消息出错: $e');
      return false;
    }
  }

  /// 销毁资源
  void dispose() {
    _subtitleController.close();
    _stateController.close();
    _functionCallController.close();
    _messageHistoryController.close();
    _isInitialized = false;
    debugPrint('RtcMessageHandler: 资源已释放');
  }
}
