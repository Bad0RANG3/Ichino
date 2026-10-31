import 'package:flutter/material.dart';

/// 全站统一的主 / 次按钮：竖向内边距 + 12 圆角。
///
/// 这两个样式原来在十个页面里各抄一份（内边距还在 13/14/16 之间飘），
/// 这里收成一个组件；[busy] 时自动换成与前景色一致的转圈并禁用点击
/// （之前手写的 `CircularProgressIndicator(color: Colors.white)` 在暗色主题下
/// 压在主色上几乎看不见）。
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  /// `FilledButton.tonalIcon` 的浅色版本。
  final bool tonal;
  final double verticalPadding;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.tonal = false,
    this.verticalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 20);
    final onTap = busy ? null : onPressed;
    final style = FilledButton.styleFrom(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return tonal
        ? FilledButton.tonalIcon(
            onPressed: onTap,
            icon: child,
            label: Text(label),
            style: style,
          )
        : FilledButton.icon(
            onPressed: onTap,
            icon: child,
            label: Text(label),
            style: style,
          );
  }
}

/// [AppButton] 的描边版本，样式与它一致。
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final double verticalPadding;

  const AppOutlinedButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.verticalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
