import 'dart:async';
import 'package:flutter/material.dart';

/// 实时字幕显示控件
/// 可以显示AI对话的字幕，包括临时和最终字幕
class SubtitleView extends StatefulWidget {
  /// 字幕流
  final Stream<Map<String, dynamic>?> subtitleStream;

  /// 最大显示行数
  final int maxLines;

  /// 字体大小
  final double fontSize;

  /// 文字颜色
  final Color textColor;

  /// 背景颜色
  final Color? backgroundColor;

  /// 高亮颜色 (用于最终文本)
  final Color finalTextColor;

  /// 是否显示临时字幕
  final bool showPartialSubtitles;

  /// 创建字幕视图
  const SubtitleView({
    Key? key,
    required this.subtitleStream,
    this.maxLines = 5,
    this.fontSize = 16.0,
    this.textColor = Colors.white,
    this.backgroundColor,
    this.finalTextColor = Colors.white,
    this.showPartialSubtitles = true,
  }) : super(key: key);

  @override
  State<SubtitleView> createState() => _SubtitleViewState();
}

class _SubtitleViewState extends State<SubtitleView> {
  /// 字幕列表
  final List<Map<String, dynamic>> _subtitles = [];
  
  /// 当前临时字幕
  String _currentPartial = '';
  
  /// 流订阅
  StreamSubscription<Map<String, dynamic>?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribeToSubtitles();
  }

  @override
  void didUpdateWidget(SubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitleStream != widget.subtitleStream) {
      _subscription?.cancel();
      _subscribeToSubtitles();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 订阅字幕流
  void _subscribeToSubtitles() {
    _subscription = widget.subtitleStream.listen((subtitle) {
      if (subtitle == null) {
        // 清空字幕
        setState(() {
          _subtitles.clear();
          _currentPartial = '';
        });
        return;
      }

      final text = subtitle['text'] as String? ?? '';
      final isFinal = subtitle['isFinal'] as bool? ?? false;
      final paragraph = subtitle['paragraph'] as bool? ?? false;

      setState(() {
        if (isFinal) {
          // 处理最终字幕
          if (_currentPartial.isNotEmpty) {
            // 用最终文本替换临时文本
            _currentPartial = '';
          }
          
          if (text.isNotEmpty) {
            // 添加最终字幕到列表
            _subtitles.add(subtitle);
            
            // 如果达到最大行数，移除最旧的
            if (_subtitles.length > widget.maxLines) {
              _subtitles.removeAt(0);
            }
          }
          
          // 如果是段落结束，添加一个空行
          if (paragraph) {
            // 可以选择在段落之间添加间隔
          }
        } else if (widget.showPartialSubtitles) {
          // 更新临时字幕
          _currentPartial = text;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示最终字幕
          ..._subtitles.map((subtitle) {
            return Text(
              subtitle['text'] as String? ?? '',
              style: TextStyle(
                fontSize: widget.fontSize,
                color: widget.finalTextColor,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
          
          // 显示临时字幕
          if (_currentPartial.isNotEmpty && widget.showPartialSubtitles)
            Text(
              _currentPartial,
              style: TextStyle(
                fontSize: widget.fontSize,
                color: widget.textColor.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
} 