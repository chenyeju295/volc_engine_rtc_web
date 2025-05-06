import 'dart:async';
import 'package:flutter/material.dart';
import 'package:volc_engine_rtc_web/volc_engine_rtc_web.dart';

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
  final String userID = 'user1';
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
        appId: " ",
        roomId: "room1",
        taskId: userID,
        agentConfig: AgentConfig(
          userId: 'ChatBot01',
          welcomeMessage: '你好，我是火山引擎 RTC 语音助手，有什么需要帮忙的吗？',
          targetUserId: [userID],
        ),
        config: Config(
          lLMConfig: LlmConfig(
            mode: 'ArkV3',
            endPointId: ' ',
          ),
          tTSConfig: TtsConfig(
            provider: 'volcano',
            providerParams: ProviderParams(
              app: App(appid: ' ', cluster: 'volcano_tts'),
              audio: Audio(voiceType: 'BV001_streaming'),
            ),
          ),
          aSRConfig: AsrConfig(
            provider: 'volcano',
            providerParams: AsrProviderParams(
              mode: 'smallmodel',
              appId: ' ',
              cluster: 'volcengine_streaming_common',
            ),
          ),
        ),
      );

      final success = await RtcAigcPlugin.initialize(
        baseUrl: " ",
        config: aigcConfig,
        appKey: ' ',
      );

      if (success) {
        setState(() {
          _status = '初始化成功';
          _isInitialized = true;
        });

        _setupSubscriptions();

        // 请求麦克风访问权限
        final permissionResult = await RtcAigcPlugin.enableDevices(audio: true);
        if (permissionResult['audio'] == true) {
          _addSystemMessage('已获取麦克风权限');

          // 枚举设备
          await _listDevices();
        } else {
          _addSystemMessage(
              '获取麦克风权限失败: ${permissionResult['audioExceptionError'] ?? "未知错误"}');
        }
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
      if (subtitle.definite == true) {
        debugPrint('收到最终字幕数据: 类型=${subtitle.runtimeType}, 内容=$subtitle');
      }

      SubtitleEntity sub = subtitle;
      if (sub.text != null) {
        final bool isFromUser = userID == sub.userId;

        setState(() {
          _currentSubtitle = sub.text!;
          _isSubtitleFinal = sub.definite == true;

          _handleSubtitleInChatList(
              _currentSubtitle, _isSubtitleFinal, isFromUser);
        });
      }
    }, onError: (error) {
      debugPrint('字幕流错误: $error');
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

  void _handleSubtitleInChatList(String text, bool isFinal, bool isUser) {
    if (text.isEmpty) return;

    // 如果是用户字幕，以不同方式处理
    if (isUser) {
      // 用户的字幕通常应该是说话的转录，可以直接作为一条新消息添加
      if (isFinal) {
        // 只处理最终字幕，避免过多中间状态
        _addUserMessage(text);
        debugPrint('添加用户字幕作为新消息: $text');
      }
      return;
    }

    // 以下处理AI字幕
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

  // 添加用户消息到聊天列表
  void _addUserMessage(String text) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.add(RtcAigcMessage.text(
        text: text,
        isUser: true,
        id: id,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isFinal: true,
      ));
    });
    _scrollToBottom();
  }

  // 添加AI消息到聊天列表
  void _addAiMessage(String text, {bool isFinal = true, String? messageId}) {
    final id = messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      final message = RtcAigcMessage.text(
        text: text,
        isUser: false,
        id: id,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isFinal: isFinal,
      );

      _messages.add(message);

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
          final oldMessage = _messages[i];
          _messages[i] = RtcAigcMessage.text(
            text: text,
            isUser: false,
            id: messageId,
            timestamp: oldMessage.timestamp,
            isFinal: isFinal,
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
      final success = await RtcAigcPlugin.startConversation();

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

  // 列出可用设备
  Future<void> _listDevices() async {
    try {
      await RtcAigcPlugin.enableDevices();
      final devices = await RtcAigcPlugin.enumerateDevices();
      if (devices.isNotEmpty) {
        _addSystemMessage('发现 ${devices.length} 个媒体设备');

        // 分类设备
        List<Map<String, dynamic>> audioInputs = [];
        List<Map<String, dynamic>> audioOutputs = [];

        for (var device in devices) {
          final kind = device['kind'] ?? '';
          if (kind == 'audioinput') {
            audioInputs.add(device);
          } else if (kind == 'audiooutput') {
            audioOutputs.add(device);
          }
        }

        if (audioInputs.isNotEmpty) {
          _addSystemMessage('麦克风设备: ${audioInputs.length} 个');
        }

        if (audioOutputs.isNotEmpty) {
          _addSystemMessage('扬声器设备: ${audioOutputs.length} 个');
        }
      } else {
        _addSystemMessage('未找到媒体设备');
      }
    } catch (e) {
      _addSystemMessage('获取设备列表失败: $e');
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
                color: _isSubtitleFinal
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _isSubtitleFinal
                      ? Colors.green.shade200
                      : Colors.blue.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isSpeaking ? Icons.mic : Icons.speaker_notes,
                        color: _isSpeaking ? Colors.green : Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSubtitleFinal ? "最终字幕" : "实时字幕",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isSubtitleFinal
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                      const Spacer(),
                      if (!_isSubtitleFinal)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _isSubtitleFinal ? Colors.green : Colors.blue),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (_isSpeaking)
                        IconButton(
                          icon: const Icon(Icons.stop_circle,
                              color: Colors.red, size: 20),
                          onPressed: _interruptConversation,
                          tooltip: '打断',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: _isSubtitleFinal
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
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
    final isUser = message.isUser;
    final isSystem = message.type == MessageType.system;
    final isTemporarySubtitle =
        !isUser && _pendingSubtitleIds.contains(message.id);
    final isFinal = message.isFinal;

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
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
          ),
        ),
      );
    }

    // 获取角色标识
    final String roleName = isUser ? '我' : 'AI助手';
    final Color roleColor =
        isUser ? Colors.blue.shade700 : Colors.green.shade700;
    final IconData roleIcon = isUser ? Icons.person : Icons.smart_toy;

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
              : (isTemporarySubtitle
                  ? Colors.grey.shade100
                  : (isFinal ? Colors.green.shade50 : Colors.white)),
          borderRadius: BorderRadius.circular(12.0),
          border: isTemporarySubtitle
              ? Border.all(color: Colors.blue.shade200, width: 0.5)
              : (isFinal ? Border.all(color: Colors.green.shade200) : null),
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
                  roleIcon,
                  size: 16,
                  color: isUser ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  roleName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isTemporarySubtitle
                          ? Colors.grey.shade200
                          : (isFinal
                              ? Colors.green.shade100
                              : Colors.blue.shade100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isTemporarySubtitle ? "输入中" : (isFinal ? "最终回复" : "临时回复"),
                      style: TextStyle(
                        fontSize: 10,
                        color: isTemporarySubtitle
                            ? Colors.grey.shade700
                            : (isFinal
                                ? Colors.green.shade700
                                : Colors.blue.shade700),
                      ),
                    ),
                  ),
                ],
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
              message.text,
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
