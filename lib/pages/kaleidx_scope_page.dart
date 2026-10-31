import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../models/session_model.dart';
import '../models/user_kaleidx_scope.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';
import '../widgets/app_card.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/risk/risk_list_widgets.dart';
import '../widgets/risk/risk_page_scaffold.dart';
import '../widgets/risk/risk_run_mixin.dart';
import '../widgets/risk/risk_widgets.dart';
import '../widgets/step_progress.dart';

/// 万花筒专区：发现新的宿命之门、获取门的钥匙、设置门的通关状态。
///
/// 三个动作都落在 `upsertUserAll.userKaleidxScopeList` 同一行的三个布尔位上
/// （`isGateFound` / `isKeyFound` / `isClear`）。钥匙不走 `userItemList`：
/// `ExportUserItems` 从不输出 itemKind 15，下行也没有读它的路径。
class KaleidxScopePage extends StatefulWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final Future<void> Function()? onExitToTitle;

  const KaleidxScopePage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
  });

  @override
  State<KaleidxScopePage> createState() => _KaleidxScopePageState();
}

/// 通关态可以往两个方向改，所以用三态而不是又一个勾选框。
enum _ClearChoice { keep, cleared, uncleared }

class _KaleidxScopePageState extends State<KaleidxScopePage>
    with CooldownMixin<KaleidxScopePage>, RiskRunMixin<KaleidxScopePage> {
  final _gateIdController = TextEditingController();
  final List<int> _pending = [];

  bool _discover = true;
  bool _giveKey = false;
  _ClearChoice _clearChoice = _ClearChoice.keep;

  Map<String, Map<String, dynamic>> _userAllData = const {};
  List<UserKaleidxScopeBean> _serverScopes = const [];

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  @override
  void dispose() {
    _gateIdController.dispose();
    super.dispose();
  }

  void _addPending() {
    final id = int.tryParse(_gateIdController.text.trim()) ?? -1;
    if (id <= 0) {
      riskSnack(AppStrings.kaleidxNeedGateId);
      return;
    }
    if (_pending.contains(id)) {
      riskSnack(AppStrings.kaleidxGateIdDuplicated);
      return;
    }
    setState(() {
      _pending.add(id);
      _gateIdController.clear();
    });
  }

  UserKaleidxScopeBean? _serverRow(int gateId) {
    for (final row in _serverScopes) {
      if (row.gateId == gateId) return row;
    }
    return null;
  }

  bool? get _targetClear => switch (_clearChoice) {
    _ClearChoice.keep => null,
    _ClearChoice.cleared => true,
    _ClearChoice.uncleared => false,
  };

  /// 整行替换，所以已存在的门必须拿服务器原行做底，只改要改的位。
  List<UserKaleidxScopeBean> _buildRows() {
    final clear = _targetClear;
    final timestamp = UserAllPayloadBuilder.nowTimestamp();
    return [
      for (final id in _pending)
        _serverRow(id)?.withActions(
              discover: _discover,
              giveKey: _giveKey,
              clear: clear,
              timestamp: timestamp,
            ) ??
            UserKaleidxScopeBean.discovered(
              id,
              giveKey: _giveKey,
              clear: clear,
              timestamp: timestamp,
            ),
    ];
  }

  Future<void> _fetchData() async {
    final service = SessionModel.instance.createTitleService(
      cookies: widget.cookies,
    );
    if (service == null) return;

    await runRiskFetch(() async {
      final results = await Future.wait([
        service.fetchUserAllData(widget.userId),
        service.getUserKaleidxScopes(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _userAllData = results[0] as Map<String, Map<String, dynamic>>;
        _serverScopes = results[1] as List<UserKaleidxScopeBean>;
      });
    });
  }

  Future<void> _run() async {
    if (!ensureRiskReady(
      loginDateTime: widget.loginDateTime,
      loginId: widget.loginId,
      notLoggedInMessage: AppStrings.kaleidxNotLoggedIn,
      cooldownNotice: AppStrings.kaleidxCooldownNotice,
    )) {
      return;
    }
    if (_pending.isEmpty) {
      riskSnack(AppStrings.kaleidxNeedGateId);
      return;
    }
    if (!_discover && !_giveKey && _clearChoice == _ClearChoice.keep) {
      riskSnack(AppStrings.kaleidxNeedAction);
      return;
    }

    final loginDateTime = widget.loginDateTime!;
    final loginId = widget.loginId!;
    setRiskRunning(true);

    try {
      final service = SessionModel.instance.createTitleService(
        cookies: widget.cookies,
      )!;
      final builder = UserAllPayloadBuilder(service.config);

      var data = _userAllData;
      if (data.isEmpty || _serverScopes.isEmpty) {
        updateRiskStep(RiskStep.fetchData);
        final results = await Future.wait([
          service.fetchUserAllData(widget.userId),
          service.getUserKaleidxScopes(widget.userId),
        ]);
        data = results[0] as Map<String, Map<String, dynamic>>;
        if (mounted) {
          setState(() {
            _userAllData = data;
            _serverScopes = results[1] as List<UserKaleidxScopeBean>;
          });
        }
      }

      updateRiskStep(RiskStep.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: UserAllPayloadBuilder.placeholderMusicData(),
        generalUserInfo: data,
      );

      final rows = _buildRows();
      // 每一位 '1' 插入 / '0' 更新，判据是服务器有没有同 gateId 的行。
      final flags = [
        for (final row in rows) _serverRow(row.gateId) == null ? '1' : '0',
      ].join();
      builder.applyKaleidxScopePatch(
        packet,
        scopes: [for (final row in rows) row.toWireJson()],
        newFlags: flags,
      );

      await service.upsertUserAll(packet, widget.userId);
      updateRiskStep(RiskStep.complete, await _verify(service));
      await autoLogoutAndExit(widget.onExitToTitle);
    } catch (e) {
      reportRiskError(e);
    } finally {
      setRiskRunning(false);
    }
  }

  Future<String> _verify(TitleApiService service) async {
    final requested = List<int>.from(_pending);
    List<UserKaleidxScopeBean> rows;
    try {
      rows = await service.getUserKaleidxScopes(widget.userId);
    } catch (e) {
      return AppStrings.kaleidxVerifyFailed(describeApiError(e));
    }
    if (mounted) setState(() => _serverScopes = rows);

    final saved = rows.where((r) => requested.contains(r.gateId));
    final missing = requested
        .where((id) => !rows.any((r) => r.gateId == id))
        .toList();
    if (missing.isNotEmpty) {
      return AppStrings.kaleidxNotSaved(missing.join(' / '));
    }
    return AppStrings.kaleidxVerified(saved.length);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _userAllData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.kaleidxFeatureTitle)),
      body: RiskFeatureScaffold(
        isLoggedIn: isLoggedIn,
        cooldownRemaining: cooldownRemaining,
        notLoggedInMessage: AppStrings.kaleidxNotLoggedIn,
        cooldownNotice: AppStrings.kaleidxCooldownNotice,
        featureIcon: Icons.science_outlined,
        featureTitle: AppStrings.kaleidxFeatureTitle,
        featureDescription: AppStrings.kaleidxFeatureDesc,
        cards: [
          _inputCard(),
          RiskFetchCard(
            hasData: hasData,
            statusText: hasData
                ? '${AppStrings.fetched} (${_serverScopes.length})'
                : AppStrings.fetchNotFetched,
            loadingLabel: AppStrings.fetching,
            actionLabel: AppStrings.fetchData,
            loading: riskFetching,
            enabled: !riskRunning,
            onFetch: _fetchData,
          ),
        ],
        autoLogout: riskAutoLogout,
        autoLogoutEnabled: widget.onExitToTitle != null,
        onAutoLogoutChanged: setRiskAutoLogout,
        running: riskRunning,
        runEnabled: isLoggedIn,
        runIcon: Icons.lock_open_outlined,
        runLabel: AppStrings.kaleidxRun,
        runningLabel: AppStrings.running,
        onRun: _run,
        step: riskStep,
        stepMessage: riskStepMessage,
        stepError: riskError,
        steps: [
          (RiskStep.fetchData, AppStrings.kaleidxStepFetch),
          (RiskStep.upload, AppStrings.kaleidxStepUpload),
          if (riskAutoLogout) (RiskStep.logout, AppStrings.stepLogout),
        ],
      ),
    );
  }

  Widget _inputCard() {
    final theme = Theme.of(context);
    final enabled = !riskRunning;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RiskNumberField(
            controller: _gateIdController,
            label: AppStrings.kaleidxGateIdLabel,
            hint: AppStrings.kaleidxGateIdHint,
            enabled: enabled,
          ),
          const SizedBox(height: 8),
          RiskAddButton(onPressed: enabled ? _addPending : null),
          RiskCheckRow(
            label: AppStrings.kaleidxActionDiscover,
            value: _discover,
            enabled: enabled,
            onChanged: (v) => setState(() => _discover = v),
          ),
          RiskCheckRow(
            label: AppStrings.kaleidxActionKey,
            value: _giveKey,
            enabled: enabled,
            onChanged: (v) => setState(() => _giveKey = v),
          ),
          const SizedBox(height: 10),
          RiskDropdownField<_ClearChoice>(
            value: _clearChoice,
            label: AppStrings.kaleidxClearLabel,
            enabled: enabled,
            items: const [
              DropdownMenuItem(
                value: _ClearChoice.keep,
                child: Text(AppStrings.kaleidxClearKeep),
              ),
              DropdownMenuItem(
                value: _ClearChoice.cleared,
                child: Text(AppStrings.kaleidxClearCleared),
              ),
              DropdownMenuItem(
                value: _ClearChoice.uncleared,
                child: Text(AppStrings.kaleidxClearUncleared),
              ),
            ],
            onChanged: (v) => setState(() => _clearChoice = v),
          ),
          if (_giveKey || _clearChoice == _ClearChoice.cleared) ...[
            const SizedBox(height: 6),
            Text(
              _giveKey
                  ? AppStrings.kaleidxKeyNeedsGate
                  : AppStrings.kaleidxClearNeedsKey,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final id in _pending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '#$id  ${_stateLabelFor(id)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          if (_pending.isEmpty)
            Text(
              AppStrings.kaleidxPendingEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _stateLabelFor(int gateId) {
    final row = _serverRow(gateId);
    if (row == null) {
      return _userAllData.isEmpty
          ? ''
          : AppStrings.kaleidxGateState(false, false, false);
    }
    return AppStrings.kaleidxGateState(
      row.isGateFound,
      row.isKeyFound,
      row.isClear,
    );
  }
}
