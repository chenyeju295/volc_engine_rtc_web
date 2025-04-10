/**
 * RTC AIGC 模型类定义
 */
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// 消息类型
enum MessageType {
  /// Text message
  text,

  /// Function call message
  functionCall,

  /// Function return message
  functionReturn,

  /// Status message
  status,

  /// System message
  system,

  /// User message
  user,

  /// AI message
  ai,

  /// Error message
  error,

  /// Unknown message type
  unknown
}

/// Function call status
enum FunctionCallStatus {
  /// Function call is pending
  pending,

  /// Function call is in progress
  inProgress,

  /// Function call is completed
  completed,

  /// Function call has failed
  failed
}

/// AIGC客户端状态
enum AigcClientState {
  /// Initial state
  initial,

  /// Client is initializing
  initializing,

  /// Client is connecting
  connecting,

  /// Client is responding
  responding,

  /// Client is ready
  ready,

  /// Client is joining a room
  joining,

  /// Client has joined a room
  joined,

  /// Client is starting a conversation
  starting,

  /// Client is in conversation
  inConversation,

  /// Client is stopping a conversation
  stopping,

  /// Client is leaving a room
  leaving,

  /// Client has an error
  error,

  /// Client has been disposed
  disposed
}

/// RTC服务状态
enum RtcState {
  /// 初始状态
  initial,

  /// 已初始化但未在房间中
  initialized,

  /// 已加入房间但未在对话中
  inRoom,

  /// 正在对话中
  inConversation,

  /// 等待AI响应中
  waitingResponse,
  
  /// 发生错误
  error,

  /// 已销毁
  disposed
}

// /// RTC连接状态
// enum ConnectionState {
//   /// 已断开连接
//   disconnected,
//
//   /// 正在连接中
//   connecting,
//
//   /// 已连接
//   connected,
//
//   /// 连接失败
//   failed
// }

/// RTC AIGC消息模型
class RtcAigcMessage {
  /// 消息ID
  final String id;

  /// 消息类型
  final MessageType type;

  /// 消息内容
  final String? text;

  /// 消息内容 (与text同义，为兼容性添加)
  final String? content;

  /// 发送者ID
  final String? senderId;

  /// 是否为用户消息
  final bool? isUser;

  /// 是否被中断
  final bool isInterrupted;

  /// 消息时间戳
  final int? timestamp;

  /// Function call details (if type is functionCall)
  final FunctionCall? functionCall;

  /// Function return details (if type is functionReturn)
  final FunctionReturn? functionReturn;

  /// Status message (if type is status)
  final String? status;

  /// 构造函数
  RtcAigcMessage({
    required this.id,
    required this.type,
    this.text,
    this.content,
    this.senderId,
    this.isUser,
    this.isInterrupted = false,
    this.timestamp,
    this.functionCall,
    this.functionReturn,
    this.status,
  });

  /// 用于创建文本消息的工厂方法
  factory RtcAigcMessage.text({
    required String id,
    required String text,
    required bool isUser,
    String? senderId,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.text,
      text: text,
      content: text,
      senderId: senderId,
      isUser: isUser,
      timestamp: timestamp,
    );
  }

  /// 用于创建用户消息的工厂方法
  factory RtcAigcMessage.user({
    required String id,
    required String text,
    String? senderId,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.user,
      text: text,
      content: text,
      senderId: senderId,
      isUser: true,
      timestamp: timestamp,
    );
  }

  /// 用于创建AI消息的工厂方法
  factory RtcAigcMessage.ai({
    required String id,
    required String text,
    String? senderId,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.ai,
      text: text,
      content: text,
      senderId: senderId,
      isUser: false,
      timestamp: timestamp,
    );
  }

  /// 用于创建系统消息的工厂方法
  factory RtcAigcMessage.system({
    required String id,
    required String text,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.system,
      text: text,
      content: text,
      isUser: false,
      timestamp: timestamp,
    );
  }

  /// 用于创建错误消息的工厂方法
  factory RtcAigcMessage.error({
    required String id,
    required String text,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.error,
      text: text,
      content: text,
      isUser: false,
      timestamp: timestamp,
    );
  }

  /// 用于创建功能调用消息的工厂方法
  factory RtcAigcMessage.functionCall({
    required String id,
    required String name,
    required Map<String, dynamic> arguments,
    bool isUser = false,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.functionCall,
      functionCall: FunctionCall(
        name: name,
        arguments: arguments,
      ),
      isUser: isUser,
      timestamp: timestamp,
    );
  }

  /// 用于创建功能返回消息的工厂方法
  factory RtcAigcMessage.functionReturn({
    required String id,
    required String callId,
    required dynamic result,
    bool isUser = false,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.functionReturn,
      functionReturn: FunctionReturn(
        callId: callId,
        result: result,
      ),
      isUser: isUser,
      timestamp: timestamp,
    );
  }

  /// 用于创建状态消息的工厂方法
  factory RtcAigcMessage.status({
    required String id,
    required String status,
    bool isUser = false,
    int? timestamp,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.status,
      status: status,
      isUser: isUser,
      timestamp: timestamp,
    );
  }

  /// 从JSON创建实例
  factory RtcAigcMessage.fromJson(Map<String, dynamic> json) {
    final type = _typeFromString(json['type'] as String? ?? 'unknown');

    switch (type) {
      case MessageType.text:
        return RtcAigcMessage.text(
          id: json['id'] as String,
          text: json['text'] as String,
          isUser: json['isUser'] as bool? ?? false,
          senderId: json['senderId'] as String?,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.user:
        return RtcAigcMessage.user(
          id: json['id'] as String,
          text: json['text'] as String,
          senderId: json['senderId'] as String?,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.ai:
        return RtcAigcMessage.ai(
          id: json['id'] as String,
          text: json['text'] as String,
          senderId: json['senderId'] as String?,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.functionCall:
        final functionCallJson = json['functionCall'] as Map<String, dynamic>?;
        if (functionCallJson == null) {
          throw FormatException('Invalid function call message format');
        }
        return RtcAigcMessage.functionCall(
          id: json['id'] as String,
          name: functionCallJson['name'] as String,
          arguments: functionCallJson['arguments'] as Map<String, dynamic>,
          isUser: json['isUser'] as bool? ?? false,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.functionReturn:
        final functionReturnJson =
            json['functionReturn'] as Map<String, dynamic>?;
        if (functionReturnJson == null) {
          throw FormatException('Invalid function return message format');
        }
        return RtcAigcMessage.functionReturn(
          id: json['id'] as String,
          callId: functionReturnJson['callId'] as String,
          result: functionReturnJson['result'],
          isUser: json['isUser'] as bool? ?? false,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.status:
        return RtcAigcMessage.status(
          id: json['id'] as String,
          status: json['status'] as String,
          isUser: json['isUser'] as bool? ?? false,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.system:
        return RtcAigcMessage.system(
          id: json['id'] as String,
          text: json['text'] as String,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.error:
        return RtcAigcMessage.error(
          id: json['id'] as String,
          text: json['text'] as String,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
      case MessageType.unknown:
      default:
        return RtcAigcMessage(
          id: json['id'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.unknown,
          text: json['text'] as String?,
          content: json['text'] as String?,
          senderId: json['senderId'] as String?,
          isUser: json['isUser'] as bool? ?? false,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : null,
        );
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'id': id,
      'type': _typeToString(type),
      'isUser': isUser,
      'timestamp': timestamp,
    };

    if (text != null) {
      json['text'] = text;
      json['content'] = text;
    }

    if (senderId != null) {
      json['senderId'] = senderId;
    }

    if (isInterrupted) {
      json['isInterrupted'] = isInterrupted;
    }

    if (functionCall != null) {
      json['functionCall'] = functionCall!.toJson();
    }

    if (functionReturn != null) {
      json['functionReturn'] = functionReturn!.toJson();
    }

    if (status != null) {
      json['status'] = status;
    }

    return json;
  }

  /// 复制并修改某些属性
  RtcAigcMessage copyWith({
    String? id,
    MessageType? type,
    String? text,
    String? content,
    String? senderId,
    bool? isUser,
    bool? isInterrupted,
    int? timestamp,
    FunctionCall? functionCall,
    FunctionReturn? functionReturn,
    String? status,
  }) {
    return RtcAigcMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      text: content ?? text ?? this.text,
      content: content ?? text ?? this.content,
      senderId: senderId ?? this.senderId,
      isUser: isUser ?? this.isUser,
      isInterrupted: isInterrupted ?? this.isInterrupted,
      timestamp: timestamp ?? this.timestamp,
      functionCall: functionCall ?? this.functionCall,
      functionReturn: functionReturn ?? this.functionReturn,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'RtcAigcMessage{id: $id, type: $type, text: $text, content: $content, isUser: $isUser, senderId: $senderId, isInterrupted: $isInterrupted, timestamp: $timestamp, functionCall: $functionCall, functionReturn: $functionReturn, status: $status}';
  }

  /// Convert message type to string
  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.user:
        return 'user';
      case MessageType.ai:
        return 'ai';
      case MessageType.functionCall:
        return 'functionCall';
      case MessageType.functionReturn:
        return 'functionReturn';
      case MessageType.status:
        return 'status';
      case MessageType.system:
        return 'system';
      case MessageType.error:
        return 'error';
      case MessageType.unknown:
      default:
        return 'unknown';
    }
  }

  /// Convert string to message type
  static MessageType _typeFromString(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'user':
        return MessageType.user;
      case 'ai':
        return MessageType.ai;
      case 'functionCall':
        return MessageType.functionCall;
      case 'functionReturn':
        return MessageType.functionReturn;
      case 'status':
        return MessageType.status;
      case 'system':
        return MessageType.system;
      case 'error':
        return MessageType.error;
      default:
        return MessageType.unknown;
    }
  }
}

/// Function call details
class FunctionCall {
  /// Function name
  final String name;

  /// Function arguments
  final Map<String, dynamic> arguments;

  /// Function call status
  final FunctionCallStatus status;

  /// Create a new function call
  FunctionCall({
    required this.name,
    required this.arguments,
    this.status = FunctionCallStatus.pending,
  });

  /// Create a function call from a JSON map
  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>,
      status: _statusFromString(json['status'] as String? ?? 'pending'),
    );
  }

  /// Convert function call to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arguments': arguments,
      'status': _statusToString(status),
    };
  }

  /// Create a copy of this function call with modified properties
  FunctionCall copyWith({
    String? name,
    Map<String, dynamic>? arguments,
    FunctionCallStatus? status,
  }) {
    return FunctionCall(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      status: status ?? this.status,
    );
  }

  /// Convert function call status to string
  static String _statusToString(FunctionCallStatus status) {
    switch (status) {
      case FunctionCallStatus.pending:
        return 'pending';
      case FunctionCallStatus.inProgress:
        return 'inProgress';
      case FunctionCallStatus.completed:
        return 'completed';
      case FunctionCallStatus.failed:
        return 'failed';
      default:
        return 'pending';
    }
  }

  /// Convert string to function call status
  static FunctionCallStatus _statusFromString(String status) {
    switch (status) {
      case 'pending':
        return FunctionCallStatus.pending;
      case 'inProgress':
        return FunctionCallStatus.inProgress;
      case 'completed':
        return FunctionCallStatus.completed;
      case 'failed':
        return FunctionCallStatus.failed;
      default:
        return FunctionCallStatus.pending;
    }
  }
}

/// Function return details
class FunctionReturn {
  /// ID of the function call this return is for
  final String callId;

  /// Function result
  final dynamic result;

  /// Create a new function return
  FunctionReturn({
    required this.callId,
    required this.result,
  });

  /// Create a function return from a JSON map
  factory FunctionReturn.fromJson(Map<String, dynamic> json) {
    return FunctionReturn(
      callId: json['callId'] as String,
      result: json['result'],
    );
  }

  /// Convert function return to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'result': result,
    };
  }

  /// Create a copy of this function return with modified properties
  FunctionReturn copyWith({
    String? callId,
    dynamic result,
  }) {
    return FunctionReturn(
      callId: callId ?? this.callId,
      result: result ?? this.result,
    );
  }
}

/// 设备信息
class DeviceInfo {
  /// 设备ID
  final String deviceId;

  /// 设备名称
  final String label;

  /// 构造函数
  DeviceInfo({required this.deviceId, required this.label});

  /// 从JSON创建实例
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      label: json['label'] as String,
    );
  }

  /// 转换为JSON
  Map<String, String> toJson() {
    return {
      'deviceId': deviceId,
      'label': label,
    };
  }
}

/// 设备状态变更事件
class DeviceStateEvent {
  /// 设备是否可用
  final bool isAvailable;

  /// 设备类型
  final String deviceType;

  /// 构造函数
  DeviceStateEvent({required this.isAvailable, required this.deviceType});
}

/// 音频状态变更事件
class AudioStatusEvent {
  /// 是否正在播放
  final bool isPlaying;

  /// 是否正在采集
  final bool isCapturing;

  /// 构造函数
  AudioStatusEvent({required this.isPlaying, required this.isCapturing});
}
