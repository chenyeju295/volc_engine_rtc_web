import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
import 'widgets/conversation_view.dart' as local_widgets; // 导入本地的会话视图组件

class ConversationDemo extends StatefulWidget {
  const ConversationDemo({Key? key}) : super(key: key);

  @override
  State<ConversationDemo> createState() => _ConversationDemoState();
}

class _ConversationDemoState extends State<ConversationDemo> {
  // 控制器
  final TextEditingController _messageController = TextEditingController();

  // 消息流控制器
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 状态流控制器
  final StreamController<Map<String, dynamic>> _stateStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 会话是否已开始
  bool _isConversationStarted = false;

  // 是否正在发送消息
  bool _isSendingMessage = false;

  // 用户ID
  String _userId = 'User${Random().nextInt(10000)}';

  // AI会话ID
  String _botId = 'BotID001';

  // 字幕订阅
  StreamSubscription? _subtitleSubscription;

  // 状态订阅
  StreamSubscription? _stateSubscription;

  // 消息订阅
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageStreamController.close();
    _stateStreamController.close();

    // 取消所有订阅
    _subtitleSubscription?.cancel();
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();

    // 如果会话已开始，停止它
    if (_isConversationStarted) {
      RtcAigcPlugin.stopConversation();
    }

    super.dispose();
  }

  // 设置事件监听器
  void _setupEventListeners() {
    // 监听字幕消息
    _subtitleSubscription = RtcAigcPlugin.subtitleStream.listen((subtitle) {
      if (subtitle == null) return;
      subtitle = subtitle as Map<String, dynamic>;
      final text = subtitle['text'] as String? ?? '';
      final isFinal = subtitle['isFinal'] as bool? ?? false;

      debugPrint('收到字幕: $text (isFinal: $isFinal)');

      _messageStreamController.add({
        'userId': _botId,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isFinal': isFinal,
      });
    });

    // 监听状态变化
    _stateSubscription = RtcAigcPlugin.stateStream?.listen((state) {
      final stateString = state is String ? state : state.toString();
      final isThinking = stateString.toString().contains('THINKING') ||
          stateString.toString().contains('PROCESSING');
      final isTalking = stateString.toString().contains('SPEAKING') ||
          stateString.toString().contains('TALKING');

      debugPrint('状态变化: $stateString (思考: $isThinking, 说话: $isTalking)');

      _stateStreamController.add({
        'state': stateString,
        'isThinking': isThinking,
        'isTalking': isTalking,
      });
    });

    // 添加连接状态流监听
    RtcAigcPlugin.connectionStateStream.listen((connectionState) {
      debugPrint('连接状态变化: $connectionState');
    });

    // 添加音频状态流监听
    RtcAigcPlugin.audioStatusStream.listen((isActive) {
      debugPrint('音频状态变化: ${isActive ? "活跃" : "非活跃"}');
    });

    // 添加设备状态流监听
    RtcAigcPlugin.deviceStateStream.listen((devices) {
      debugPrint('设备变化: ${devices.toString()}');
    });

    _initializePluginAndRequestMicrophoneAccess();
  }

  // 初始化插件并请求麦克风权限
  Future<void> _initializePluginAndRequestMicrophoneAccess() async {
    try {
      debugPrint('正在初始化插件并请求麦克风权限...');

      // 注册消息处理回调
      final initResult = await RtcAigcPlugin.initialize(
          // 必需的参数
          appId: '67eb953062b4b601a6df1348', // 替换为您的APP ID
          roomId: 'demo_room',
          userId: _userId,
          token:
              '00167eb953062b4b601a6df1348QAAId6gE4FHzZ2CM/GcFAHJvb20xBQB1c2VyMQYAAABgjPxnAQBgjPxnAgBgjPxnAwBgjPxnBABgjPxnBQBgjPxnIACiJ43l8vpJTdIYqpqovQOKogW6NBmuyd0jEmubjbCR8Q==', // 使用示例token
          serverUrl: "http://localhost:3001",
          // 回调函数
          onMessage: (String message, bool isUser) {
            debugPrint('收到消息: ${isUser ? "用户" : "AI"} - $message');

            // 如果是用户消息且不是通过UI发送的，添加到消息流
            if (isUser && !message.startsWith(_userId)) {
              _messageStreamController.add({
                'userId': _userId,
                'text': message,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'isFinal': true,
              });
            }
          });

      debugPrint('插件初始化结果: $initResult');

      // 显式请求麦克风权限
      await _requestMicrophoneAccess();

      debugPrint('已设置所有事件监听器');
    } catch (e) {
      debugPrint('初始化插件出错: $e');
      _showErrorSnackBar('初始化插件失败: $e');
    }
  }

  // 请求麦克风权限
  Future<void> _requestMicrophoneAccess() async {
    try {
      debugPrint('正在请求麦克风权限...');

      final result = await RtcAigcPlugin.requestMicrophoneAccess();
      final success = result is Map ? (result['success'] ?? false) : false;

      if (success) {
        debugPrint('麦克风权限获取成功');

        // 成功获取权限后获取设备列表
        await RtcAigcPlugin.getAudioInputDevices();
        await RtcAigcPlugin.getAudioOutputDevices();
      } else {
        debugPrint('麦克风权限获取失败');
        _showErrorSnackBar('麦克风权限获取失败，某些功能可能无法正常工作');
      }
    } catch (e) {
      debugPrint('请求麦克风权限时出错: $e');
      _showErrorSnackBar('请求麦克风权限失败: $e');
    }
  }

  // 开始会话
  Future<void> _startConversation() async {
    setState(() {
      _isSendingMessage = true;
    });

    try {
      final success = await RtcAigcPlugin.startConversation(
        welcomeMessage:
            'Hello, I am your AI assistant. How can I help you today?',
      );

      if (success) {
        setState(() {
          _isConversationStarted = true;
        });

        // 发送系统消息
        _messageStreamController.add({
          'userId': 'system',
          'text': '会话已开始，请开始对话',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isFinal': true,
        });
      } else {
        _showErrorSnackBar('开始会话失败');
      }
    } catch (e) {
      _showErrorSnackBar('开始会话出错: $e');
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }

  // 停止会话
  Future<void> _stopConversation() async {
    setState(() {
      _isSendingMessage = true;
    });

    try {
      final success = await RtcAigcPlugin.stopConversation();

      setState(() {
        _isConversationStarted = false;
      });

      // 发送系统消息
      _messageStreamController.add({
        'userId': 'system',
        'text': '会话已结束',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isFinal': true,
      });
    } catch (e) {
      _showErrorSnackBar('停止会话出错: $e');
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }

  // 发送消息
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // 如果会话未开始，先开始它
    if (!_isConversationStarted) {
      await _startConversation();
    }

    setState(() {
      _isSendingMessage = true;
    });

    // 清空输入框
    _messageController.clear();

    // 先添加用户消息到UI
    _messageStreamController.add({
      'userId': _userId,
      'text': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isFinal': true,
    });

    try {
      await RtcAigcPlugin.sendTextMessage(message);
    } catch (e) {
      _showErrorSnackBar('发送消息出错: $e');
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }

  // 打断对话
  Future<void> _interruptConversation() async {
    try {
      // 使用停止会话代替打断
      await RtcAigcPlugin.stopConversation();
      await Future.delayed(const Duration(milliseconds: 300));
      await RtcAigcPlugin.startConversation();

      // 发送状态更新
      _stateStreamController.add({
        'state': 'INTERRUPTED',
        'isThinking': false,
        'isTalking': false,
      });

      // 添加系统消息
      _messageStreamController.add({
        'userId': 'system',
        'text': '已打断AI回复',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isFinal': true,
      });
    } catch (e) {
      _showErrorSnackBar('打断对话出错: $e');
    }
  }

  // 显示错误提示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI对话演示'),
        actions: [
          // Join Room Button
          IconButton(
            icon: const Icon(Icons.meeting_room),
            tooltip: '加入房间',
            onPressed: _joinRoom,
          ),
          if (_isConversationStarted)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: '停止会话',
              onPressed: _stopConversation,
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '开始会话',
              onPressed: _startConversation,
            ),
        ],
      ),
      body: Column(
        children: [
          // 会话视图
          Expanded(
            child: local_widgets.ConversationView(
              messageHistoryStream: _messageStreamController.stream,
              stateStream: _stateStreamController.stream,
              userId: _userId,
              botId: _botId,
              onInterrupt: _interruptConversation,
            ),
          ),

          // 输入区域
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isSendingMessage,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: _isSendingMessage ? null : _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 加入房间
  Future<void> _joinRoom() async {
    setState(() {
      _isSendingMessage = true;
    });

    try {
      final success = await RtcAigcPlugin.joinRoom(
        roomId: 'demo_room',
        userId: _userId,
        welcomeMessage: '你好，我是AI助手，有什么可以帮你的吗？',
      );

      if (success) {
        // 发送系统消息
        _messageStreamController.add({
          'userId': 'system',
          'text': '已成功加入房间',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isFinal': true,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功加入房间'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar('加入房间失败');
      }
    } catch (e) {
      _showErrorSnackBar('加入房间出错: $e');
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }
}
