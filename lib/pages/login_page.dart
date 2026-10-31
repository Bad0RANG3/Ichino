import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../models/session_model.dart';
import '../models/session_share.dart';
import '../services/file_picker_service.dart';
import '../services/qr_service.dart';
import '../services/title_api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

/// 登录页：粘贴 / 识别 QR 令牌，走 Aime 登录后进入主页。
///
/// 也接受主页导出的「连接信息」（实验性）：那是一串 Base64，直接续上原有会话。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _qrController = TextEditingController();
  String _rawInput = '';
  SessionShare? _share;
  bool _loading = false;
  bool _forcePreviewApi = false;

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  void _onQRContentChanged(String value) {
    final text = value.trim();
    setState(() {
      _rawInput = text;
      _share = SessionShare.tryDecode(text);
    });
  }

  Future<void> _onUploadQR() async {
    try {
      final bytes = await pickImageBytes();
      if (bytes == null) return;

      final result = await decodeQRFromBytes(bytes);

      if (result != null && result.isNotEmpty) {
        if (!mounted) return;
        _qrController.text = result;
        _onQRContentChanged(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.qrScanSuccess)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.qrScanFailed)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.qrScanError}: $e')),
        );
      }
    }
  }

  Future<void> _onLogin() async {
    if (_rawInput.isEmpty) return;
    setState(() => _loading = true);

    try {
      final result = await SessionModel.instance.loginWithQr(_rawInput);

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HomePage(
              userId: result.userId,
              token: result.token,
              forcePreviewApi: _forcePreviewApi,
            ),
          ),
        );
      } else {
        context.showSnack(
          '${AppStrings.loginFailed}：'
          '${result.message ?? 'errorID=${result.errorId}'}',
        );
      }
    } on FormatException catch (e) {
      // 令牌格式不对 / 没配 Keychip：登录请求根本没发出去，要说清楚是哪一种。
      if (mounted) {
        context.showSnack('${AppStrings.qrTokenUnrecognized}：${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.requestFailed}: ${describeApiError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _restoreMessage(SessionRestoreResult result) {
    if (!result.reusedCookie) return AppStrings.sessionRestoreToken;
    return result.loggedIn
        ? AppStrings.sessionRestoreCookie
        : AppStrings.sessionRestoreReadOnly;
  }

  /// 实验性：用主页导出的连接信息恢复会话。带可用 JSESSIONID 就直接续上那次登录，
  /// 否则退回用令牌重新登录。
  Future<void> _onRestoreSession() async {
    final share = _share;
    if (share == null) return;

    setState(() => _loading = true);
    try {
      final result = await SessionModel.instance.restoreFromShare(share);
      if (!mounted) return;
      context.showSnack(_restoreMessage(result));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HomePage(
            userId: share.userId,
            token: share.token,
            restored: result,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        context.showSnack(
          '${AppStrings.sessionRestoreFailed}: ${describeApiError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRestore = _share != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppStrings.settingsTooltip,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: AppPageBody(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.appTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 48),
            _qrCard(theme),
            const SizedBox(height: 28),
            if (isRestore)
              const AppNotice(
                AppStrings.sessionShareDetected,
                icon: Icons.science_outlined,
              ),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: AppStrings.uploadQR,
                    icon: Icons.image,
                    onPressed: _loading ? null : _onUploadQR,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _primaryButton(isRestore)),
              ],
            ),
            const SizedBox(height: 16),
            if (!isRestore)
              CheckboxListTile(
                value: _forcePreviewApi,
                onChanged: (v) => setState(() => _forcePreviewApi = v ?? false),
                title: const Text(AppStrings.forcePreviewApi),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ],
        ),
      ),
    );
  }

  /// QR 令牌输入卡。
  Widget _qrCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(icon: Icons.key, title: AppStrings.qrCodeToken),
          const SizedBox(height: 12),
          TextField(
            controller: _qrController,
            maxLines: 3,
            onChanged: _onQRContentChanged,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: AppStrings.qrHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  /// 主按钮：粘贴的是连接信息时变成「恢复会话」，否则是「登录」。
  Widget _primaryButton(bool isRestore) {
    final label = isRestore
        ? (_loading ? AppStrings.restoringSession : AppStrings.restoreSession)
        : (_loading ? AppStrings.loggingIn : AppStrings.login);
    final enabled = isRestore
        ? !_loading
        : (_rawInput.isNotEmpty && !_loading);

    return AppButton(
      label: label,
      icon: isRestore ? Icons.link : Icons.arrow_forward,
      busy: _loading,
      onPressed: enabled
          ? (isRestore ? _onRestoreSession : _onLogin)
          : null,
    );
  }
}
