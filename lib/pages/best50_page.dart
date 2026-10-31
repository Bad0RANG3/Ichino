import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../models/session_model.dart';
import '../models/user_rating.dart';
import '../services/music_data_service.dart';
import '../services/png_export_service.dart';
import '../services/rating_calculator.dart';
import '../services/title_api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_page.dart';
import '../widgets/best50_poster.dart';

/// Best 50 成绩图页面：负责取数与导出，海报本身在 `widgets/best50_poster.dart`。
///
/// GetUserRatingApi 只需要 userId（Cookie 是可选的，与 Empurple 的
/// `UserRatingRequest` + `MaimaiApiClient` 一致），所以 Preview API 模式、
/// 未登录游戏服务器时同样能拉出 B50，只是拿不到 FC/AP、FS 这类详细标记。
class Best50Page extends StatefulWidget {
  final int userId;
  final String? cookies;
  final String userName;
  final int iconId;
  final int playerRating;

  const Best50Page({
    super.key,
    required this.userId,
    this.cookies,
    required this.userName,
    required this.iconId,
    required this.playerRating,
  });

  @override
  State<Best50Page> createState() => _Best50PageState();
}

class _Best50PageState extends State<Best50Page> {
  final GlobalKey _posterKey = GlobalKey();

  UserRatingBean? _rating;
  String? _error;
  bool _loading = true;
  bool _exporting = false;
  bool _musicReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(Best50Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 用户可能在 preview/登录请求完成前就切到本页，cookies 到位后再补一次加载。
    if (oldWidget.cookies != widget.cookies &&
        (_rating == null || _error != null)) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (!TitleServerConfigHolder().isConfigured) {
      _fail(AppStrings.ticketNotConfigured);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = SessionModel.instance.createTitleService(
        cookies: widget.cookies,
      )!;
      final rating = await service.getUserRatingTyped(widget.userId);
      if (!mounted) return;
      setState(() {
        _rating = rating;
        _loading = false;
      });

      // 曲名/定数缺失时仍能出图（RA 会是 0），所以不当作致命错误。
      await MusicDataService.instance.load();
      if (!mounted) return;
      setState(() => _musicReady = true);
    } catch (e) {
      _fail(describeApiError(e));
    }
  }

  void _fail(String message) {
    setState(() {
      _loading = false;
      _rating = null;
      _error = message;
    });
  }

  List<Best50CardData> _resolve(List<UserRatingItemBean> items) {
    final music = MusicDataService.instance;
    return items.map((item) {
      final result = RatingCalculator.compute(
        music.getDs(item.musicId, item.level),
        item.achievementPercent,
      );
      return Best50CardData(
        musicId: item.musicId,
        level: item.musicLevel,
        title: music.getTitle(item.musicId),
        achievementText: item.achievementText,
        comboStatus: item.comboStatus,
        syncStatus: item.syncStatus,
        ra: result.ra,
        rate: result.rate,
      );
    }).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary =
          _posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('海报尚未完成布局');

      final image = await boundary.toImage(pixelRatio: Best50Poster.exportPixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('PNG 编码失败');

      final path = await exportPng(
        byteData.buffer.asUint8List(),
        'best50_${widget.userId}.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.best50Exported(path))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.best50ExportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rating = _rating;
    if (rating == null) {
      return AppStateView(
        icon: Icons.error_outline,
        title: AppStrings.loadFailed,
        description: _error,
        error: true,
        actionLabel: AppStrings.retry,
        onAction: _bootstrap,
      );
    }

    // 没有成绩是「空」，不是「错」——这里不该用报错色。
    if (rating.ratingList.isEmpty && rating.newRatingList.isEmpty) {
      return AppStateView(
        icon: Icons.bar_chart_outlined,
        title: AppStrings.best50Empty,
        actionLabel: AppStrings.retry,
        onAction: _bootstrap,
      );
    }

    final best35 = _resolve(
      rating.ratingList.take(Best50Poster.maxBest35).toList(),
    );
    final best15 = _resolve(
      rating.newRatingList.take(Best50Poster.maxBest15).toList(),
    );

    return Scaffold(
      body: Column(
        children: [
          AppPageBody(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (!_musicReady)
                  const AppNotice(
                    AppStrings.best50NoMusicData,
                    icon: Icons.info_outline,
                  ),
                AppButton(
                  label: _exporting
                      ? AppStrings.best50Exporting
                      : AppStrings.best50Export,
                  icon: Icons.download,
                  busy: _exporting,
                  onPressed: _export,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 海报要按视口整体缩放一档，进来才能看见完整一张（之前的现象是
                // 「太大且缩不小」）。两处坑：
                //  1. InteractiveViewer(constrained:false) 给子节点无界约束，
                //     此时 FittedBox 根本不会缩放，必须先给一个有限大小的盒子。
                //  2. InteractiveViewer 没有 initialScale，所以「初始就缩到位」
                //     只能靠把子节点做成 contain 尺寸、minScale 固定 1.0。
                // RepaintBoundary 放在 FittedBox 内侧：它自身的绘制尺寸仍是
                // 1762x1850，导出分辨率不受这里缩放影响。
                final fitWidth =
                    constraints.maxWidth / Best50Poster.canvasWidth;
                final fitHeight =
                    constraints.maxHeight / Best50Poster.canvasHeight;
                final contain = fitWidth < fitHeight ? fitWidth : fitHeight;

                return Center(
                  child: InteractiveViewer(
                    constrained: false,
                    minScale: 1.0,
                    maxScale: 10.0,
                    boundaryMargin: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: Best50Poster.canvasWidth * contain,
                      height: Best50Poster.canvasHeight * contain,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: RepaintBoundary(
                          key: _posterKey,
                          child: Best50Poster(
                            userName: widget.userName,
                            iconId: widget.iconId,
                            playerRating: widget.playerRating,
                            best35: best35,
                            best15: best15,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
