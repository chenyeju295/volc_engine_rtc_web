import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';

void main() {
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
  // Core states
  String _status = '未初始化';
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _isConversationActive = false;
  bool _isSpeaking = false;
  bool _isMuted = false;
  String _currentSubtitle = '';
  bool _isSubtitleFinal = false;
  List<RtcAigcMessage> _messages = [];

  // AI user state
  String? _aiUserId;
  bool _hasPendingSubtitle = false;
  String? _currentAiMessageId;
  Set<String> _pendingSubtitleIds = {};

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Subscriptions
  StreamSubscription? _subtitleSubscription;
  StreamSubscription? _audioStatusSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _userJoinedSubscription;
  StreamSubscription? _userLeaveSubscription;

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
    _userJoinedSubscription?.cancel();
    _userLeaveSubscription?.cancel();

    _messageController.dispose();
    _scrollController.dispose();
    RtcAigcPlugin.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    setState(() {
      _status = '正在初始化...';
    });

    try {
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
            endPointId: 'ep-20250414121921-p9bn6',
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

      final success = await RtcAigcPlugin.initialize(
        baseUrl: "http://localhost:3001",
        config: aigcConfig,
        appKey: '05eeb1c0c3154acaa38a3886decc6b97',
      );

      if (success) {
        setState(() {
          _status = '初始化成功';
          _isInitialized = true;
        });

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
      // 调试输出字幕数据类型和内容
      debugPrint('收到字幕数据: 类型=${subtitle.runtimeType}, 内容=$subtitle');

      String text = '';
      bool isFinal = false;

      // 处理不同类型的字幕数据
      // 如果是Map类型，直接提取字段
      text = subtitle['text'] ?? '';
      isFinal = subtitle['isFinal'] ?? false;

      // 调试输出处理后的字幕
      debugPrint('处理后的字幕: text="$text", isFinal=$isFinal');

      if (text.isNotEmpty) {
        setState(() {
          _currentSubtitle = text;
          _isSubtitleFinal = isFinal;
          _handleSubtitleInChatList(text, isFinal);
        });
      }
    }, onError: (error) {
      debugPrint('字幕流错误: $error');
    });

    // 订阅状态流以获取更详细的字幕信息
    _stateSubscription = RtcAigcPlugin.stateStream.listen((state) {
      // 检查是否为字幕状态消息
      debugPrint('状态流变化: $state');
      setState(() {
        _status = state.toString();
      });
    });

    // 订阅音频状态流
    _audioStatusSubscription =
        RtcAigcPlugin.audioStatusStream.listen((isActive) {
      setState(() {
        _isSpeaking = isActive;
        debugPrint('音频状态变化: 是否说话=$isActive');
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

    // 用户加入事件
    _userJoinedSubscription = RtcAigcPlugin.userJoinedStream.listen((data) {
      _handleUserJoined(data);
    });

    // 用户离开事件
    _userLeaveSubscription = RtcAigcPlugin.userLeaveStream.listen((data) {
      _handleUserLeave(data);
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

  // 处理用户加入事件
  void _handleUserJoined(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId != 'user1') {
      setState(() {
        _aiUserId = userId;
        _addSystemMessage('AI助手已加入房间');
      });
    }
  }

  // 处理用户离开事件
  void _handleUserLeave(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null && userId == _aiUserId) {
      setState(() {
        _aiUserId = null;
        _addSystemMessage('AI助手已离开房间');
      });
    }
  }

  // 处理字幕在聊天列表中的显示
  void _handleSubtitleInChatList(String text, bool isFinal) {
    if (text.isEmpty) return;

    // 如果是最终字幕且没有临时字幕，直接添加为新消息
    if (isFinal && !_hasPendingSubtitle) {
      _addAiMessage(text, isFinal: true);
      return;
    }

    // 如果是第一个临时字幕，创建新消息
    if (!_hasPendingSubtitle) {
      _currentAiMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      _addAiMessage(text, isFinal: false, messageId: _currentAiMessageId);
      _hasPendingSubtitle = true;
      return;
    }

    // 如果已有临时字幕，更新现有消息
    if (_hasPendingSubtitle && _currentAiMessageId != null) {
      _updateAiMessage(text, isFinal: isFinal, messageId: _currentAiMessageId!);

      // 如果是最终字幕，重置状态
      if (isFinal) {
        _hasPendingSubtitle = false;
        _currentAiMessageId = null;
      }
    }
  }

  // 添加系统消息
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

  // 添加AI消息到聊天列表
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

  // 更新现有的AI消息
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

  // 加入房间
  Future<void> _joinRoom() async {
    if (!_isInitialized) return;

    setState(() {
      _status = '正在加入房间...';
    });

    try {
      final success = await RtcAigcPlugin.joinRoom();
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

  // 开始对话
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

  // 停止对话
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

  // 打断对话
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

  // 发送消息
  Future<void> _sendMessage() async {
    if (!_isInitialized || !_isConversationActive) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await RtcAigcPlugin.sendTextMessage(message);
      _messageController.clear();
    } catch (e) {
      setState(() {
        _status = '错误: $e';
        _addSystemMessage('发送消息出错: $e');
      });
    }
  }

  // 离开房间
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

  // 静音控制
  Future<void> _toggleMute() async {
    try {
      final success = await RtcAigcPlugin.muteAudio(!_isMuted);
      if (_isMuted) {
        setState(() {
          if (success["success"] == true) {
            _isMuted = false;
            _addSystemMessage('已取消静音');
          } else {
            _addSystemMessage('取消静音失败');
          }
        });
      } else {
        // 当前非静音状态，需要静音
        setState(() {
          if (success["success"] == true) {
            _isMuted = true;
            _addSystemMessage('已静音');
          } else {
            _addSystemMessage('静音失败');
          }
        });
      }

      debugPrint('静音状态切换: $_isMuted');
    } catch (e) {
      setState(() {
        _status = '错误: $e';
        _addSystemMessage('静音操作出错: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTC AIGC Demo'),
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child:
                        Text('状态: $_status', overflow: TextOverflow.ellipsis)),
                Text('房间: ${_isJoined ? '已加入' : '未加入'}'),
                Text('对话: ${_isConversationActive ? '活跃' : '未开始'}'),
              ],
            ),
          ),

          // 字幕显示区域 - 放在页面顶部，无论是否说话都显示最新字幕
          if (_currentSubtitle.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSpeaking ? Icons.mic : Icons.speaker_notes,
                    color: _isSpeaking ? Colors.green : Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_currentSubtitle)),
                  if (!_isSubtitleFinal)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                    onPressed: _interruptConversation,
                    tooltip: '打断',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // 主要内容区域
          Expanded(
            child: Column(
              children: [
                // 消息列表
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyConversation()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageItem(message);
                          },
                        ),
                ),

                // 消息输入区域
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isMuted ? Icons.mic_off : Icons.mic,
                            color: _isMuted ? Colors.red : Colors.blue),
                        onPressed: _isJoined ? _toggleMute : null,
                        tooltip: _isMuted ? '取消静音' : '静音',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: '输入消息...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isConversationActive ? _sendMessage : null,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isInitialized && !_isJoined ? _joinRoom : null,
                child: const Text('加入房间'),
              ),
              ElevatedButton(
                onPressed: _isJoined && !_isConversationActive
                    ? _startConversation
                    : null,
                child: const Text('开始对话'),
              ),
              ElevatedButton(
                onPressed: _isConversationActive ? _stopConversation : null,
                child: const Text('结束对话'),
              ),
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
    );
  }

  // 构建消息项
  Widget _buildMessageItem(RtcAigcMessage message) {
    final isUser = message.isUser ?? false;
    final isSystem = message.type == MessageType.system;
    final isTemporarySubtitle =
        !isUser && _pendingSubtitleIds.contains(message.id);

    // 系统消息样式
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
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
          ),
        ),
      );
    }

    // 用户或AI消息样式
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.blue.shade100
              : (isTemporarySubtitle ? Colors.grey.shade100 : Colors.white),
          borderRadius: BorderRadius.circular(12.0),
          border: isTemporarySubtitle
              ? Border.all(color: Colors.blue.shade200)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 16,
                  color: isUser ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  isUser ? '我' : 'AI助手',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        isUser ? Colors.blue.shade700 : Colors.green.shade700,
                  ),
                ),
                if (isTemporarySubtitle) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.text ?? '',
              style: TextStyle(
                fontStyle:
                    isTemporarySubtitle ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 空聊天界面
  Widget _buildEmptyConversation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _isConversationActive ? "发送消息开始对话吧" : "点击「开始对话」按钮开始",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
