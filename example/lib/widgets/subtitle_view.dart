import 'package:flutter/material.dart';

/// 字幕显示组件
/// 
/// 用于显示AI实时字幕，支持临时字幕和最终字幕的不同样式
class SubtitleView extends StatelessWidget {
  /// 字幕文本
  final String text;
  
  /// 是否为最终字幕
  final bool isFinal;
  
  /// 是否显示思考状态（无文本时）
  final bool isThinking;
  
  /// 打断回答回调
  final VoidCallback? onInterrupt;
  
  /// 自定义样式
  final SubtitleViewStyle? style;

  const SubtitleView({
    Key? key,
    required this.text,
    this.isFinal = false,
    this.isThinking = false,
    this.onInterrupt,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 如果没有文本且不处于思考状态，则不显示
    if (text.isEmpty && !isThinking) {
      return const SizedBox.shrink();
    }

    final effectiveStyle = style ?? SubtitleViewStyle();
    
    return AnimatedContainer(
      duration: effectiveStyle.animationDuration,
      curve: effectiveStyle.animationCurve,
      margin: effectiveStyle.margin,
      padding: effectiveStyle.padding,
      decoration: BoxDecoration(
        color: isFinal
            ? effectiveStyle.finalBackgroundColor
            : effectiveStyle.progressBackgroundColor,
        borderRadius: effectiveStyle.borderRadius,
        border: Border.all(
          color: isFinal 
              ? effectiveStyle.finalBorderColor
              : effectiveStyle.progressBorderColor,
          width: effectiveStyle.borderWidth,
        ),
        boxShadow: [
          if (effectiveStyle.enableShadow)
            BoxShadow(
              color: (isFinal 
                  ? effectiveStyle.finalBorderColor 
                  : effectiveStyle.progressBorderColor).withOpacity(0.2),
              blurRadius: effectiveStyle.shadowBlurRadius,
              offset: effectiveStyle.shadowOffset,
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(effectiveStyle),
          if (text.isNotEmpty) 
            ..._buildContent(effectiveStyle),
          if (text.isEmpty && isThinking) 
            _buildThinkingIndicator(effectiveStyle),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(SubtitleViewStyle style) {
    return Row(
      children: [
        // AI头像
        CircleAvatar(
          radius: style.avatarRadius,
          backgroundColor: isFinal 
              ? style.finalAvatarColor 
              : style.progressAvatarColor,
          child: Icon(
            Icons.smart_toy,
            color: Colors.white,
            size: style.avatarIconSize,
          ),
        ),
        
        SizedBox(width: style.headerSpacing),
        
        // 状态文本
        Text(
          isFinal ? style.finalStatusText : style.progressStatusText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFinal
                ? style.finalTextColor
                : style.progressTextColor,
            fontSize: style.statusTextSize,
          ),
        ),
        
        const Spacer(),
        
        // 正在进行中的指示器或打断按钮
        if (!isFinal && isThinking)
          SizedBox(
            width: style.indicatorSize, 
            height: style.indicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: style.indicatorStrokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(
                style.progressTextColor
              ),
            ),
          )
        else if (!isFinal && text.isNotEmpty && onInterrupt != null)
          IconButton(
            icon: Icon(
              Icons.stop_circle_outlined, 
              color: style.interruptColor,
              size: style.interruptIconSize,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onInterrupt,
            tooltip: '打断',
          ),
      ],
    );
  }

  /// 构建内容区域
  List<Widget> _buildContent(SubtitleViewStyle style) {
    return [
      SizedBox(height: style.contentSpacing),
      AnimatedDefaultTextStyle(
        duration: style.animationDuration,
        style: TextStyle(
          fontSize: style.contentTextSize,
          height: style.contentLineHeight,
          fontStyle: isFinal
              ? FontStyle.normal
              : FontStyle.italic,
          color: isFinal
              ? style.finalContentTextColor
              : style.progressContentTextColor,
        ),
        child: Text(text),
      ),
    ];
  }

  /// 构建思考中指示器
  Widget _buildThinkingIndicator(SubtitleViewStyle style) {
    return Container(
      margin: EdgeInsets.only(top: style.contentSpacing, left: style.avatarRadius * 2),
      child: Row(
        children: [
          _buildDot(0, style),
          _buildDot(1, style),
          _buildDot(2, style),
        ],
      ),
    );
  }
  
  /// 构建动态思考点
  Widget _buildDot(int index, SubtitleViewStyle style) {
    return Container(
      width: style.thinkingDotSize,
      height: style.thinkingDotSize,
      margin: EdgeInsets.only(right: style.thinkingDotSpacing),
      decoration: BoxDecoration(
        color: style.progressTextColor.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.5, end: 1.0),
        duration: Duration(milliseconds: 600 + (index * 200)),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: value,
              child: child,
            ),
          );
        },
        child: const SizedBox(),
      ),
    );
  }
}

/// 字幕视图样式配置
class SubtitleViewStyle {
  // 动画相关
  final Duration animationDuration;
  final Curve animationCurve;
  
  // 布局相关
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final bool enableShadow;
  
  // 头像相关
  final double avatarRadius;
  final double avatarIconSize;
  
  // 间距相关
  final double headerSpacing;
  final double contentSpacing;
  
  // 进度相关
  final double indicatorSize;
  final double indicatorStrokeWidth;
  final double interruptIconSize;
  
  // 文本相关
  final double statusTextSize;
  final double contentTextSize;
  final double contentLineHeight;
  
  // 思考动画相关
  final double thinkingDotSize;
  final double thinkingDotSpacing;
  
  // 进行中状态颜色
  final Color progressBackgroundColor;
  final Color progressBorderColor;
  final Color progressAvatarColor;
  final Color progressTextColor;
  final Color progressContentTextColor;
  
  // 最终状态颜色
  final Color finalBackgroundColor;
  final Color finalBorderColor;
  final Color finalAvatarColor;
  final Color finalTextColor;
  final Color finalContentTextColor;
  
  // 交互颜色
  final Color interruptColor;
  
  // 文本
  final String progressStatusText;
  final String finalStatusText;
  
  /// 默认样式构造函数
  SubtitleViewStyle({
    // 动画
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
    
    // 布局
    this.margin = const EdgeInsets.only(top: 16, bottom: 8),
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.borderWidth = 1.0,
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(0, 1),
    this.enableShadow = false,
    
    // 头像
    this.avatarRadius = 14.0,
    this.avatarIconSize = 14.0,
    
    // 间距
    this.headerSpacing = 8.0,
    this.contentSpacing = 12.0,
    
    // 指示器
    this.indicatorSize = 12.0,
    this.indicatorStrokeWidth = 2.0,
    this.interruptIconSize = 18.0,
    
    // 文本
    this.statusTextSize = 14.0,
    this.contentTextSize = 16.0,
    this.contentLineHeight = 1.5,
    
    // 思考动画
    this.thinkingDotSize = 6.0,
    this.thinkingDotSpacing = 4.0,
    
    // 进行中状态颜色
    this.progressBackgroundColor = const Color(0xFFF5F5F5),
    this.progressBorderColor = Colors.blue,
    this.progressAvatarColor = Colors.green,
    this.progressTextColor = Colors.blue,
    this.progressContentTextColor = const Color(0xFF757575),
    
    // 最终状态颜色
    this.finalBackgroundColor = Colors.white,
    this.finalBorderColor = Colors.green,
    this.finalAvatarColor = Colors.green,
    this.finalTextColor = Colors.green,
    this.finalContentTextColor = const Color(0xFF212121),
    
    // 交互颜色
    this.interruptColor = Colors.red,
    
    // 文本
    this.progressStatusText = "输入中...",
    this.finalStatusText = "AI 回复",
  });
  
  /// 创建深色模式样式
  factory SubtitleViewStyle.dark() {
    return SubtitleViewStyle(
      progressBackgroundColor: const Color(0xFF263238),
      progressBorderColor: Colors.lightBlue,
      progressTextColor: Colors.lightBlue,
      progressContentTextColor: const Color(0xFFBDBDBD),
      
      finalBackgroundColor: const Color(0xFF1B3A27),
      finalBorderColor: Colors.lightGreen,
      finalTextColor: Colors.lightGreen,
      finalContentTextColor: const Color(0xFFE0E0E0),
    );
  }
} 