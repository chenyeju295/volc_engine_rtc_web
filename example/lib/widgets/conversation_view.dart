import 'dart:async';
import 'package:flutter/material.dart';

class ConversationView extends StatefulWidget {
  final Stream<Map<String, dynamic>> messageHistoryStream;
  final Stream<Map<String, dynamic>> stateStream;
  final String userId;
  final String botId;
  final Function() onInterrupt;

  const ConversationView({
    Key? key,
    required this.messageHistoryStream,
    required this.stateStream,
    required this.userId,
    required this.botId,
    required this.onInterrupt,
  }) : super(key: key);

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final List<Map<String, dynamic>> _messages = [];
  bool _isThinking = false;
  bool _isTalking = false;
  String _currentSubtitle = '';
  bool _isSubtitleFinal = false;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // 订阅消息历史流
    _messageSubscription = widget.messageHistoryStream.listen((message) {
      setState(() {
        if (message['userId'] == widget.botId && !message['isFinal']) {
          // 对于AI的非最终消息，更新当前字幕
          _currentSubtitle = message['text'];
          _isSubtitleFinal = false;
        } else if (message['userId'] == widget.botId && message['isFinal']) {
          // 对于AI的最终消息，添加到消息列表并清空当前字幕
          _messages.add(message);
          _currentSubtitle = '';
          _isSubtitleFinal = true;
        } else {
          // 对于其他消息，直接添加到列表
          _messages.add(message);
        }
      });
      
      // 滚动到底部
      _scrollToBottom();
    });

    // 订阅状态流
    _stateSubscription = widget.stateStream.listen((state) {
      setState(() {
        _isThinking = state['isThinking'] ?? false;
        _isTalking = state['isTalking'] ?? false;
      });
    });
  }

  void _scrollToBottom() {
    // 确保在视图构建完成后滚动
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

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          // 主消息列表区域
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),
          
          // 字幕显示区域
          if (_currentSubtitle.isNotEmpty || _isThinking)
            _buildSubtitleArea(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final isUser = message['userId'] == widget.userId;
    final isSystem = message['userId'] == 'system';
    
    // 系统消息显示为居中信息
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              message['text'],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(false),
          const SizedBox(width: 8.0),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text(message['text']),
            ),
          ),
          const SizedBox(width: 8.0),
          if (isUser) _buildAvatar(true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      backgroundColor: isUser ? Colors.blue.shade700 : Colors.green.shade700,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildSubtitleArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(false),
              const SizedBox(width: 8.0),
              Text(
                _isThinking ? "思考中..." : "正在说话...",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isTalking)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                  onPressed: widget.onInterrupt,
                  tooltip: '打断',
                ),
            ],
          ),
          if (_currentSubtitle.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8.0, left: 40.0),
              child: Text(
                _currentSubtitle,
                style: TextStyle(
                  color: Colors.black87,
                  fontStyle: _isSubtitleFinal ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          if (_isThinking && _currentSubtitle.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8.0, left: 40.0),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
