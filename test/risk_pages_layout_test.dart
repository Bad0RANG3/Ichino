import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/pages/high_risk_feature_page.dart';
import 'package:ichino/pages/kaleidx_scope_page.dart';
import 'package:ichino/pages/map_traverse_page.dart';
import 'package:ichino/pages/music_risk_feature_page.dart';
import 'package:ichino/pages/music_risk_feature_view.dart';
import 'package:ichino/pages/number_patch_page.dart';
import 'package:ichino/pages/ticket_page.dart';
import 'package:ichino/pages/travel_partner_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 高危功能的九个页面都跑同一套骨架（[RiskFeatureScaffold]），这里用最窄的
/// 手机宽度一次性确认它们都不溢出——各页自己的测试只覆盖自己那一页，加了
/// 一个新的公共组件之后，最容易漏的就是「别的页面被挤爆」。
Future<void> _pump(WidgetTester tester, Widget page, {Size size = const Size(320, 2600)}) async {
  SharedPreferences.setMockInitialValues({});
  await TitleServerConfigHolder().update(
    const TitleServerConfig(
      titleServerUrl: 'http://127.0.0.1:9999',
      aesKey: '0123456789abcdef',
      aesIv: '0123456789abcdef',
      clientId: 'A63E01C2805',
    ),
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

void main() {
  final pages = <String, Widget>{
    '功能票': const TicketPage(userId: 42, playerRating: 15000),
    '歌曲解锁': const MusicRiskFeaturePage(
      userId: 42,
      mode: MusicRiskFeatureMode.unlockMusic,
    ),
    '收藏品获取': const MusicRiskFeaturePage(
      userId: 42,
      mode: MusicRiskFeatureMode.collectibles,
    ),
    '修改 Rating': const NumberPatchPage(
      userId: 42,
      mode: NumberPatchMode.rating,
    ),
    '舞里程': const NumberPatchPage(
      userId: 42,
      mode: NumberPatchMode.maiMile,
    ),
    '一键跑图': const MapTraversePage(userId: 42),
    '万花筒': const KaleidxScopePage(userId: 42),
    '旅行伙伴': const TravelPartnerPage(userId: 42),
    '高危功能中转': const HighRiskFeaturePage(userId: 42),
  };

  for (final entry in pages.entries) {
    testWidgets('${entry.key}页在 320 宽下未登录也不溢出', (tester) async {
      await _pump(tester, entry.value);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('旅行伙伴页在桌面宽度下同样不溢出', (tester) async {
    await _pump(
      tester,
      const TravelPartnerPage(userId: 42),
      size: const Size(1440, 1600),
    );
    expect(tester.takeException(), isNull);
  });
}
