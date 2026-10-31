import 'package:flutter/material.dart';

import '../../config/responsive.dart';
import '../../config/strings.dart';
import '../app_card.dart';
import '../app_notice.dart';
import '../step_progress.dart';
import 'risk_widgets.dart';

/// 尚未配置 Title Server 时的占位视图。
class RiskConfigMissingView extends StatelessWidget {
  final String message;

  const RiskConfigMissingView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_ethernet,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// 高危页统一的滚动容器与内边距。
class RiskPageBody extends StatelessWidget {
  final List<Widget> children;

  const RiskPageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: responsiveBody(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// 未登录 / 冷却横幅。
class RiskStatusNotices extends StatelessWidget {
  final bool isLoggedIn;
  final int cooldownRemaining;
  final String notLoggedInText;
  final String Function(int remaining) cooldownText;

  const RiskStatusNotices({
    super.key,
    required this.isLoggedIn,
    required this.cooldownRemaining,
    required this.notLoggedInText,
    required this.cooldownText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isLoggedIn)
          AppNotice(
            notLoggedInText,
            error: true,
            icon: Icons.warning_amber_rounded,
          ),
        if (isLoggedIn && cooldownRemaining > 0)
          AppNotice(cooldownText(cooldownRemaining), icon: Icons.timer_outlined),
      ],
    );
  }
}

/// 高危功能页的统一骨架，自上而下固定为：
///
/// 未登录/冷却提示 → 功能说明卡 → 各页自己的卡片 → 自动退登勾选 →
/// 执行按钮 → 执行阶段卡。
///
/// 各页只需给出文案与回调；卡片之间的间距由这里统一，页面上不再出现
/// 一串 `const SizedBox(height: 12)`。中转页（只导航、不发包）把
/// [onRun] 与 [onAutoLogoutChanged] 留空即可，按钮与勾选框会整段隐藏。
class RiskFeatureScaffold extends StatelessWidget {
  final bool isLoggedIn;
  final int cooldownRemaining;
  final String notLoggedInMessage;
  final String Function(int remaining) cooldownNotice;

  /// 功能说明卡；[featureTitle] 为 `null` 时整张卡不显示（功能票页）。
  final IconData? featureIcon;
  final String? featureTitle;
  final String? featureDescription;
  /// 说明卡下方的补充提示（如跑图的「不发放收藏品」），用警示色。
  final String? featureWarning;
  final Widget? featureChild;
  final bool danger;

  /// 说明卡与执行按钮之间，各页自己的卡片。
  final List<Widget> cards;

  final bool autoLogout;
  final bool autoLogoutEnabled;
  final ValueChanged<bool>? onAutoLogoutChanged;
  final String? autoLogoutLabel;

  final bool running;
  final bool runEnabled;
  final IconData runIcon;
  final String runLabel;
  final String runningLabel;
  final String? runDisabledLabel;
  final VoidCallback? onRun;
  /// 执行按钮上方的提示条（功能票的「已选票」）。
  final Widget? runHint;

  final RiskStep step;
  final String stepMessage;
  final String? stepError;
  final List<(RiskStep, String)> steps;

  const RiskFeatureScaffold({
    super.key,
    required this.isLoggedIn,
    required this.cooldownRemaining,
    required this.notLoggedInMessage,
    required this.cooldownNotice,
    this.featureIcon,
    this.featureTitle,
    this.featureDescription,
    this.featureWarning,
    this.featureChild,
    this.danger = false,
    this.cards = const [],
    this.autoLogout = false,
    this.autoLogoutEnabled = true,
    this.onAutoLogoutChanged,
    this.autoLogoutLabel,
    this.running = false,
    this.runEnabled = false,
    this.runIcon = Icons.play_arrow,
    this.runLabel = '',
    this.runningLabel = '',
    this.runDisabledLabel,
    this.runHint,
    this.onRun,
    this.step = RiskStep.idle,
    this.stepMessage = '',
    this.stepError,
    this.steps = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = featureTitle;

    return RiskPageBody(
      children: [
        RiskStatusNotices(
          isLoggedIn: isLoggedIn,
          cooldownRemaining: cooldownRemaining,
          notLoggedInText: notLoggedInMessage,
          cooldownText: cooldownNotice,
        ),
        if (title != null)
          RiskFeatureCard(
            icon: featureIcon,
            title: title,
            description: featureDescription,
            danger: danger,
            child: featureWarning == null
                ? featureChild
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ?featureChild,
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          featureWarning!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        for (final card in cards) ...[
          const SizedBox(height: 12),
          card,
        ],
        if (onAutoLogoutChanged != null) ...[
          const SizedBox(height: 12),
          AutoLogoutToggle(
            value: autoLogout,
            enabled: autoLogoutEnabled && !running,
            onChanged: onAutoLogoutChanged,
            label: autoLogoutLabel ?? AppStrings.autoLogoutAndExit,
          ),
        ],
        if (onRun != null) ...[
          const SizedBox(height: 12),
          ?runHint,
          if (runHint != null) const SizedBox(height: 12),
          RiskRunButton(
            running: running,
            enabled: runEnabled,
            icon: runIcon,
            label: runLabel,
            runningLabel: runningLabel,
            disabledLabel: runDisabledLabel,
            onPressed: onRun!,
          ),
        ],
        if (step != RiskStep.idle && steps.isNotEmpty) ...[
          const SizedBox(height: 16),
          StepProgressCard(
            step: step,
            message: stepMessage,
            error: stepError,
            steps: steps,
          ),
        ],
      ],
    );
  }
}
