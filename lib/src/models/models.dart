/**
 * RTC AIGC 模型类定义
 */

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

/// RTC连接状态
enum RtcConnectionState {
  /// 已断开连接
  disconnected,

  /// 正在连接中
  connecting,

  /// 已连接
  connected,

  /// 连接失败
  failed,

  /// 未知状态
  unknown
}

/// RTC AIGC消息模型
class RtcAigcMessage {
  /// 消息ID
  final String id;

  /// 消息类型
  final MessageType type;

  /// 消息内容
  final String text;

  /// 发送者ID
  final String? senderId;

  /// 是否为用户消息
  final bool isUser;

  /// 是否被中断
  final bool isInterrupted;

  /// 消息时间戳
  int? timestamp = DateTime.now().millisecondsSinceEpoch;

  /// 函数调用名称 (如果是函数调用)
  final String? functionName;

  /// 函数调用参数 (如果是函数调用)
  final Map<String, dynamic>? functionArguments;

  /// 状态信息 (如果是状态消息)
  final String? status;

  /// 对于字幕，是否是最终字幕
  final bool isFinal;

  /// 构造函数
  RtcAigcMessage({
    required this.id,
    required this.type,
    this.text = '',
    this.senderId,
    this.isUser = false,
    this.isInterrupted = false,
    this.timestamp,
    this.functionName,
    this.functionArguments,
    this.status,
    this.isFinal = false,
  });

  /// 用于创建文本消息的工厂方法
  factory RtcAigcMessage.text({
    required String id,
    required String text,
    required bool isUser,
    int? timestamp,
    String? senderId,
    bool isInterrupted = false,
    bool isFinal = false,
  }) {
    return RtcAigcMessage(
      id: id,
      type: isUser ? MessageType.user : MessageType.ai,
      senderId: senderId,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      text: text,
      isInterrupted: isInterrupted,
      isFinal: isFinal,
      isUser: isUser,
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
      senderId: senderId,
      isUser: true,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isInterrupted: false,
      isFinal: false,
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
      senderId: senderId,
      isUser: false,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isInterrupted: false,
      isFinal: false,
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
      senderId: null,
      isUser: false,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isInterrupted: false,
      isFinal: false,
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
      senderId: null,
      isUser: false,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isInterrupted: false,
      isFinal: false,
    );
  }

  /// 用于创建功能调用消息的工厂方法
  factory RtcAigcMessage.functionCall({
    required String id,
    required String name,
    required Map<String, dynamic> arguments,
    required int timestamp,
    String? senderId,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.functionCall,
      text: '函数调用: $name',
      senderId: senderId,
      isUser: false,
      timestamp: timestamp,
      functionName: name,
      functionArguments: arguments,
      isInterrupted: false,
      isFinal: false,
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
      text: '函数返回: $callId',
      senderId: null,
      isUser: isUser,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isInterrupted: false,
      isFinal: false,
    );
  }

  /// 用于创建状态消息的工厂方法
  factory RtcAigcMessage.status({
    required String id,
    required String status,
    required int timestamp,
    String? senderId,
  }) {
    return RtcAigcMessage(
      id: id,
      type: MessageType.status,
      text: '状态: $status',
      senderId: senderId,
      timestamp: timestamp,
      status: status,
      isInterrupted: false,
      isFinal: false,
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
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
        );
      case MessageType.user:
        return RtcAigcMessage.user(
          id: json['id'] as String,
          text: json['text'] as String,
          senderId: json['senderId'] as String?,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
        );
      case MessageType.ai:
        return RtcAigcMessage.ai(
          id: json['id'] as String,
          text: json['text'] as String,
          senderId: json['senderId'] as String?,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
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
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
          senderId: json['senderId'] as String?,
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
              : DateTime.now().millisecondsSinceEpoch,
        );
      case MessageType.status:
        return RtcAigcMessage.status(
          id: json['id'] as String,
          status: json['status'] as String,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
          senderId: json['senderId'] as String?,
        );
      case MessageType.system:
        return RtcAigcMessage.system(
          id: json['id'] as String,
          text: json['text'] as String,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
        );
      case MessageType.error:
        return RtcAigcMessage.error(
          id: json['id'] as String,
          text: json['text'] as String,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
        );
      case MessageType.unknown:
      default:
        return RtcAigcMessage(
          id: json['id'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.unknown,
          text: json['text'] as String? ?? '',
          senderId: json['senderId'] as String?,
          isUser: false,
          isInterrupted: false,
          timestamp: json['timestamp'] != null
              ? int.parse(json['timestamp'] as String)
              : DateTime.now().millisecondsSinceEpoch,
          functionName: null,
          functionArguments: null,
          status: null,
          isFinal: false,
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

    json['text'] = text;

    if (senderId != null) {
      json['senderId'] = senderId;
    }

    if (isInterrupted) {
      json['isInterrupted'] = isInterrupted;
    }

    if (functionName != null && functionArguments != null) {
      json['functionCall'] = {
        'name': functionName,
        'arguments': functionArguments,
      };
    }

    if (status != null) {
      json['status'] = status;
    }

    json['isFinal'] = isFinal;

    return json;
  }

  /// 复制并修改某些属性
  RtcAigcMessage copyWith({
    String? id,
    MessageType? type,
    String? text,
    String? senderId,
    bool? isUser,
    bool? isInterrupted,
    int? timestamp,
    String? functionName,
    Map<String, dynamic>? functionArguments,
    String? status,
    bool? isFinal,
  }) {
    return RtcAigcMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      isUser: isUser ?? this.isUser,
      isInterrupted: isInterrupted ?? this.isInterrupted,
      timestamp: timestamp ?? this.timestamp,
      functionName: functionName ?? this.functionName,
      functionArguments: functionArguments ?? this.functionArguments,
      status: status ?? this.status,
      isFinal: isFinal ?? this.isFinal,
    );
  }

  @override
  String toString() {
    return 'RtcAigcMessage{id: $id, type: $type, text: $text, senderId: $senderId, isUser: $isUser, isInterrupted: $isInterrupted, timestamp: $timestamp, functionName: $functionName, functionArguments: $functionArguments, status: $status, isFinal: $isFinal}';
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

//
// {definite: false, language: zh, mode: 1, paragraph: false, sequence: 249, text: 愿意的话，和我多说一说，说出来或许心里能, timestamp: 1745289846606, userId: ChatBot01}
/// 字幕实体类
class SubtitleEntity {
  /// 是否确定
  final bool? definite;

  /// 语言
  final String? language;

  /// 模式
  final int? mode;

  /// 段落
  final bool? paragraph;

  /// 序列
  final int? sequence;

  /// 文本
  final String? text;

  /// 时间戳
  final int? timestamp;

  /// 用户ID
  final String? userId;

  /// 构造函数
  SubtitleEntity({
    this.definite,
    this.language,
    this.mode,
    this.paragraph,
    this.sequence,
    this.text,
    this.timestamp,
    this.userId,
  });

  /// 从JSON创建实例
  factory SubtitleEntity.fromJson(Map<String, dynamic> json) {
    return SubtitleEntity(
      definite: json['definite'] == true,
      language: json['language'],
      mode: json['mode'],
      paragraph: json['paragraph'],
      sequence: json['sequence'],
      text: json['text'],
      timestamp: json['timestamp'],
      userId: json['userId'],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'definite': definite,
      'language': language,
      'mode': mode,
      'paragraph': paragraph,
      'sequence': sequence,
      'text': text,
      'timestamp': timestamp,
      'userId': userId,
    };
  }

  /// 复制并修改字幕实体
  SubtitleEntity copyWith({
    bool? definite,
    String? language,
    int? mode,
    bool? paragraph,
    int? sequence,
    String? text,
    int? timestamp,
    String? userId,
  }) {
    return SubtitleEntity(
      definite: definite ?? this.definite,
      language: language ?? this.language,
      mode: mode ?? this.mode,
      paragraph: paragraph ?? this.paragraph,
      sequence: sequence ?? this.sequence,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'SubtitleEntity(definite: $definite, language: $language, mode: $mode, '
        'paragraph: $paragraph, sequence: $sequence, text: $text, '
        'timestamp: $timestamp, userId: $userId)';
  }
}
