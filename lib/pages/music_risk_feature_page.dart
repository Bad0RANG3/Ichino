import 'package:flutter/material.dart';

import 'music_risk_feature_view.dart';

/// 解锁歌曲 / 收藏品获取的页面外壳。
///
/// 两者共用同一份 [MusicRiskFeatureView]，只按 [mode] 取标题与说明，
/// 因此不再各写一个几乎一样的 Page。
class MusicRiskFeaturePage extends StatelessWidget {
  final int userId;
  final String? cookies;
  final int? loginDateTime;
  final int? loginId;
  final String? lastLoginDate;
  final Future<void> Function()? onExitToTitle;
  final MusicRiskFeatureMode mode;

  const MusicRiskFeaturePage({
    super.key,
    required this.userId,
    required this.mode,
    this.cookies,
    this.loginDateTime,
    this.loginId,
    this.lastLoginDate,
    this.onExitToTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mode.title)),
      body: MusicRiskFeatureView(
        userId: userId,
        cookies: cookies,
        loginDateTime: loginDateTime,
        loginId: loginId,
        lastLoginDate: lastLoginDate,
        onExitToTitle: onExitToTitle,
        mode: mode,
      ),
    );
  }
}
