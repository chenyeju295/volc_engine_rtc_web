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

  // 新增: 当前正在处理的AI消息ID
  String? _currentAiMessageId;
  // 新增: 是否有临时字幕显示
  bool _hasPendingSubtitle = false;
  // 新增: 临时字幕消息ID集合
  Set<String> _pendingSubtitleIds = {};

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

  late RtcAigcPlugin _rtcEngine;
  bool _isAudioTestRunning = false;

  // 新增: 调试开关
  bool _debugMode = false;

  // 新增: 字幕回调计数器，用于诊断
  int _subtitleCallbackCount = 0;

  // 新增: 最后接收的字幕时间戳
  int _lastSubtitleTimestamp = 0;

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
      //{
      //           "AppId": "67f3871435d851017835d866",
      //           "RoomId": "room1",
      //           "TaskId": "user1",
      //           "AgentConfig": {
      //             "TargetUserId": ["user1"],
      //             "WelcomeMessage": "你好，我是火山引擎 RTC 语音助手，有什么需要帮忙的吗？",
      //             "UserId": "ChatBot01"
      //           },
      //           "Config": {
      //             "LLMConfig": {
      //               "Mode": "ArkV3",
      //               "EndPointId": "ep-20250401160533-rr59m",
      //               "VisionConfig": {"Enable": false}
      //             },
      //             "ASRConfig": {
      //               "Provider": "volcano",
      //               "ProviderParams": {
      //                 "Mode": "smallmodel",
      //                 "AppId": "4799544484",
      //                 "Cluster": "volcengine_streaming_common"
      //               }
      //             },
      //             "TTSConfig": {
      //               "Provider": "volcano",
      //               "ProviderParams": {
      //                 "app": {"appid": "4799544484", "cluster": "volcano_tts"},
      //                 "audio": {"voice_type": "BV001_streaming"}
      //               }
      //             }
      //           }
      //         }
      final aigcConfig = AigcConfig(
        appId: "67f3871435d851017835d866",
        roomId: "room1",
        taskId: "user1",
        agentConfig: AgentConfig(
          userId: 'ChatBot01',
          welcomeMessage: '你好，我是火山引擎 RTC 语音助手，有什么需要帮忙的吗？',
          targetUserId: ['user1'],
        ),
        config: Config(
          lLMConfig: LlmConfig(
            mode: 'ArkV3',
            endPointId: 'ep-20250401160533-rr59m',
          ),
          tTSConfig: TtsConfig(
            provider: 'volcano',
            providerParams: ProviderParams(
              app: App(appid: '4799544484', cluster: 'volcano_tts'),
              audio: Audio(voiceType: 'BV001_streaming'),
            ),
          ),
          aSRConfig: AsrConfig(
            provider: 'volcano',
            providerParams: AsrProviderParams(
              mode: 'smallmodel',
              appId: '4799544484',
              cluster: 'volcengine_streaming_common',
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 1));

      // 使用 AigcConfig 初始化插件
      final success = await RtcAigcPlugin.initialize(
        baseUrl: "http://localhost:3001",
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
      // 增加计数器
      _subtitleCallbackCount++;
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastSubtitle =
          _lastSubtitleTimestamp > 0 ? now - _lastSubtitleTimestamp : 0;
      _lastSubtitleTimestamp = now;

      final Map<String, dynamic> subtitleMap = subtitle;
      final String text = subtitleMap['text'] ?? '';
      final bool isFinal = subtitleMap['isFinal'] ?? false;

      // 调试模式下输出全部字幕信息
      if (_debugMode) {
        debugPrint(
            '【字幕回调】#$_subtitleCallbackCount 收到字幕，间隔: ${timeSinceLastSubtitle}ms\n内容: "$text"\n是否最终: $isFinal');
      }

      // 仅在字幕有内容时处理
      if (text.isNotEmpty) {
        setState(() {
          _currentSubtitle = text;
          _isSubtitleFinal = isFinal;

          // 只输出最终字幕的日志
          if (isFinal) {
            debugPrint('【示例】收到最终字幕: $text');
          }

          // 处理字幕添加到聊天列表的逻辑
          _handleSubtitleInChatList(text, isFinal);
        });
      }
    }, onError: (error) {
      debugPrint('【错误】字幕流错误: $error');
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
      final List<RtcAigcMessage> messageMap = message;
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
              '00167f3871435d851017835d866QAA2tbkBY338Z+O3BWgFAHJvb20xBQB1c2VyMQYAAADjtwVoAQDjtwVoAgDjtwVoAwDjtwVoBADjtwVoBQDjtwVoIAC0vvemDyBdXHdEBMgp0JkssQ39DfqlxzeX40uOaVgVQQ==');

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
        type: MessageType.system,
      ));
    });
    _scrollToBottom();
  }

  // 开始音频测试
  Future<void> _startAudioTest() async {
    if (_isAudioTestRunning) return;

    try {
      Map<String, dynamic> result =
          await RtcAigcPlugin.startAudioPlaybackDeviceTest(
              "http://music.163.com/song/media/outer/url?id=447925558.mp3",
              200);

      if (result['success']) {
        setState(() {
          _isAudioTestRunning = true;
        });
        _addSystemMessage('音频设备测试已开始');
      } else {
        _addSystemMessage('开始音频设备测试失败: ${result['error']}');
      }
    } catch (e) {
      _addSystemMessage('开始音频设备测试出错: $e');
    }
  }

  // 停止音频测试
  Future<void> _stopAudioTest() async {
    if (!_isAudioTestRunning) return;

    try {
      Map<String, dynamic> result =
          await RtcAigcPlugin.stopAudioDeviceRecordAndPlayTest();

      if (result['success']) {
        setState(() {
          _isAudioTestRunning = false;
        });
        _addSystemMessage('音频设备测试已停止');
      } else {
        _addSystemMessage('停止音频设备测试失败: ${result['error']}');
      }
    } catch (e) {
      _addSystemMessage('停止音频设备测试出错: $e');
    }
  }

  // 新增: 处理字幕在聊天列表中的显示
  void _handleSubtitleInChatList(String text, bool isFinal) {
    if (text.isEmpty) {
      return;
    }

    // 如果是最终字幕且没有临时字幕，直接添加为新消息
    if (isFinal && !_hasPendingSubtitle) {
      debugPrint('【示例】添加新的最终字幕消息: $text');
      _addAiMessage(text, isFinal: true);
      return;
    }

    // 如果是第一个临时字幕，创建新消息
    if (!_hasPendingSubtitle) {
      _currentAiMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      _addAiMessage(text, isFinal: false, messageId: _currentAiMessageId);
      _hasPendingSubtitle = true;
      debugPrint('【示例】添加新的临时字幕消息: $text');
      return;
    }

    // 如果已有临时字幕，更新现有消息
    if (_hasPendingSubtitle && _currentAiMessageId != null) {
      _updateAiMessage(text, isFinal: isFinal, messageId: _currentAiMessageId!);

      if (isFinal) {
        debugPrint('【示例】更新为最终字幕: $text');
      }

      // 如果是最终字幕，重置状态
      if (isFinal) {
        _hasPendingSubtitle = false;
        _currentAiMessageId = null;
      }
    }
  }

  // 新增: 添加AI消息到聊天列表
  void _addAiMessage(String text, {bool isFinal = true, String? messageId}) {
    final id = messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.add(RtcAigcMessage.text(
        text: text,
        isUser: false,
        id: id,
      ));

      // 如果不是最终字幕，将ID添加到临时字幕集合
      if (!isFinal) {
        _pendingSubtitleIds.add(id);
      }
    });
    _scrollToBottom();
  }

  // 新增: 更新现有的AI消息
  void _updateAiMessage(String text,
      {required bool isFinal, required String messageId}) {
    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].id == messageId) {
          _messages[i] = RtcAigcMessage.text(
            text: text,
            isUser: false,
            id: messageId,
          );

          // 如果是最终字幕，从临时字幕集合中移除
          if (isFinal) {
            _pendingSubtitleIds.remove(messageId);
          }
          break;
        }
      }
    });
    _scrollToBottom();
  }

  // 切换调试模式
  void _toggleDebugMode() {
    setState(() {
      _debugMode = !_debugMode;
      _addSystemMessage(_debugMode ? '已开启调试模式' : '已关闭调试模式');
      debugPrint('【示例】调试模式: $_debugMode');
      if (_debugMode) {
        debugPrint('【字幕统计】总计收到 $_subtitleCallbackCount 条字幕回调');
      }
    });
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

        // 字幕显示 - 仅在没有临时字幕显示在聊天列表时且AI正在说话时显示
        if (!_hasPendingSubtitle && _isSpeaking)
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
                onPressed: _isConversationActive ? _sendMessage : null,
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
                if (_debugMode)
                  _buildStatusItem('字幕回调', '$_subtitleCallbackCount 次'),
              ],
            ),
          ),
        ),

        // 音频设备测试 (新增卡片)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('音频设备测试', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _isInitialized ? _startAudioTest : null,
                  child: const Text('开始音频测试'),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _isInitialized ? _stopAudioTest : null,
                  child: const Text('停止音频测试'),
                ),
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

        // 调试工具卡片 (新增)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('调试工具', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: _toggleDebugMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _debugMode ? Colors.green : Colors.grey,
                  ),
                  child: Text(_debugMode ? '关闭调试模式' : '开启调试模式'),
                ),
                if (_debugMode) ...[
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () {
                      _addSystemMessage(
                          '字幕统计: 总计 $_subtitleCallbackCount 条字幕回调');
                    },
                    child: const Text('显示字幕统计'),
                  ),
                ],
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
    final isSystem = message.type == MessageType.system;

    // 检查是否为临时字幕
    final isTemporarySubtitle =
        !isUser && _pendingSubtitleIds.contains(message.id);

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
        color: isUser
            ? Colors.blue.shade100
            : (isTemporarySubtitle ? Colors.grey.shade100 : Colors.white),
        borderRadius: BorderRadius.circular(8.0),
        border: isTemporarySubtitle
            ? Border.all(
                color: Colors.blue.shade200,
                width: 1.0,
                style: BorderStyle.solid)
            : null,
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
                Row(
                  children: [
                    Text(
                      isUser ? '我' : 'AI助手',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isTemporarySubtitle) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            const Text(
                              '输入中...',
                              style:
                                  TextStyle(fontSize: 12.0, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  message.text ?? '',
                  style: TextStyle(
                    fontStyle: isTemporarySubtitle
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
