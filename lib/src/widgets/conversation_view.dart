import 'dart:async';
import 'package:flutter/material.dart';

/// 消息源
enum MessageSource {
  /// 用户消息
  user,
  
  /// AI消息
  ai,
  
  /// 系统消息
  system
}

/// 高级会话视图组件
class ConversationView extends StatefulWidget {
  /// 消息历史流
  final Stream<Map<String, dynamic>> messageHistoryStream;
  
  /// AI状态流
  final Stream<Map<String, dynamic>> stateStream;
  
  /// 用户ID
  final String userId;
  
  /// AI ID
  final String botId;
  
  /// 打断回调
  final VoidCallback? onInterrupt;
  
  /// 是否显示打断按钮
  final bool showInterruptButton;
  
  /// 气泡颜色配置
  final Map<MessageSource, Color> bubbleColors;
  
  /// 文本颜色配置
  final Map<MessageSource, Color> textColors;
  
  /// 显示状态指示器
  final bool showStatusIndicator;
  
  /// 创建一个会话视图
  const ConversationView({
    Key? key,
    required this.messageHistoryStream,
    required this.stateStream,
    required this.userId,
    this.botId = 'BotName001',
    this.onInterrupt,
    this.showInterruptButton = true,
    this.bubbleColors = const {
      MessageSource.user: Color(0xFF2E6AFF),
      MessageSource.ai: Color(0xFFE8F1FF),
      MessageSource.system: Color(0xFFEEEEEE),
    },
    this.textColors = const {
      MessageSource.user: Colors.white,
      MessageSource.ai: Color(0xFF333333),
      MessageSource.system: Color(0xFF666666),
    },
    this.showStatusIndicator = true,
  }) : super(key: key);

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  /// 消息历史
  final List<Map<String, dynamic>> _messages = [];
  
  /// 消息流订阅
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  
  /// 状态流订阅
  StreamSubscription<Map<String, dynamic>>? _stateSubscription;
  
  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();
  
  /// AI状态
  bool _isAIThinking = false;
  bool _isAITalking = false;
  String _aiState = '';
  
  /// AI是否已准备好
  bool _isAIReady = false;

  @override
  void initState() {
    super.initState();
    _subscribeToStreams();
  }
  
  @override
  void didUpdateWidget(ConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageHistoryStream != widget.messageHistoryStream ||
        oldWidget.stateStream != widget.stateStream) {
      _unsubscribe();
      _subscribeToStreams();
    }
  }
  
  @override
  void dispose() {
    _unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 订阅消息和状态流
  void _subscribeToStreams() {
    _messageSubscription = widget.messageHistoryStream.listen(_handleNewMessage);
    _stateSubscription = widget.stateStream.listen(_handleStateChange);
  }
  
  /// 取消订阅
  void _unsubscribe() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
  }
  
  /// 处理新消息
  void _handleNewMessage(Map<String, dynamic> message) {
    _isAIReady = true;
    final userId = message['userId'] as String? ?? '';
    final text = message['text'] as String? ?? '';
    final isFinal = message['isFinal'] as bool? ?? false;
    
    // 确定是更新还是添加
    bool shouldAdd = true;
    
    // 如果历史有消息，检查是否需要更新
    if (_messages.isNotEmpty) {
      final lastMsg = _messages.last;
      
      // 如果是相同发送者的未完成消息，则更新
      if (lastMsg['userId'] == userId && lastMsg['isFinal'] == false) {
        shouldAdd = false;
        setState(() {
          lastMsg['text'] = text;
          lastMsg['isFinal'] = isFinal;
          lastMsg['timestamp'] = message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
        });
      }
    }
    
    // 添加新消息
    if (shouldAdd) {
      setState(() {
        _messages.add({
          ...message,
          'isInterrupted': false, // 初始未打断
        });
      });
    }
    
    // 滚动到底部
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
  
  /// 处理状态变化
  void _handleStateChange(Map<String, dynamic> state) {
    final stateCode = state['state'] as String? ?? '';
    
    setState(() {
      _aiState = stateCode;
      _isAIThinking = state['isThinking'] as bool? ?? false;
      _isAITalking = state['isTalking'] as bool? ?? false;
      
      // 如果是打断状态，标记最后一条AI消息为已打断
      if (stateCode == 'INTERRUPTED' && _messages.isNotEmpty) {
        // 查找最后一条AI消息
        for (int i = _messages.length - 1; i >= 0; i--) {
          if (_messages[i]['userId'] == widget.botId) {
            _messages[i]['isInterrupted'] = true;
            break;
          }
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 状态指示器
        if (widget.showStatusIndicator)
          _buildStatusIndicator(),
          
        // 消息列表
        Expanded(
          child: _isAIReady ? _buildMessageList() : _buildLoadingIndicator(),
        ),
      ],
    );
  }
  
  /// 构建加载提示
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24, 
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text(
            'AI 准备中...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建消息列表
  Widget _buildMessageList() {
    return Stack(
      children: [
        // 消息列表
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // 底部留出打断按钮的空间
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final message = _messages[index];
            final userId = message['userId'] as String? ?? '';
            final isUser = userId == widget.userId;
            final isAI = userId == widget.botId;
            
            // 确定消息源
            final source = isUser ? MessageSource.user : 
                          isAI ? MessageSource.ai : MessageSource.system;
            
            return _buildMessageBubble(message, source);
          },
        ),
        
        // 打断按钮
        if (widget.showInterruptButton && widget.onInterrupt != null && (_isAIThinking || _isAITalking))
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: widget.onInterrupt,
                icon: const Icon(Icons.pan_tool),
                label: const Text('打断AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  /// 构建状态指示器
  Widget _buildStatusIndicator() {
    String statusText = '';
    
    if (_isAIThinking) {
      statusText = 'AI正在思考...';
    } else if (_isAITalking) {
      statusText = 'AI正在说话...';
    } else if (_aiState == 'LISTENING') {
      statusText = 'AI正在聆听...';
    } else if (_aiState == 'INTERRUPTED') {
      statusText = 'AI被打断';
    }
    
    if (statusText.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: Colors.grey[200],
      width: double.infinity,
      child: Row(
        children: [
          if (_isAIThinking || _isAITalking)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isAITalking ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 14.0,
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建消息气泡
  Widget _buildMessageBubble(Map<String, dynamic> message, MessageSource source) {
    final text = message['text'] as String? ?? '';
    final isFinal = message['isFinal'] as bool? ?? false;
    final isInterrupted = message['isInterrupted'] as bool? ?? false;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: source == MessageSource.user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (source != MessageSource.user)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.smart_toy, size: 18, color: Colors.blue),
              ),
            ),
            
          Flexible(
            child: Column(
              crossAxisAlignment: source == MessageSource.user
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: widget.bubbleColors[source],
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: widget.textColors[source],
                          fontSize: 16.0,
                          fontStyle: isFinal ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      
                      // 显示"正在输入"动画
                      if (!isFinal && source == MessageSource.ai)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: _buildTypingIndicator(),
                        ),
                    ],
                  ),
                ),
                
                // 显示"已打断"标签
                if (isInterrupted)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '已打断',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          if (source == MessageSource.user)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[400],
                child: const Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 构建"正在输入"指示器
  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Colors.grey[600],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedOpacity(
              opacity: _isAITalking ? 1.0 : 0.2,
              duration: Duration(milliseconds: 300 + (index * 100)),
              alwaysIncludeSemantics: true,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
} 