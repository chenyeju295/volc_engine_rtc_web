import 'package:flutter/material.dart';
import 'package:volc_engine_rtc_web/rtc_aigc_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTC AIGC Plugin Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AigcDemoPage(),
    );
  }
}

class AigcDemoPage extends StatefulWidget {
  const AigcDemoPage({Key? key}) : super(key: key);

  @override
  State<AigcDemoPage> createState() => _AigcDemoPageState();
}

class _AigcDemoPageState extends State<AigcDemoPage> {
  bool _initialized = false;
  bool _isTalking = false;
  String _userText = '';
  String _aiResponse = '';
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  @override
  void dispose() {
    RtcAigcPlugin.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initializePlugin() async {
    try {
      await RtcAigcPlugin.initialize(
        appId: '67eb953062b4b601a6df1348',
        roomId: 'Room1',
        userId: 'User1',
        token:
            '00167eb953062b4b601a6df1348QAA4fD0CKSXuZ6lf92cFAFJvb20xBQBVc2VyMQYAAACpX/dnAQCpX/dnAgCpX/dnAwCpX/dnBACpX/dnBQCpX/dnIAC23njJVyLuI4ijYPYbGUobDb0HsShfEPP0P4ZRu4wuWg==',
        asrAppId: '4799544484',
        ttsAppId: '4799544484',
        serverUrl: 'http://localhost:3001',
        arkModelId: 'ep-20250401160533-rr59m',
        onUserSpeechRecognized: (text) {
          setState(() {
            _userText = text;
          });
        },
        onAiResponseReceived: (text) {
          setState(() {
            _aiResponse = text;
          });
        },
        onSpeechStateChanged: (isActive) {
          setState(() {
            _isTalking = isActive;
          });
        },
      );

      setState(() {
        _initialized = true;
      });

      debugPrint('Plugin initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize plugin: $e');
    }
  }

  Future<void> _startConversation() async {
    if (!_initialized) return;

    try {
      final success = await RtcAigcPlugin.startConversation();

      if (success) {
        debugPrint('Conversation started successfully');
      } else {
        debugPrint('Failed to start conversation');
      }
    } catch (e) {
      debugPrint('Error starting conversation: $e');
    }
  }

  Future<void> _stopConversation() async {
    if (!_initialized) return;

    try {
      await RtcAigcPlugin.stopConversation();
      debugPrint('Conversation stopped');
    } catch (e) {
      debugPrint('Error stopping conversation: $e');
    }
  }

  Future<void> _sendTextMessage() async {
    if (!_initialized || _textController.text.isEmpty) return;

    try {
      final message = _textController.text;
      await RtcAigcPlugin.sendTextMessage(message);

      setState(() {
        _userText = message;
        _textController.clear();
      });

      debugPrint('Text message sent: $message');
    } catch (e) {
      debugPrint('Error sending text message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIGC Demo'),
      ),
      body: _initialized
          ? _buildConversationUI()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildConversationUI() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice conversation controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _startConversation,
                icon: const Icon(Icons.mic),
                label: const Text('Start Talking'),
              ),
              ElevatedButton.icon(
                onPressed: _stopConversation,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Talking'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Text chat input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendTextMessage,
                icon: const Icon(Icons.send),
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Conversation display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(_userText.isEmpty ? '(No input yet)' : _userText),
                  const SizedBox(height: 24),
                  Text(
                    'AI:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(_aiResponse.isEmpty
                                ? '(Waiting for response...)'
                                : _aiResponse),
                          ),
                          if (_isTalking)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.volume_up,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
