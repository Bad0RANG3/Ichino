import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../core/json_value.dart';
import '../models/session_model.dart';
import '../services/title_api_service.dart';
import '../services/user_all_payload_builder.dart';
import '../widgets/app_card.dart';
import '../widgets/cooldown_mixin.dart';
import '../widgets/risk/risk_list_widgets.dart';
import '../widgets/risk/risk_page_scaffold.dart';
import '../widgets/risk/risk_run_mixin.dart';
import '../widgets/risk/risk_widgets.dart';
import '../widgets/step_progress.dart';

/// 一键跑图：把选中的区域标记为已完成。
///
/// 依据反编译客户端：
/// - 区域进度是 `upsertUserAll.userMapList`，行结构见 `Net/VO/Mai2/UserMap.cs`
///   `{mapId, distance, isLock, isClear, isComplete, unlockFlag}`，主键 mapId。
/// - `MapMaster.CreateUserDataMapList`（Util/MapMaster.cs:509-543）用 `distance`
///   与该区域的 ReleaseFlag / End 里程针比较，**重算** isClear / isComplete，
///   没有对应针时甚至强制写回 false。所以只发 flag 会被冲掉，必须把
///   `distance` 推过 End 针——这里直接给 `UserMapData.MaxDistance`。
/// - `unlockFlag` 语义是反的：`IsFinishedOpening ? 0 : 1`。
/// - `isLock` 客户端不回读（`ConvertUserMap` 从不读它）。
class MapTraversePage extends StatefulWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final Future<void> Function()? onExitToTitle;

  const MapTraversePage({
    super.key,
    required this.userId,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.onExitToTitle,
  });

  @override
  State<MapTraversePage> createState() => _MapTraversePageState();
}

class _MapTraversePageState extends State<MapTraversePage>
    with CooldownMixin<MapTraversePage>, RiskRunMixin<MapTraversePage> {
  final _mapIdController = TextEditingController();
  final List<int> _pending = [];

  Map<String, Map<String, dynamic>> _userAllData = const {};
  Set<int>? _serverMapIds;
  List<Map<String, dynamic>> _serverMaps = const [];

  @override
  int? get cooldownLoginDateTime => widget.loginDateTime;

  @override
  void dispose() {
    _mapIdController.dispose();
    super.dispose();
  }

  void _addPending() {
    final id = int.tryParse(_mapIdController.text.trim()) ?? -1;
    if (id <= 0) {
      riskSnack(AppStrings.mapNeedMapId);
      return;
    }
    if (_pending.contains(id)) {
      riskSnack(AppStrings.listDuplicate);
      return;
    }
    setState(() {
      _pending.add(id);
      _mapIdController.clear();
    });
  }

  void _applyServerMaps(List<Map<String, dynamic>> rows) {
    _serverMaps = rows;
    _serverMapIds = rows
        .map((e) => jsonInt(e['mapId']))
        .where((e) => e != 0)
        .toSet();
  }

  Future<void> _fetchData() async {
    final service = SessionModel.instance.createTitleService(
      cookies: widget.cookies,
    );
    if (service == null) return;

    await runRiskFetch(() async {
      final results = await Future.wait([
        service.fetchUserAllData(widget.userId),
        service.getUserMaps(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _userAllData = results[0] as Map<String, Map<String, dynamic>>;
        _applyServerMaps(results[1] as List<Map<String, dynamic>>);
      });
    });
  }

  Future<void> _run() async {
    if (!ensureRiskReady(
      loginDateTime: widget.loginDateTime,
      loginId: widget.loginId,
      notLoggedInMessage: AppStrings.mapNotLoggedIn,
      cooldownNotice: AppStrings.mapCooldownNotice,
    )) {
      return;
    }
    if (_pending.isEmpty) {
      riskSnack(AppStrings.mapNeedMapId);
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
      var serverIds = _serverMapIds;
      if (data.isEmpty || serverIds == null) {
        updateRiskStep(RiskStep.fetchData);
        final results = await Future.wait([
          service.fetchUserAllData(widget.userId),
          service.getUserMaps(widget.userId),
        ]);
        data = results[0] as Map<String, Map<String, dynamic>>;
        if (mounted) setState(() => _userAllData = data);
        _applyServerMaps(results[1] as List<Map<String, dynamic>>);
        serverIds = _serverMapIds!;
      }

      updateRiskStep(RiskStep.upload);
      final packet = builder.build(
        userId: widget.userId,
        loginId: loginId,
        loginDateTime: loginDateTime,
        musicData: UserAllPayloadBuilder.placeholderMusicData(),
        generalUserInfo: data,
      );

      // isNewMapList 与 userMapList 一一对齐，每位 '1' 新增 / '0' 更新，
      // 判据是服务器是否已有同 mapId 的行（VOExtensions.BuildListData）。
      final maps = [
        for (final id in _pending) UserAllPayloadBuilder.completedMap(id),
      ];
      final flags = [
        for (final id in _pending) serverIds.contains(id) ? '0' : '1',
      ].join();
      builder.applyMapPatch(packet, maps: maps, newFlags: flags);

      await service.upsertUserAll(packet, widget.userId);
      updateRiskStep(RiskStep.complete, await _verify(service));
      await autoLogoutAndExit(widget.onExitToTitle);
    } catch (e) {
      reportRiskError(e);
    } finally {
      setRiskRunning(false);
    }
  }

  /// 回读区分「服务器没写入 userMapList」和「写入了但游戏里仍显示未完成」。
  Future<String> _verify(TitleApiService service) async {
    final requested = List<int>.from(_pending);
    List<Map<String, dynamic>> rows;
    try {
      rows = await service.getUserMaps(widget.userId);
    } catch (e) {
      return AppStrings.mapVerifyFailed(describeApiError(e));
    }
    if (mounted) setState(() => _applyServerMaps(rows));

    final saved = _serverMapIds ?? <int>{};
    final missing = requested.where((id) => !saved.contains(id)).toList();
    if (missing.isNotEmpty) {
      return AppStrings.mapNotSaved(missing.join(' / '));
    }
    return AppStrings.mapVerified(requested.length);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _serverMapIds != null;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mapFeatureTitle)),
      body: RiskFeatureScaffold(
        isLoggedIn: isLoggedIn,
        cooldownRemaining: cooldownRemaining,
        notLoggedInMessage: AppStrings.mapNotLoggedIn,
        cooldownNotice: AppStrings.mapCooldownNotice,
        featureIcon: Icons.map_outlined,
        featureTitle: AppStrings.mapFeatureTitle,
        featureDescription: AppStrings.mapFeatureDesc,
        featureWarning: AppStrings.mapCollectiblesNotice,
        cards: [
          _inputCard(),
          RiskFetchCard(
            hasData: hasData,
            statusText: hasData
                ? '${AppStrings.fetched} (${_serverMaps.length})'
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
        runIcon: Icons.flag_outlined,
        runLabel: AppStrings.mapRun,
        runningLabel: AppStrings.running,
        onRun: _run,
        step: riskStep,
        stepMessage: riskStepMessage,
        stepError: riskError,
        steps: [
          (RiskStep.fetchData, AppStrings.mapStepFetch),
          (RiskStep.upload, AppStrings.mapStepUpload),
          if (riskAutoLogout) (RiskStep.logout, AppStrings.stepLogout),
        ],
      ),
    );
  }

  Widget _inputCard() {
    final enabled = !riskRunning;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RiskNumberField(
            controller: _mapIdController,
            label: AppStrings.mapIdLabel,
            hint: AppStrings.mapIdHint,
            enabled: enabled,
          ),
          const SizedBox(height: 8),
          RiskAddButton(onPressed: enabled ? _addPending : null),
          const SizedBox(height: 10),
          RiskPendingIds(
            ids: _pending,
            emptyHint: AppStrings.mapPendingEmpty,
          ),
        ],
      ),
    );
  }
}
