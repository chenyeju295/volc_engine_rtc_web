import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
import 'widgets/subtitle_view.dart' as local_widgets;

void main() {
  // 确保Flutter binding已初始化
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTC AIGC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const RtcAigcDemo(),
    );
  }
}

class RtcAigcDemo extends StatefulWidget {
  const RtcAigcDemo({super.key});

  @override
  State<RtcAigcDemo> createState() => _RtcAigcDemoState();
}

class _RtcAigcDemoState extends State<RtcAigcDemo> {
  String _status = '未初始化';
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _isConversationActive = false;
  bool _isSpeaking = false;
  String _currentSubtitle = '';
  bool _isSubtitleFinal = false;
  List<RtcAigcMessage> _messages = [];
  List<Map<String, String>> _audioInputDevices = [];
  List<Map<String, String>> _audioOutputDevices = [];
  String? _selectedAudioInputId;
  String? _selectedAudioOutputId;

  // 新增: AI用户状态
  String? _aiUserId;
  bool _isAiAudioCaptureStarted = false;
  bool _isAiPublished = false;

  // 控制器
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 订阅
  StreamSubscription? _subtitleSubscription;
  StreamSubscription? _audioStatusSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _stateSubscription;

  // 新增: RTC事件订阅
  StreamSubscription? _userJoinedSubscription;
  StreamSubscription? _userLeaveSubscription;
  StreamSubscription? _userPublishStreamSubscription;
  StreamSubscription? _userUnpublishStreamSubscription;
  StreamSubscription? _userStartAudioCaptureSubscription;
  StreamSubscription? _userStopAudioCaptureSubscription;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  @override
  void dispose() {
    _subtitleSubscription?.cancel();
    _audioStatusSubscription?.cancel();
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();

    // 新增: 取消RTC事件订阅
    _userJoinedSubscription?.cancel();
    _userLeaveSubscription?.cancel();
    _userPublishStreamSubscription?.cancel();
    _userUnpublishStreamSubscription?.cancel();
    _userStartAudioCaptureSubscription?.cancel();
    _userStopAudioCaptureSubscription?.cancel();

    _messageController.dispose();
    _scrollController.dispose();
    RtcAigcPlugin.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // 确保Flutter binding已初始化
    WidgetsFlutterBinding.ensureInitialized();

    setState(() {
      _status = '正在初始化...';
    });

    try {
      // 创建 AIGC 配置
      final aigcConfig = AigcConfig(
        appId: '67eb953062b4b601a6df1348', // 替换为您的 APP ID
        roomId: 'room1',
        taskId: 'user1',
        token:
            '00167eb953062b4b601a6df1348QAAId6gE4FHzZ2CM/GcFAHJvb20xBQB1c2VyMQYAAABgjPxnAQBgjPxnAgBgjPxnAwBgjPxnBABgjPxnBQBgjPxnIACiJ43l8vpJTdIYqpqovQOKogW6NBmuyd0jEmubjbCR8Q==', // 替换为您的 Token

        serverUrl: 'http://localhost:3001',
        agentConfig: AgentConfig(
          userId: 'RobotMan_',
          welcomeMessage: '你好，我是你的AI小助手，有什么可以帮你的吗？',
          enableConversationStateCallback: true,
          serverMessageSignatureForRTS: 'conversation',
          targetUserId: ['user1'],
        ),
        config: Config(
          lLMConfig: LlmConfig(
            mode: 'ArkV3',
            endPointId: 'ep-20250401160533-rr59m', // 替换为您的 EndPointID
            maxTokens: 1024,
            temperature: 0.1,
            topP: 0.3,
            systemMessages: ["你是小宁，性格幽默又善解人意。你在表达时需简明扼要，有自己的观点。"],
            modelName: 'ArkV3',
          ),
          tTSConfig: TtsConfig(
            provider: 'volcano',
            providerParams: ProviderParams(
              appId: '4799544484', // 替换为您的 TTS AppID
              cluster: 'volcano_tts',
            ),
          ),
          aSRConfig: AsrConfig(
            provider: 'volcano',
            providerParams: ProviderParams(
              mode: 'smallmodel',
              appId: '4799544484', // 替换为您的 ASR AppID
              cluster: 'volcengine_streaming_common',
            ),
          ),
        ),
      );

      // 使用 AigcConfig 初始化插件
      final success = await RtcAigcPlugin.initialize(
        config: aigcConfig,
      );

      if (success) {
        setState(() {
          _status = '初始化成功';
          _isInitialized = true;
        });

        // 设置订阅
        _setupSubscriptions();
      } else {
        setState(() {
          _status = '初始化失败';
        });
      }
    } catch (e) {
      setState(() {
        _status = '错误: $e';
      });
    }
  }

  void _setupSubscriptions() {
    // 订阅字幕流
    _subtitleSubscription = RtcAigcPlugin.subtitleStream.listen((subtitle) {
      if (subtitle == null) return;
      final Map<String, dynamic> subtitleMap = subtitle as Map<String, dynamic>;
      setState(() {
        _currentSubtitle = subtitleMap['text'] ?? '';
        _isSubtitleFinal = subtitleMap['isFinal'] ?? false;
      });
    });

    // 订阅音频状态流
    _audioStatusSubscription =
        RtcAigcPlugin.audioStatusStream.listen((isActive) {
      setState(() {
        _isSpeaking = isActive;
      });
    });

    // 订阅消息流
    _messageSubscription = RtcAigcPlugin.messageHistoryStream.listen((message) {
      final List<RtcAigcMessage> messageMap = message as List<RtcAigcMessage>;
      setState(() {
        _messages.addAll(messageMap);
      });
      _scrollToBottom();
    });

    // 订阅状态流
    _stateSubscription = RtcAigcPlugin.stateStream.listen((state) {
      if (state == null) return;
      setState(() {
        _status = state.toString();
      });
    });

    // 新增: 订阅RTC事件流
    _setupRtcEventSubscriptions();
  }

  // 新增: 设置RTC事件订阅
  void _setupRtcEventSubscriptions() {
    // 用户加入事件
    _userJoinedSubscription = RtcAigcPlugin.userJoinedStream.listen((data) {
      _handleUserJoined(data);
    });

    // 用户离开事件
    _userLeaveSubscription = RtcAigcPlugin.userLeaveStream.listen((data) {
      _handleUserLeave(data);
    });

    // 用户发布流事件
    _userPublishStreamSubscription =
        RtcAigcPlugin.userPublishStreamStream.listen((data) {
      _handleUserPublishStream(data);
    });

    // 用户取消发布流事件
    _userUnpublishStreamSubscription =
        RtcAigcPlugin.userUnpublishStreamStream.listen((data) {
      _handleUserUnpublishStream(data);
    });

    // 用户开始音频采集事件
    _userStartAudioCaptureSubscription =
        RtcAigcPlugin.userStartAudioCaptureStream.listen((data) {
      _handleUserStartAudioCapture(data);
    });

    // 用户停止音频采集事件
    _userStopAudioCaptureSubscription =
        RtcAigcPlugin.userStopAudioCaptureStream.listen((data) {
      _handleUserStopAudioCapture(data);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleStateChange(String state, String? message) {
    setState(() {
      _status = state;
    });
  }

  void _handleMessage(String text, bool isUser) {
    setState(() {
      _messages.add(RtcAigcMessage(
        text: text,
        isUser: isUser,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.text,
      ));
    });
    _scrollToBottom();
  }

  void _handleAudioStatusChange(bool isPlaying) {
    setState(() {
      _isSpeaking = isPlaying;
    });
  }

  void _handleSubtitle(Map<String, dynamic> subtitle) {
    setState(() {
      _currentSubtitle = subtitle['text'] ?? '';
      _isSubtitleFinal = subtitle['isFinal'] ?? false;
    });
  }

  Future<void> _joinRoom() async {
    if (!_isInitialized) return;

    setState(() {
      _status = '正在加入房间...';
    });

    try {
      final success = await RtcAigcPlugin.joinRoom(
          roomId: 'room1',
          userId: 'user1',
          token:
              '00167eb953062b4b601a6df1348QAAId6gE4FHzZ2CM/GcFAHJvb20xBQB1c2VyMQYAAABgjPxnAQBgjPxnAgBgjPxnAwBgjPxnBABgjPxnBQBgjPxnIACiJ43l8vpJTdIYqpqovQOKogW6NBmuyd0jEmubjbCR8Q==');

      if (success) {
        setState(() {
          _status = '已加入房间';
          _isJoined = true;
        });
      } else {
        setState(() {
          _status = '加入房间失败';
        });
      }
    } catch (e) {
      setState(() {
        _status = '错误: $e';
      });
    }
  }

  Future<void> _startConversation() async {
    if (!_isInitialized || !_isJoined) return;

    setState(() {
      _status = '正在开始对话...';
      _addSystemMessage('正在启动AI智能体...');
    });

    try {
      final success = await RtcAigcPlugin.startConversation(
        welcomeMessage: '你好，我是AI助手，有什么可以帮助你的？',
      );

      if (success) {
        setState(() {
          _status = '对话已开始';
          _isConversationActive = true;
          _addSystemMessage('AI智能体已启动，等待欢迎语...');
        });
      } else {
        setState(() {
          _status = '开始对话失败';
          _addSystemMessage('AI智能体启动失败');
        });
      }
    } catch (e) {
      setState(() {
        _status = '错误: $e';
        _addSystemMessage('AI智能体启动出错: $e');
      });
    }
  }

  Future<void> _stopConversation() async {
    if (!_isInitialized || !_isConversationActive) return;

    setState(() {
      _status = '正在停止对话...';
      _addSystemMessage('正在关闭AI智能体...');
    });

    try {
      final success = await RtcAigcPlugin.stopConversation();

      setState(() {
        _status = success ? '对话已停止' : '停止对话失败';
        _isConversationActive = false;
        _addSystemMessage(success ? 'AI智能体已关闭' : 'AI智能体关闭失败');
      });
    } catch (e) {
      setState(() {
        _status = '错误: $e';
        _addSystemMessage('AI智能体关闭出错: $e');
      });
    }
  }

  Future<void> _interruptConversation() async {
    if (!_isInitialized || !_isConversationActive) return;

    setState(() {
      _addSystemMessage('正在打断AI回答...');
    });

    try {
      await RtcAigcPlugin.interruptConversation();
      _addSystemMessage('已打断AI回答');
    } catch (e) {
      setState(() {
        _status = '错误: $e';
        _addSystemMessage('打断AI回答出错: $e');
      });
    }
  }

  Future<void> _sendMessage() async {
    if (!_isInitialized || !_isConversationActive) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      _addSystemMessage('正在发送消息...');
      await RtcAigcPlugin.sendTextMessage(message);
      _messageController.clear();
      _addSystemMessage('消息已发送，等待AI回复...');
    } catch (e) {
      setState(() {
        _status = '错误: $e';
        _addSystemMessage('发送消息出错: $e');
      });
    }
  }

  Future<void> _leaveRoom() async {
    if (!_isInitialized || !_isJoined) return;

    setState(() {
      _status = '正在离开房间...';
    });

    try {
      // 如果对话还在进行中，先停止对话
      if (_isConversationActive) {
        await RtcAigcPlugin.stopConversation();
      }

      final success = await RtcAigcPlugin.leaveRoom();

      setState(() {
        if (success) {
          _status = '已离开房间';
          _isJoined = false;
          _isConversationActive = false;
          _messages.clear();
          _currentSubtitle = '';
        } else {
          _status = '离开房间失败';
        }
      });
    } catch (e) {
      setState(() {
        _status = '错误: $e';
      });
    }
  }

  // 新增: 处理用户加入事件
  void _handleUserJoined(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId != 'user1') {
      setState(() {
        _aiUserId = userId;
        _addSystemMessage('AI助手已加入房间');
      });
    }
  }

  // 新增: 处理用户离开事件
  void _handleUserLeave(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId == _aiUserId) {
      setState(() {
        _aiUserId = null;
        _isAiAudioCaptureStarted = false;
        _isAiPublished = false;
        _addSystemMessage('AI助手已离开房间');
      });
    }
  }

  // 新增: 处理用户发布流事件
  void _handleUserPublishStream(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId == _aiUserId) {
      setState(() {
        _isAiPublished = true;
        _addSystemMessage('AI助手开始发布媒体流');
      });
    }
  }

  // 新增: 处理用户取消发布流事件
  void _handleUserUnpublishStream(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId == _aiUserId) {
      setState(() {
        _isAiPublished = false;
        _addSystemMessage('AI助手停止发布媒体流');
      });
    }
  }

  // 新增: 处理用户开始音频采集事件
  void _handleUserStartAudioCapture(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId == _aiUserId) {
      setState(() {
        _isAiAudioCaptureStarted = true;
        _addSystemMessage('AI助手开始音频采集');
      });
    }
  }

  // 新增: 处理用户停止音频采集事件
  void _handleUserStopAudioCapture(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId == _aiUserId) {
      setState(() {
        _isAiAudioCaptureStarted = false;
        _addSystemMessage('AI助手停止音频采集');
      });
    }
  }

  // 新增: 添加系统消息
  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(RtcAigcMessage(
        text: text,
        isUser: false,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.text,
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RTC AIGC Demo'),
      ),
      body: Column(
        children: [
          // 状态显示
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('RTC状态: $_status'),
                    Text('房间: ${_isJoined ? '已加入' : '未加入'}'),
                    Text('对话: ${_isConversationActive ? '进行中' : '未开始'}'),
                  ],
                ),
                if (_isJoined)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('AI说话: ${_isSpeaking ? '是' : '否'}'),
                      Text('AI: ${_aiUserId ?? '未加入'}'),
                      Text('音频: ${_isAiAudioCaptureStarted ? '已开始' : '未开始'}'),
                    ],
                  ),
              ],
            ),
          ),

          // 主内容区域
          Expanded(
            child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // 对话区域
        Expanded(
          flex: 2,
          child: _buildConversationArea(),
        ),

        // 控制面板
        Container(
          width: 200,
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey.shade100,
          child: _buildControlPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // 对话区域
        Expanded(
          flex: 3,
          child: _buildConversationArea(),
        ),

        // 控制面板 (折叠/展开)
        ExpansionTile(
          title: const Text('控制面板'),
          backgroundColor: Colors.grey.shade100,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              child: _buildControlPanel(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConversationArea() {
    return Column(
      children: [
        // 消息列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageItem(message);
            },
          ),
        ),

        // 字幕显示
        if (_currentSubtitle.isNotEmpty || _isSpeaking)
          local_widgets.SubtitleView(
            text: _currentSubtitle,
            isFinal: _isSubtitleFinal,
            isThinking: _isSpeaking,
            onInterrupt: _interruptConversation,
          ),

        // 消息输入区域
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton(
                onPressed: _sendMessage,
                child: const Text('发送'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        // AI状态信息
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('AI状态', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4.0),
                _buildStatusItem('AI用户ID', _aiUserId ?? '未加入'),
                _buildStatusItem(
                    '音频采集', _isAiAudioCaptureStarted ? '已开始' : '未开始'),
                _buildStatusItem('媒体发布', _isAiPublished ? '已发布' : '未发布'),
              ],
            ),
          ),
        ),

        // 房间控制
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('房间控制', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _isInitialized && !_isJoined ? _joinRoom : null,
                  child: const Text('加入房间'),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _isJoined && !_isConversationActive
                      ? _startConversation
                      : null,
                  child: const Text('开始对话'),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _isConversationActive ? _stopConversation : null,
                  child: const Text('停止对话'),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _isJoined ? _leaveRoom : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('离开房间'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 新增: 构建状态项
  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value.contains('未') || value.contains('不')
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(RtcAigcMessage message) {
    final isUser = message.isUser ?? false;
    final isSystem = message.isUser ?? false;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            message.text ?? '',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isUser ? Colors.blue.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUser ? Colors.blue : Colors.green,
            child: Icon(
              isUser ? Icons.person : Icons.smart_toy,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? '我' : 'AI助手',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4.0),
                Text(message.text ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
