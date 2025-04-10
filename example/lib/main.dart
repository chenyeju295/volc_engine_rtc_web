import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rtc_aigc_plugin/rtc_aigc_plugin.dart';
import 'package:rtc_aigc_plugin/src/config/config.dart';
import 'conversation_demo.dart'; // 导入会话演示页面
import 'widgets/subtitle_view.dart' as local_widgets;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: RtcAigcDemo(),
    );
  }
}

class RtcAigcDemo extends StatefulWidget {
  const RtcAigcDemo({super.key});

  @override
  State<RtcAigcDemo> createState() => _RtcAigcDemoState();
}

class _RtcAigcDemoState extends State<RtcAigcDemo> {
  String _status = 'Not initialized';
  final List<String> _messages = [];
  bool _isInitialized = false;
  bool _isConversationActive = false;
  bool _isSpeaking = false;

  // 字幕相关状态
  String _currentSubtitle = '';
  bool _isSubtitleFinal = false;

  // 订阅处理
  StreamSubscription? _subtitleSubscription;
  StreamSubscription? _audioStatusSubscription;

  // Audio device states
  List<Map<String, String>> _audioInputDevices = [];
  List<Map<String, String>> _audioOutputDevices = [];
  String? _selectedAudioInputId;
  String? _selectedAudioOutputId;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _subtitleSubscription?.cancel();
    _audioStatusSubscription?.cancel();
    RtcAigcPlugin.dispose();
    _messageController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _status = 'Initializing...';
    });

    try {
      // 创建ASR配置
      final asrConfig = AsrConfig(
        appId: '4799544484', // 需要替换为您的ASR AppID
        cluster: 'volcengine_streaming_common',
      );

      // 创建TTS配置
      final ttsConfig = TtsConfig(
        appId: '4799544484', // 需要替换为您的TTS AppID
        voiceType: 'volcano_tts',
      );

      // 创建LLM配置
      final llmConfig = LlmConfig(
        modelName: 'ArkV3',
        endPointId: 'ep-20250401160533-rr59m', // 需要替换为您的EndPointID
        maxTokens: 1024,
        temperature: 0.1,
        topP: 0.3,
        systemMessages: ["你是小宁，性格幽默又善解人意。你在表达时需简明扼要，有自己的观点。"],
        userMessages: [
          "user:\"你是谁\"",
          "assistant:\"我是问答助手\"",
        ],
        historyLength: 3,
      );

      final success = await RtcAigcPlugin.initialize(
        appId: '67eb953062b4b601a6df1348', // 替换为您的APP ID
        roomId: 'room1', // 房间ID
        userId: 'user1', // 用户ID
        taskId: 'user1',
        token:
            '00167eb953062b4b601a6df1348QAAId6gE4FHzZ2CM/GcFAHJvb20xBQB1c2VyMQYAAABgjPxnAQBgjPxnAgBgjPxnAwBgjPxnBABgjPxnBQBgjPxnIACiJ43l8vpJTdIYqpqovQOKogW6NBmuyd0jEmubjbCR8Q==', // 替换为您的Token
        serverUrl: "http://localhost:3001",
        asrConfig: asrConfig,
        ttsConfig: ttsConfig,
        llmConfig: llmConfig,
        onStateChange: _handleStateChange,
        onMessage: _handleMessage,
        onAudioStatusChange: _handleAudioStatusChange,
        onSubtitle: _handleSubtitle,
      );

      if (success) {
        setState(() {
          _status = 'Initialized';
          _isInitialized = true;
        });
      } else {
        setState(() {
          _status = 'Initialization failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _startConversation() async {
    if (!_isInitialized) return;

    setState(() {
      _status = 'Starting conversation...';
    });

    try {
      final success = await RtcAigcPlugin.startConversation(
        welcomeMessage: 'Hello, how can I help you today?',
      );

      if (success) {
        setState(() {
          _status = 'Conversation active';
          _isConversationActive = true;
        });
      } else {
        setState(() {
          _status = 'Failed to start conversation';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _stopConversation() async {
    if (!_isInitialized || !_isConversationActive) return;

    setState(() {
      _status = 'Stopping conversation...';
    });

    try {
      final success = await RtcAigcPlugin.stopConversation();

      setState(() {
        _status =
            success ? 'Conversation stopped' : 'Failed to stop conversation';
        _isConversationActive = false;
        _currentSubtitle = '';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isConversationActive = false;
      });
    }
  }

  Future<void> _muteAudio() async {
    if (!_isInitialized || !_isConversationActive) return;

    try {
      await RtcAigcPlugin.muteAudio(true);
      setState(() {
        _status = 'Audio muted';
      });
    } catch (e) {
      setState(() {
        _status = 'Error muting audio: $e';
      });
    }
  }

  Future<void> _unmuteAudio() async {
    if (!_isInitialized || !_isConversationActive) return;

    try {
      await RtcAigcPlugin.muteAudio(false);
      setState(() {
        _status = 'Audio unmuted';
      });
    } catch (e) {
      setState(() {
        _status = 'Error unmuting audio: $e';
      });
    }
  }

  Future<void> _joinRoom() async {
    if (!_isInitialized) return;

    setState(() {
      _status = '正在加入房间...';
    });

    try {
      final success = await RtcAigcPlugin.joinRoom(
          // 可以传递参数来覆盖初始化时的设置
          // roomId: 'custom_room_id',
          // userId: 'custom_user_id',
          // token: 'custom_token',
          );

      setState(() {
        if (success) {
          _status = '已成功加入房间';
          // 添加一条系统消息
          _messages.add('系统: 已成功加入房间');
        } else {
          _status = '加入房间失败';
        }
      });
    } catch (e) {
      setState(() {
        _status = '加入房间出错: $e';
      });
    }
  }

  void _handleStateChange(String state, String? message) {
    setState(() {
      _status = '$state ${message != null ? ': $message' : ''}';
    });
  }

  void _handleMessage(String text, bool isUser) {
    setState(() {
      _messages.add('${isUser ? 'You' : 'AI'}: $text');
    });
  }

  void _handleAudioStatusChange(bool isPlaying) {
    setState(() {
      _isSpeaking = isPlaying;
    });
  }

  void _handleSubtitle(Map<String, dynamic> subtitle) {
    final text = subtitle['text'] as String? ?? '';
    final isFinal = subtitle['isFinal'] as bool? ?? false;

    setState(() {
      _currentSubtitle = text;
      _isSubtitleFinal = isFinal;
    });
  }

  Future<void> _refreshAudioDevices() async {
    try {
      // 获取音频输入设备列表
      final inputDevices = await RtcAigcPlugin.getAudioInputDevices();

      // 获取音频输出设备列表
      final outputDevices = await RtcAigcPlugin.getAudioOutputDevices();

      // 获取当前选中的设备
      final currentInputId = await RtcAigcPlugin.getCurrentAudioInputDevice();
      final currentOutputId = await RtcAigcPlugin.getCurrentAudioOutputDevice();

      setState(() {
        _audioInputDevices = inputDevices;
        _audioOutputDevices = outputDevices;
        _selectedAudioInputId = currentInputId;
        _selectedAudioOutputId = currentOutputId;
      });
    } catch (e) {
      print('Error refreshing audio devices: $e');
    }
  }

  Future<void> _setAudioInputDevice(String deviceId) async {
    try {
      final success = await RtcAigcPlugin.setAudioInputDevice(deviceId);
      if (success) {
        setState(() {
          _selectedAudioInputId = deviceId;
        });
      }
    } catch (e) {
      print('Error setting audio input device: $e');
    }
  }

  Future<void> _setAudioOutputDevice(String deviceId) async {
    try {
      final success = await RtcAigcPlugin.setAudioOutputDevice(deviceId);
      if (success) {
        setState(() {
          _selectedAudioOutputId = deviceId;
        });
      }
    } catch (e) {
      print('Error setting audio output device: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (!_isInitialized || !_isConversationActive) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await RtcAigcPlugin.sendTextMessage(message);
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _status = 'Error sending message: $e';
      });
    }
  }

  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '控制面板',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isInitialized ? _joinRoom : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInitialized ? Colors.blue : Colors.grey,
                  ),
                  child: const Text('加入房间'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && !_isConversationActive
                      ? _startConversation
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInitialized && !_isConversationActive
                        ? Colors.green
                        : Colors.grey,
                  ),
                  child: const Text('开始对话'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && _isConversationActive
                      ? _stopConversation
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInitialized && _isConversationActive
                        ? Colors.red
                        : Colors.grey,
                  ),
                  child: const Text('结束对话'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isInitialized && _isConversationActive
                      ? _muteAudio
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInitialized && _isConversationActive
                        ? Colors.orange
                        : Colors.grey,
                  ),
                  child: const Text('静音'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && _isConversationActive
                      ? _unmuteAudio
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInitialized && _isConversationActive
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  child: const Text('取消静音'),
                ),
                // 添加TTS测试按钮
                ElevatedButton(
                  onPressed: _isInitialized ? _testTTS : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isInitialized ? Colors.purple : Colors.grey,
                  ),
                  child: const Text('测试TTS'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 测试TTS功能（现通过AIGC服务实现）
  Future<void> _testTTS() async {
    setState(() {
      _status = '正在测试TTS...';
    });

    try {
      setState(() {
        _status = '注意：独立TTS功能已移除，请通过startConversation使用TTS';
      });

      // 使用AIGC服务进行TTS测试
      final success = await RtcAigcPlugin.startConversation(
        welcomeMessage: "您好，我是语音助手，很高兴为您服务！",
      );

      if (success) {
        setState(() {
          _status = '会话已启动，播放欢迎语音';
        });

        // 等待3秒后发送测试文本
        await Future.delayed(const Duration(seconds: 3));

        // 发送测试消息让AI说话
        await RtcAigcPlugin.sendTextMessage("请念一段测试语音，用于验证TTS功能。");
        setState(() {
          _status = 'TTS测试消息已发送';
        });

        // 5秒后停止会话
        await Future.delayed(const Duration(seconds: 5));
        // await RtcAigcPlugin.stopConversation();
        setState(() {
          _status = 'TTS测试完成，会话已停止';
        });
      } else {
        setState(() {
          _status = 'TTS测试失败：无法启动会话';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'TTS测试错误: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTC AIGC Demo'),
        actions: [
          // 添加按钮导航到高级会话演示页面
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: '高级会话演示',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ConversationDemo(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isInitialized)
              ElevatedButton(
                onPressed: _initialize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                child: const Text('初始化 SDK', style: TextStyle(fontSize: 16)),
              ),

            Text('Status: $_status'),
            const SizedBox(height: 16),

            if (_isInitialized) _buildControlPanel(),

            const SizedBox(height: 16),
            // 添加测试AI字幕按钮
            if (_isInitialized)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const Text('AI字幕测试',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _testInterimSubtitle,
                          child: const Text('测试临时字幕'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _testFinalSubtitle,
                          child: const Text('测试最终字幕'),
                        ),
                      ),
                    ],
                  ),
                  if (_currentSubtitle.isNotEmpty)
                    local_widgets.SubtitleView(
                      text: _currentSubtitle,
                      isFinal: _isSubtitleFinal,
                      isThinking: !_isSubtitleFinal && _currentSubtitle.isEmpty,
                      onInterrupt: _isInitialized && _isConversationActive
                          ? () => RtcAigcPlugin.stopConversation()
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // 测试临时字幕
  void _testInterimSubtitle() async {
    try {
      await RtcAigcPlugin.testAISubtitle(
        text: '这是一段测试的临时字幕文本，AI正在思考和生成回答内容。这段文本可以实时更新以反映思维过程。',
        isFinal: false,
      );
    } catch (e) {
      debugPrint('测试临时字幕失败: $e');
    }
  }

  // 测试最终字幕
  void _testFinalSubtitle() async {
    try {
      await RtcAigcPlugin.testAISubtitle(
        text: '这是一段测试的最终字幕文本。显示为绿色表示AI已完成回答，代表最终确认的内容。您可以继续对话了。',
        isFinal: true,
      );
    } catch (e) {
      debugPrint('测试最终字幕失败: $e');
    }
  }
}
