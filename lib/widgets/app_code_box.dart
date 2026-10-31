import 'package:flutter/material.dart';

/// 等宽只读文本框：日志 / Base64 连接信息 / 备份 JSON 共用。
///
/// 三处原来各写一份同样的底色、圆角与字号。默认限高 260，避免一串
/// 备份 JSON 把整页撑到几千像素（调试卡原来没有这个限制）。
class AppCodeBox extends StatelessWidget {
  final String text;
  final double? maxHeight;

  const AppCodeBox({
    super.key,
    required this.text,
    this.maxHeight = 260,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: maxHeight == null
          ? const BoxConstraints()
          : BoxConstraints(maxHeight: maxHeight!),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
