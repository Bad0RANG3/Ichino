import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/session_model.dart';
import '../services/title_api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/risk/risk_page_scaffold.dart';
import '../widgets/risk/risk_run_mixin.dart';
import '../widgets/step_progress.dart';

class TicketPage extends StatefulWidget {
  final int userId;
  final String? cookies;

  /// `loginDateTime` 来自 HomePage 启动时执行的 UserLoginApi。
  /// 为 `null` 时表示当前未持有有效登录态（例如 isInherit 账号或登录失败）。
  final int? loginDateTime;
  final int playerRating;

  /// 当用户勾选"完成后自动退出登录"时，由 HomePage 负责发送 logout 包。
  final Future<void> Function()? onLogoutRequested;

  const TicketPage({
    super.key,
    required this.userId,
    required this.playerRating,
    this.cookies,
    this.loginDateTime,
    this.onLogoutRequested,
  });

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage>
    with CooldownMixin<TicketPage>, RiskRunMixin<TicketPage> {
  static const _ticketNameMap = {
    2: '2倍票',
    4: '4倍票',
    5: '5倍票'
  };

  List<Map<String, dynamic>>? _tickets;
  String? _ticketsError;
  int? _selectedTicketId;

  String _ticketName(int chargeId) =>
      _ticketNameMap[chargeId] ?? '票$chargeId';

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  Map<String, dynamic>? _findTicket(int chargeId) {
    final tickets = _tickets;
    if (tickets == null) return null;
    for (final t in tickets) {
      if ((t['chargeId'] as num?)?.toInt() == chargeId) return t;
    }
    return null;
  }

  Future<void> _loadTickets() async {
    final service = SessionModel.instance.createTitleService(
      cookies: widget.cookies,
    );
    if (service == null) return;

    setState(() {
      _ticketsError = null;
      _tickets = null;
      _selectedTicketId = null;
    });

    await runRiskFetch(
      () async {
        final data = await service.getUserCharge(widget.userId);
        if (!mounted) return;
        final rawList = data['userChargeList'] as List<dynamic>? ?? [];
        setState(() {
          _tickets = rawList.map((e) => e as Map<String, dynamic>).toList();
        });
      },
      onError: (e) => setState(() => _ticketsError = describeApiError(e)),
    );
  }

  Future<void> _runTicket() async {
    final ticketId = _selectedTicketId;
    if (ticketId == null) {
      riskSnack(AppStrings.ticketNotSelected);
      return;
    }
    if (!ensureRiskReady(
      loginDateTime: widget.loginDateTime,
      loginId: null,
      notLoggedInMessage: AppStrings.ticketNotLoggedIn,
      cooldownNotice: AppStrings.ticketCooldownNotice,
      requireLoginId: false,
    )) {
      return;
    }

    final selectedTicket = _findTicket(ticketId);
    if (selectedTicket != null &&
        (selectedTicket['stock'] as num?)?.toInt() != 0) {
      riskSnack(AppStrings.ticketStockNotEmpty);
      return;
    }

    final service = SessionModel.instance.createTitleService(
      cookies: widget.cookies,
    )!;
    setRiskRunning(true);
    clearRiskError();

    try {
      updateRiskStep(RiskStep.upload);
      await service.upsertUserChargeLog(
        userId: widget.userId,
        ticketId: ticketId,
        loginDateTime: widget.loginDateTime!,
        playerRating: widget.playerRating,
      );

      if (riskAutoLogout && widget.onLogoutRequested != null) {
        updateRiskStep(RiskStep.logout);
        await Future<void>.delayed(const Duration(seconds: 5));
        await widget.onLogoutRequested!();
      }

      updateRiskStep(
        RiskStep.complete,
        '${AppStrings.ticketUsed}: ${_ticketName(ticketId)}',
      );
    } catch (e) {
      reportRiskError(e);
    } finally {
      setRiskRunning(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!TitleServerConfigHolder().isConfigured) {
      return const RiskConfigMissingView(
        message: AppStrings.ticketNotConfigured,
      );
    }

    final selected = _selectedTicketId;
    final onCooldown = cooldownRemaining > 0;

    return RiskFeatureScaffold(
      isLoggedIn: isLoggedIn,
      cooldownRemaining: cooldownRemaining,
      notLoggedInMessage: AppStrings.ticketNotLoggedIn,
      cooldownNotice: AppStrings.ticketCooldownNotice,
      cards: [_buildTicketListCard()],
      autoLogout: riskAutoLogout,
      autoLogoutEnabled: widget.onLogoutRequested != null,
      onAutoLogoutChanged: setRiskAutoLogout,
      autoLogoutLabel: AppStrings.ticketAutoLogout,
      running: riskRunning,
      runEnabled: widget.loginDateTime != null && !onCooldown,
      runIcon: onCooldown ? Icons.timer_outlined : Icons.play_arrow,
      runLabel: AppStrings.runTicket,
      runningLabel: AppStrings.running,
      runDisabledLabel:
          onCooldown ? AppStrings.ticketCooldownCountdown(cooldownRemaining) : null,
      runHint: selected == null ? null : _selectedTicketHint(selected),
      onRun: _runTicket,
      step: riskStep,
      stepMessage: riskStepMessage,
      stepError: riskError,
      steps: [
        (RiskStep.upload, AppStrings.stepChargeTicket),
        if (riskAutoLogout) (RiskStep.logout, AppStrings.stepLogout),
      ],
    );
  }

  Widget _selectedTicketHint(int chargeId) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${AppStrings.selectedTicket}: ${_ticketName(chargeId)} (ID: $chargeId)',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTicketListCard() {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: _selectedTicketId != null
          ? theme.colorScheme.primary.withValues(alpha: 0.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.myTickets,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: riskFetching ? null : _loadTickets,
                  icon: riskFetching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    riskFetching ? AppStrings.loading : AppStrings.refreshData,
                    style: theme.textTheme.labelSmall,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ticketsError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _ticketsError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ..._ticketNameMap.keys.map(
            (id) => _ticketRow(theme, id, _findTicket(id)),
          ),
        ],
      ),
    );
  }

  Widget _ticketRow(ThemeData theme, int chargeId, Map<String, dynamic>? ticket) {
    final hasData = ticket != null;
    final stock = (ticket?['stock'] as num?)?.toInt() ?? 0;
    final validDate = ticket?['validDate'] as String? ?? '-';
    final name = _ticketName(chargeId);
    final isSelected = _selectedTicketId == chargeId;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: riskRunning
          ? null
          : () {
              setState(() {
                _selectedTicketId = isSelected ? null : chargeId;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '$chargeId',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  if (hasData)
                    Text(
                      '有效期: $validDate',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary)
            else if (hasData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stock > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '剩余 $stock',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: stock > 0 ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
