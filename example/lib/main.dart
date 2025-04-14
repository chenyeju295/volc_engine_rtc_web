import 'dart:async';
import 'dart:math';
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

class _RtcAigcDemoState extends State<RtcAigcDemo>
    with SingleTickerProviderStateMixin {
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

  // 添加更多状态监听变量
  StreamSubscription? _localAudioPropertiesSubscription;
  StreamSubscription? _remoteAudioPropertiesSubscription;
  StreamSubscription? _networkQualitySubscription;
  StreamSubscription? _connectionStateSubscription;

  // 音频属性数据
  int _localAudioVolume = 0;
  Map<String, int> _remoteAudioVolumes = {};

  // 网络质量数据
  String _networkQuality = "未知";

  // 连接状态
  String _connectionState = "未连接";

  // 添加统计信息面板控制
  bool _showStatsPanel = false;
  late TabController _tabController;

  // 媒体统计数据
  Map<String, dynamic> _mediaStats = {};
  Timer? _statsTimer;

  // 模拟用于统计面板的数据
  int _rtt = 50;
  int _packetsLost = 0;
  double _packetLossRate = 0.01;
  int _bitrate = 200;
  int _audioLevel = 50;
  int _frameRate = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    // 取消新增的订阅
    _localAudioPropertiesSubscription?.cancel();
    _remoteAudioPropertiesSubscription?.cancel();
    _networkQualitySubscription?.cancel();
    _connectionStateSubscription?.cancel();

    _messageController.dispose();
    _scrollController.dispose();
    RtcAigcPlugin.dispose();
    _statsTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // 确保Flutter binding已初始化
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
        appKey: '05eeb1c0c3154acaa38a3886decc6b97',
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

    // 添加本地音频属性监听 - 暂时注释掉未实现的流
    /*
    _localAudioPropertiesSubscription = RtcAigcPlugin.localAudioPropertiesStream.listen((data) {
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          _localAudioVolume = data['volume'] as int? ?? 0;
        });
        if (_debugMode) {
          debugPrint('【音频属性】本地音量: $_localAudioVolume');
        }
      }
    });
    */

    // 添加远端音频属性监听 - 暂时注释掉未实现的流
    /*
    _remoteAudioPropertiesSubscription = RtcAigcPlugin.remoteAudioPropertiesStream.listen((data) {
      if (data != null && data is List) {
        setState(() {
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              final userId = item['userId'] as String?;
              final volume = item['volume'] as int?;
              if (userId != null && volume != null) {
                _remoteAudioVolumes[userId] = volume;

                // 如果是AI用户，更新说话状态
                if (userId == _aiUserId && volume > 5) {
                  _isSpeaking = true;
                } else if (userId == _aiUserId && volume <= 5) {
                  _isSpeaking = false;
                }
              }
            }
          }
        });

        if (_debugMode && _remoteAudioVolumes.isNotEmpty) {
          debugPrint('【音频属性】远端音量: $_remoteAudioVolumes');
        }
      }
    });
    */

    // 添加网络质量监听 - 暂时注释掉未实现的流
    /*
    _networkQualitySubscription = RtcAigcPlugin.networkQualityStream.listen((data) {
      if (data != null && data is Map<String, dynamic>) {
        final quality = data['quality'] as int?;
        setState(() {
          _networkQuality = _getNetworkQualityString(quality);
        });
        if (_debugMode) {
          debugPrint('【网络质量】当前质量: $_networkQuality');
        }
      }
    });
    */

    // 添加连接状态监听 - 暂时注释掉未实现的流
    /*
    _connectionStateSubscription = RtcAigcPlugin.connectionStateStream.listen((data) {
      if (data != null && data is Map<String, dynamic>) {
        final state = data['state'] as int?;
        setState(() {
          _connectionState = _getConnectionStateString(state);
        });
        if (_debugMode) {
          debugPrint('【连接状态】当前状态: $_connectionState');
        }
      }
    });
    */

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

  // 更新字幕处理逻辑
  void _handleSubtitleInChatList(String text, bool isFinal) {
    if (text.isEmpty) {
      return;
    }

    // AI在说话时添加话筒图标
    if (_aiUserId != null && _remoteAudioVolumes.containsKey(_aiUserId)) {
      setState(() {
        _isSpeaking = _remoteAudioVolumes[_aiUserId]! > 5;
      });
    }

    // 如果是最终字幕且没有临时字幕，直接添加为新消息
    if (isFinal && !_hasPendingSubtitle) {
      if (_debugMode) {
        debugPrint('【字幕】添加新的最终字幕消息: $text');
      }
      _addAiMessage(text, isFinal: true);
      return;
    }

    // 如果是第一个临时字幕，创建新消息
    if (!_hasPendingSubtitle) {
      _currentAiMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      _addAiMessage(text, isFinal: false, messageId: _currentAiMessageId);
      _hasPendingSubtitle = true;
      if (_debugMode) {
        debugPrint('【字幕】添加新的临时字幕消息: $text');
      }
      return;
    }

    // 如果已有临时字幕，更新现有消息
    if (_hasPendingSubtitle && _currentAiMessageId != null) {
      _updateAiMessage(text, isFinal: isFinal, messageId: _currentAiMessageId!);

      if (_debugMode && isFinal) {
        debugPrint('【字幕】更新为最终字幕: $text');
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

  // 将网络质量数值转换为可读字符串
  String _getNetworkQualityString(int? quality) {
    switch (quality) {
      case 0:
        return '未知';
      case 1:
        return '极好';
      case 2:
        return '良好';
      case 3:
        return '一般';
      case 4:
        return '较差';
      case 5:
        return '很差';
      case 6:
        return '不可用';
      default:
        return '未知';
    }
  }

  // 将连接状态数值转换为可读字符串
  String _getConnectionStateString(int? state) {
    switch (state) {
      case 1:
        return '正在连接';
      case 2:
        return '已连接';
      case 3:
        return '重新连接中';
      case 4:
        return '连接失败';
      case 5:
        return '已断开';
      default:
        return '未连接';
    }
  }

  // 开始或停止收集媒体统计数据
  void _toggleStatsCollection() {
    setState(() {
      _showStatsPanel = !_showStatsPanel;
    });

    if (_showStatsPanel) {
      // 开始定时收集统计数据
      _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _collectMediaStats();
      });
      _collectMediaStats(); // 立即收集一次
    } else {
      // 停止定时收集
      _statsTimer?.cancel();
      _statsTimer = null;
    }
  }

  // 收集媒体统计数据
  Future<void> _collectMediaStats() async {
    try {
      // 由于插件可能未实现getMediaStats方法，我们使用模拟数据
      // 实际使用时应替换为真实的API调用: final stats = await RtcAigcPlugin.getMediaStats();

      // 模拟数据
      final stats = {
        'rtt': (_rtt += (Random().nextInt(5) - 2)).clamp(20, 500),
        'packetsLost': _packetsLost += Random().nextInt(3),
        'packetLossRate':
            (_packetLossRate + (Random().nextDouble() * 0.01 - 0.005))
                .clamp(0.0, 1.0),
        'bitrate': (_bitrate += (Random().nextInt(20) - 10)).clamp(10, 500),
        'audioLevel': (_audioLevel += (Random().nextInt(10) - 5)).clamp(0, 100),
        'frameRate': (_frameRate += (Random().nextInt(2) - 1)).clamp(15, 30),
      };

      setState(() {
        _mediaStats = stats;
      });

      if (_debugMode) {
        debugPrint(
            '【媒体统计】收集到新的媒体统计数据: ${_mediaStats.toString().substring(0, min(100, _mediaStats.toString().length))}...');
      }
    } catch (e) {
      debugPrint('【错误】获取媒体统计失败: $e');
    }
  }

  // 构建统计面板
  Widget _buildStatsPanel() {
    if (!_showStatsPanel) return const SizedBox.shrink();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('实时统计', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: _toggleStatsCollection,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: '网络'),
              Tab(text: '媒体'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNetworkStatsView(),
                _buildMediaStatsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 网络统计视图
  Widget _buildNetworkStatsView() {
    final rtt = _mediaStats['rtt'] ?? 0;
    final packetsLost = _mediaStats['packetsLost'] ?? 0;
    final packetLossRate = _mediaStats['packetLossRate'] ?? 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildStatItem('网络质量', _networkQuality),
        _buildStatItem('连接状态', _connectionState),
        _buildStatItem('往返时延 (RTT)', '$rtt ms'),
        _buildStatItem('丢包数', '$packetsLost'),
        _buildStatItem('丢包率', '${(packetLossRate * 100).toStringAsFixed(2)}%'),
      ],
    );
  }

  // 媒体统计视图
  Widget _buildMediaStatsView() {
    final bitrate = _mediaStats['bitrate'] ?? 0;
    final audioLevel = _mediaStats['audioLevel'] ?? 0;
    final frameRate = _mediaStats['frameRate'] ?? 0;

    final localVolume = _localAudioVolume;
    final aiVolume =
        _aiUserId != null ? _remoteAudioVolumes[_aiUserId] ?? 0 : 0;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildStatItem('本地音量', '$localVolume'),
        _buildStatItem('AI音量', '$aiVolume'),
        _buildStatItem('比特率', '$bitrate kbps'),
        _buildStatItem('音频电平', '$audioLevel'),
        _buildStatItem('帧率', '$frameRate fps'),
      ],
    );
  }

  // 构建统计项
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
    return Stack(
      children: [
        Column(
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

            // 字幕显示 - 仅在没有临时字幕显示在聊天列表时且AI正在说话时显示
            if (!_hasPendingSubtitle && _isSpeaking)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: local_widgets.SubtitleView(
                  text: _currentSubtitle,
                  isFinal: _isSubtitleFinal,
                  isThinking: _isSpeaking,
                  onInterrupt: _interruptConversation,
                ),
              ),

            // 消息输入区域
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 统计按钮
                  IconButton(
                    icon: Icon(
                      Icons.bar_chart,
                      color: _showStatsPanel ? Colors.blue : Colors.grey,
                    ),
                    onPressed: _toggleStatsCollection,
                    tooltip: '统计面板',
                    padding: EdgeInsets.zero,
                  ),

                  const SizedBox(width: 8),

                  // 输入框
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: _isConversationActive ? _sendMessage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
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

        // 统计面板 (在底部)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildStatsPanel(),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        // 使用更新后的AI状态卡片
        _buildAiStatusCard(),

        // 房间控制卡片保持不变
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

        // 使用更新的调试工具卡片
        _buildDebugToolsCard(),
      ],
    );
  }

  // 更新AI状态卡片，添加音频相关信息
  Widget _buildAiStatusCard() {
    final aiVolume =
        _aiUserId != null ? _remoteAudioVolumes[_aiUserId] ?? 0 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI状态', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4.0),
            _buildStatusItem('AI用户ID', _aiUserId ?? '未加入'),
            _buildStatusItem('音频采集', _isAiAudioCaptureStarted ? '已开始' : '未开始'),
            _buildStatusItem('媒体发布', _isAiPublished ? '已发布' : '未发布'),
            _buildStatusItem('AI音量', '$aiVolume'),
            if (_debugMode)
              _buildStatusItem('字幕回调', '$_subtitleCallbackCount 次'),
          ],
        ),
      ),
    );
  }

  // 更新状态面板，添加网络和连接状态信息
  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade200,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text('状态: $_status', overflow: TextOverflow.ellipsis)),
              Text('对话: ${_isConversationActive ? '进行中' : '未开始'}'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI: ${_aiUserId != null ? '已加入' : '未加入'}'),
              Text('音频: ${_isAiAudioCaptureStarted ? '已开始' : '未开始'}'),
              Text('网络: $_networkQuality'),
            ],
          ),
          if (_debugMode)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('本地音量: $_localAudioVolume'),
                Text('连接: $_connectionState'),
                Text('AI说话: ${_isSpeaking ? '是' : '否'}'),
              ],
            ),
        ],
      ),
    );
  }

  // 更新消息项的构建
  Widget _buildMessageItem(RtcAigcMessage message) {
    final isUser = message.isUser ?? false;
    final isSystem = message.type == MessageType.system;

    // 检查是否为临时字幕
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像和状态指示
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: isUser ? Colors.blue : Colors.green,
                child: Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  color: Colors.white,
                ),
              ),
              if (!isUser && _isSpeaking && !isTemporarySubtitle)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.mic,
                      size: 12,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8.0),

          // 消息内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称和状态指示
                Row(
                  children: [
                    Text(
                      isUser ? '我' : 'AI助手',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    if (!isUser && _aiUserId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          _aiUserId!.substring(0, min(8, _aiUserId!.length)),
                          style: TextStyle(
                              fontSize: 10, color: Colors.green.shade800),
                        ),
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
                                  TextStyle(fontSize: 10.0, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // 消息文本
                const SizedBox(height: 4.0),
                Text(
                  message.text ?? '',
                  style: TextStyle(
                    fontStyle: isTemporarySubtitle
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontSize: 15.0,
                    height: 1.3,
                  ),
                ),

                // 时间戳和状态
                const SizedBox(height: 4.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        fontSize: 10.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (!isUser && isTemporarySubtitle) ...[
                      const SizedBox(width: 4.0),
                      Icon(
                        Icons.flash_on,
                        size: 12.0,
                        color: Colors.blue.shade300,
                      ),
                    ] else if (!isUser && !isTemporarySubtitle) ...[
                      const SizedBox(width: 4.0),
                      Icon(
                        Icons.check_circle_outline,
                        size: 12.0,
                        color: Colors.green.shade300,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 格式化时间戳
  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
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
          if (!_isConversationActive) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startConversation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('开始对话'),
            ),
          ],
        ],
      ),
    );
  }

  // 更新调试工具卡片，添加统计功能
  Card _buildDebugToolsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('调试工具', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleDebugMode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _debugMode ? Colors.green : Colors.grey,
                    ),
                    child: Text(_debugMode ? '关闭调试模式' : '开启调试模式'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleStatsCollection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _showStatsPanel ? Colors.orange : Colors.grey,
                    ),
                    child: Text(_showStatsPanel ? '关闭统计' : '显示统计'),
                  ),
                ),
              ],
            ),
            if (_debugMode) ...[
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: () {
                  _addSystemMessage('字幕统计: 总计 $_subtitleCallbackCount 条字幕回调');
                  _addSystemMessage('网络状态: $_networkQuality');
                  _addSystemMessage('连接状态: $_connectionState');
                  if (_aiUserId != null) {
                    _addSystemMessage(
                        'AI音量: ${_remoteAudioVolumes[_aiUserId] ?? 0}');
                  }
                },
                child: const Text('状态信息'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
