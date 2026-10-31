import 'package:flutter/material.dart';

import '../../config/responsive.dart';
import '../../config/strings.dart';
import '../../config/title_server_config.dart';
import '../../models/user_data.dart';
import '../../models/user_preview.dart';
import '../../widgets/account_backup_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_notice.dart';
import '../../widgets/app_page.dart';
import '../../widgets/connection_share_card.dart';
import '../../widgets/home/home_common.dart';
import '../../widgets/home/home_debug_card.dart';
import '../../widgets/home/home_preview_cards.dart';
import '../../widgets/home/home_user_data_cards.dart';

/// 主页第一个页签的内容：账号概要、统计卡与调试信息。
///
/// 数据与回调都由 [HomePage] 持有，这里只负责按加载状态切换展示。
class HomeTabView extends StatelessWidget {
  final int userId;
  final String token;
  final String? cookies;
  final UserPreviewDataBean? preview;
  final UserDataBean? userData;
  final bool loading;
  final String? error;
  final bool isGameLoggedIn;
  final bool forcePreviewApi;
  final bool showRestoredNotice;
  final String? rawJson;

  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogin;

  const HomeTabView({
    super.key,
    required this.userId,
    required this.token,
    required this.cookies,
    required this.preview,
    required this.userData,
    required this.loading,
    required this.error,
    required this.isGameLoggedIn,
    required this.forcePreviewApi,
    required this.showRestoredNotice,
    required this.rawJson,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    // 开发预览等入口会直接塞入种子数据，此时没配 Title Server 也应该展示。
    if (!TitleServerConfigHolder().isConfigured &&
        userData == null &&
        preview == null) {
      return _ConfigMissingView(onOpenSettings: onOpenSettings);
    }

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _ErrorView(error: error!, onRetry: onRetry);
    }

    final data = userData;
    if (data != null) {
      return _buildFullData(context, data);
    }

    final p = preview;
    if (p == null) {
      return const SizedBox.shrink();
    }

    final showLoginButton = forcePreviewApi && !isGameLoggedIn;
    if (p.isLogin || showLoginButton) {
      return _buildPreviewOnly(
        context,
        p,
        showLoginButton: showLoginButton,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPreviewOnly(
    BuildContext context,
    UserPreviewDataBean preview, {
    required bool showLoginButton,
  }) {
    return AppPageBody(
      child: Column(
        children: [
          if (preview.errorId != 0) ErrorIdBanner(errorId: preview.errorId),
          AppNotice(
            showLoginButton
                ? AppStrings.previewModeNotice
                : AppStrings.inheritedAccountNotice,
            icon: showLoginButton ? Icons.login : Icons.science_outlined,
          ),
          if (showLoginButton)
            AppButton(
              label: AppStrings.login,
              icon: Icons.login,
              onPressed: onLogin,
            ),
          const SizedBox(height: 12),
          HomeProfileCard(
            userName: preview.userName,
            iconId: preview.iconId,
            playerRating: preview.playerRating,
          ),
          const SizedBox(height: 12),
          ...responsiveGrid(
            context: context,
            children: [
              PreviewGameInfoCard(preview: preview),
              PreviewStatusCard(preview: preview),
            ],
          ),
          const SizedBox(height: 12),
          ConnectionShareCard(userId: userId, token: token),
          if (rawJson != null) ...[
            const SizedBox(height: 12),
            DebugRawJsonCard(rawJson: rawJson!),
          ],
        ],
      ),
    );
  }

  Widget _buildFullData(BuildContext context, UserDataBean data) {
    return AppPageBody(
      child: Column(
        children: [
          if (showRestoredNotice)
            AppNotice(
              AppStrings.sessionRestoredNotice,
              icon: Icons.science_outlined,
            ),
          HomeProfileCard(
            userName: data.userName,
            iconId: data.iconId,
            playerRating: data.playerRating,
            highestRating: '${data.highestRating}',
          ),
          const SizedBox(height: 12),
            ...responsiveGrid(
              context: context,
              children: [
                RatingBreakdownCard(data: data),
                FirstPlayCard(data: data),
                GameInfoFromUserDataCard(data: data),
                PlayStatsCard(data: data),
                StatusFromUserDataCard(preview: preview, data: data),
                UserDataDetailCard(data: data),
              ],
            ),
            const SizedBox(height: 12),
            ConnectionShareCard(userId: userId, token: token),
            const SizedBox(height: 12),
            AccountBackupCard(userId: userId, cookies: cookies),
            if (rawJson != null) ...[
              const SizedBox(height: 12),
              DebugRawJsonCard(rawJson: rawJson!),
            ],
          ],
      ),
    );
  }
}

class _ConfigMissingView extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _ConfigMissingView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      icon: Icons.settings_ethernet,
      title: AppStrings.titleServerNotConfigured,
      description: AppStrings.titleServerNotConfiguredDesc,
      actionLabel: AppStrings.openSettings,
      actionIcon: Icons.settings,
      onAction: onOpenSettings,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      icon: Icons.error_outline,
      title: AppStrings.loadFailed,
      description: error,
      error: true,
      actionLabel: AppStrings.retry,
      onAction: onRetry,
    );
  }
}
