import 'package:flutter/material.dart';

import '../config/responsive.dart';

/// 页面统一的滚动容器：外部 16 内边距 + 宽屏限宽居中（[responsiveBody]）。
///
/// 各页原来都要写一遍 `SingleChildScrollView > responsiveBody > Column`，
/// 内边距还各写各的（16/20/24）。现在只有 [padding] 一个变量。
class AppPageBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppPageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: responsiveBody(context, child: child),
    );
  }
}

/// 居中的整页状态视图：图标 + 标题 + 可选说明 + 可选按钮。
///
/// 覆盖原来四份几乎一样的私有实现（未配置 / 加载失败 / 无数据 / 配置缺失）。
/// [error] 只在不正常的状态下传 true——「没有成绩」这种空状态用红色会误导。
///
/// 内容整体可滚动：错误文本长度不可控（socket / HTTP 原样），
/// 定高居中会直接 RenderFlex 溢出。
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool error;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.error = false,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = error ? theme.colorScheme.error : theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: tint),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon ?? Icons.refresh, size: 20),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
