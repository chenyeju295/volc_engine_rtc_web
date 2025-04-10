import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'package:rtc_aigc_plugin/src/utils/web_utils.dart';
import 'package:rtc_aigc_plugin/src/utils/rtc_message_utils.dart';

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
  final StreamController<Map<String, dynamic>> _messageHistoryController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 字幕流
  Stream<Map<String, dynamic>> get subtitleStream => _subtitleController.stream;

  /// 状态消息流
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  /// 函数调用流
  Stream<Map<String, dynamic>> get functionCallStream =>
      _functionCallController.stream;

  /// 消息历史流
  Stream<Map<String, dynamic>> get messageHistoryStream =>
      _messageHistoryController.stream;

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
    if (message == null) {
      debugPrint('RtcMessageHandler: 消息为空');
      return;
    }

    try {
      // 转换为Uint8List
      final Uint8List? bytes = _toUint8List(message);
      if (bytes == null) {
        debugPrint('RtcMessageHandler: 无法转换消息为Uint8List');

        // 尝试直接作为字符串处理
        final String messageStr = WebUtils.binaryToString(message);
        if (messageStr.isNotEmpty) {
          _processTextOrJson(userId, messageStr);
        }
        return;
      }

      // 尝试解析TLV格式
      final Map<String, dynamic>? tlvData =
          RtcMessageUtils.parseTlvMessage(bytes);
      if (tlvData != null) {
        _processJsonMessage(userId, tlvData);
        return;
      }

      // 如果不是TLV格式，尝试直接转换为字符串
      final String messageStr = WebUtils.binaryToString(message);
      if (messageStr.isNotEmpty) {
        _processTextOrJson(userId, messageStr);
      } else {
        debugPrint('RtcMessageHandler: 无法解析消息内容');
      }
    } catch (e) {
      debugPrint('RtcMessageHandler: 处理二进制消息出错: $e');
    }
  }

  /// 处理文本或JSON消息
  void _processTextOrJson(String userId, String text) {
    if (text.isEmpty) return;

    // 尝试解析为JSON
    try {
      final Map<String, dynamic>? jsonData =
          RtcMessageUtils.safeParseJson(text);
      if (jsonData != null) {
        _processJsonMessage(userId, jsonData);
      } else {
        _processTextMessage(userId, text);
      }
    } catch (e) {
      _processTextMessage(userId, text);
    }
  }

  /// 转换为Uint8List
  Uint8List? _toUint8List(dynamic data) {
    try {
      if (data is Uint8List) {
        return data;
      }

      // 如果是ArrayBuffer或类似对象
      if (js_util.hasProperty(data, 'byteLength')) {
        // 使用Uint8Array视图
        final uint8Array = js_util.callConstructor(
            js_util.getProperty(js_util.globalThis, 'Uint8Array'), [data]);

        // 转换为Dart的Uint8List
        final int length = js_util.getProperty(uint8Array, 'length');
        final Uint8List result = Uint8List(length);

        for (int i = 0; i < length; i++) {
          result[i] = js_util.getProperty(uint8Array, i);
        }

        return result;
      }
    } catch (e) {
      debugPrint('RtcMessageHandler: 转换Uint8List出错: $e');
    }

    return null;
  }

  /// 处理JSON消息
  void _processJsonMessage(String userId, Map<String, dynamic> data) {
    try {
      // 检查消息类型
      if (data.containsKey('type')) {
        final String type = data['type'];

        // 处理字幕消息
        if (type == RtcMessageUtils.TYPE_SUBTITLE || type == 'subv') {
          if (data.containsKey('data') && data['data'] is List) {
            // 处理火山引擎字幕格式
            final List<dynamic> subtitles = data['data'];
            for (final item in subtitles) {
              if (item is Map && item.containsKey('text')) {
                _processSubtitleMessage(userId, {
                  'type': RtcMessageUtils.TYPE_SUBTITLE,
                  'text': item['text'],
                  'isFinal': item['definite'] ?? false,
                  'language': item['language'] ?? 'zh'
                });
              }
            }
          }
          // _processSubtitleMessage(userId, data["data"]);
        }

        // 处理状态消息
        else if (type == RtcMessageUtils.TYPE_STATE) {
          _processStateMessage(userId, data);
        }

        // 处理函数调用消息
        else if (type == RtcMessageUtils.TYPE_FUNCTION_CALL) {
          _processFunctionCallMessage(userId, data);
        }

        // 处理其他类型消息
        else {
          debugPrint('RtcMessageHandler: 未知消息类型: $type');
          _messageHistoryController.add({
            'type': type,
            'data': data,
            'userId': userId,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        }
      } else {
        // 检查是否可能是字幕（没有type但有text）
        if (data.containsKey('text')) {
          _processSubtitleMessage(userId, {
            ...data,
            'type': RtcMessageUtils.TYPE_SUBTITLE,
            'isFinal': data['isFinal'] ?? true
          });
        }
        // 检查是否有data数组，可能是火山引擎字幕格式
        else if (data.containsKey('data') && data['data'] is List) {
          // 处理火山引擎字幕格式
          final List<dynamic> subtitles = data['data'];
          for (final item in subtitles) {
            if (item is Map && item.containsKey('text')) {
              _processSubtitleMessage(userId, {
                'type': RtcMessageUtils.TYPE_SUBTITLE,
                'text': item['text'],
                'isFinal': item['definite'] ?? false,
                'language': item['language'] ?? 'zh'
              });
            }
          }
        }
        // 检查是否可能是状态消息
        else if (data.containsKey('state')) {
          _processStateMessage(userId, {
            'type': RtcMessageUtils.TYPE_STATE,
            'state': data['state'],
            ...data
          });
        } else {
          debugPrint('RtcMessageHandler: 消息没有type字段: $data');
          _messageHistoryController.add({
            'type': 'unknown',
            'data': data,
            'userId': userId,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
        }
      }
    } catch (e) {
      debugPrint('RtcMessageHandler: 处理JSON消息出错: $e');
    }
  }

  /// 处理字幕消息
  void _processSubtitleMessage(String userId, Map<String, dynamic> data) {
    try {
      final String text = data['text'] ?? '';
      if (text.isEmpty) return;

      final bool isFinal = data['isFinal'] ?? data['definite'] ?? true;
      final String language = data['language'] ?? 'zh';

      final Map<String, dynamic> subtitleData = {
        'userId': userId,
        'text': text,
        'isFinal': isFinal,
        'language': language,
        'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
      };

      _subtitleController.add(subtitleData);

      // 只有在最终版本时才添加到消息历史
      if (isFinal) {
        _messageHistoryController
            .add({'type': RtcMessageUtils.TYPE_SUBTITLE, ...subtitleData});

        debugPrint('RtcMessageHandler: 处理字幕: $text (最终: $isFinal)');
      }
    } catch (e) {
      debugPrint('RtcMessageHandler: 处理字幕消息出错: $e');
    }
  }

  /// 处理状态消息
  void _processStateMessage(String userId, Map<String, dynamic> data) {
    try {
      final String state = data['state'] ?? '';
      if (state.isEmpty) return;

      final Map<String, dynamic> stateData = {
        'userId': userId,
        'state': state,
        'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
      };

      _stateController.add(stateData);
      _messageHistoryController
          .add({'type': RtcMessageUtils.TYPE_STATE, ...stateData});

      debugPrint('RtcMessageHandler: 处理状态: $state');
    } catch (e) {
      debugPrint('RtcMessageHandler: 处理状态消息出错: $e');
    }
  }

  /// 处理函数调用消息
  void _processFunctionCallMessage(String userId, Map<String, dynamic> data) {
    try {
      final String name = data['name'] ?? '';
      if (name.isEmpty) return;

      final Map<String, dynamic> args = data['arguments'] ?? {};

      final Map<String, dynamic> functionCallData = {
        'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': userId,
        'name': name,
        'arguments': args,
        'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
      };

      _functionCallController.add(functionCallData);
      _messageHistoryController.add(
          {'type': RtcMessageUtils.TYPE_FUNCTION_CALL, ...functionCallData});

      debugPrint('RtcMessageHandler: 处理函数调用: $name');
    } catch (e) {
      debugPrint('RtcMessageHandler: 处理函数调用消息出错: $e');
    }
  }

  /// 处理纯文本消息
  void _processTextMessage(String userId, String text) {
    if (text.isEmpty) return;

    try {
      // 假设纯文本是字幕
      final Map<String, dynamic> subtitleData = {
        'userId': userId,
        'text': text,
        'isFinal': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      };

      _subtitleController.add(subtitleData);
      _messageHistoryController
          .add({'type': RtcMessageUtils.TYPE_SUBTITLE, ...subtitleData});

      debugPrint('RtcMessageHandler: 处理纯文本字幕: $text');
    } catch (e) {
      debugPrint('RtcMessageHandler: 处理纯文本消息出错: $e');
    }
  }

  /// 发送用户二进制消息
  Future<bool> sendUserBinaryMessage(String userId, dynamic message) async {
    if (_rtcClient == null) {
      debugPrint('RtcMessageHandler: RTC引擎未初始化，无法发送消息');
      return false;
    }

    try {
      final result = await WebUtils.callMethodAsync(
          _rtcClient, 'sendUserBinaryMessage', [userId, message]);
      return result == 0;
    } catch (e) {
      debugPrint('RtcMessageHandler: 发送二进制消息出错: $e');
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
