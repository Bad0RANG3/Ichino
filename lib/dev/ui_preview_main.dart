import 'package:flutter/material.dart';

import '../config/title_server_config.dart';
import '../main.dart';
import '../pages/home_page.dart';
import 'ui_preview_data.dart';

/// 开发期 UI 预览入口：跳过二维码登录，直接用假数据进主页。
///
/// flutter run -d windows -t lib/dev/ui_preview_main.dart --no-pub
///
/// 登录态与 Title Server 配置都是假的：票据 / 风险这些页面按「已登录 + 已配置」
/// 渲染，只有真去点发请求的按钮才会失败（URL 指向本机未监听的端口）。
/// 想调主页各卡片的数值就改 `ui_preview_data.dart`。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 不配的话票据/风险页会停在「请先配置 Title Server」，看不到真正的页面。
  await TitleServerConfigHolder().update(uiPreviewConfig);
  runApp(
    MyApp(
      home: HomePage(
        userId: uiPreviewUserId,
        token: uiPreviewToken,
        restored: createUiPreviewSession(),
      ),
    ),
  );
}
