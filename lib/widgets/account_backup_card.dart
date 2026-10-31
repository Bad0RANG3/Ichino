import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../config/strings.dart';
import '../models/session_model.dart';
import '../services/account_backup_service.dart';
import '../services/title_api_service.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_code_box.dart';
import 'app_notice.dart';

/// 账号备份：把服务器能读到的用户数据汇成一长串 JSON，可复制到剪贴板。
///
/// 只读不写——全程只发 `GetUser*Api`，不会碰 UpsertUserAllApi，所以和
/// 「风险」页那些伪造包相比是安全操作。
class AccountBackupCard extends StatefulWidget {
  final int userId;
  final String? cookies;

  const AccountBackupCard({super.key, required this.userId, this.cookies});

  @override
  State<AccountBackupCard> createState() => _AccountBackupCardState();
}

class _AccountBackupCardState extends State<AccountBackupCard> {
  bool _running = false;
  String _progress = '';
  AccountBackup? _result;
  String? _error;

  Future<void> _run() async {
    final service = SessionModel.instance.createTitleService(
      cookies: widget.cookies,
    );
    if (service == null) {
      context.showSnack(AppStrings.ticketNotConfigured);
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _progress = '';
    });

    try {
      final backup = await AccountBackupService(service, userId: widget.userId)
          .run(
            onSection: (section) {
              if (mounted) setState(() => _progress = section);
            },
          );
      if (!mounted) return;
      setState(() {
        _result = backup;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeApiError(e);
        _running = false;
      });
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    context.showSnack(AppStrings.accountBackupCopied);
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.folder_zip_outlined,
            title: AppStrings.accountBackupTitle,
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.accountBackupDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: _running
                ? AppStrings.accountBackupRunning(_progress)
                : AppStrings.accountBackupRun,
            icon: Icons.download_outlined,
            busy: _running,
            tonal: true,
            verticalPadding: 13,
            onPressed: _run,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppNotice(_error!, icon: Icons.error_outline, error: true),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            if (!result.isComplete) ...[
              AppNotice(
                AppStrings.accountBackupPartial(result.failedSections),
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.accountBackupSize(_sizeLabel(result.byteLength)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copy(result.encode()),
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text(AppStrings.accountBackupCopy),
                ),
              ],
            ),
            AppCodeBox(text: result.encode()),
            const SizedBox(height: 10),
            Text(
              AppStrings.accountBackupSecurity,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
