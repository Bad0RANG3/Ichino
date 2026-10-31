import 'package:flutter/material.dart';

import '../../config/strings.dart';
import '../../models/user_data.dart';
import '../../models/user_preview.dart';
import '../app_card.dart';
import 'home_common.dart';

class RatingBreakdownCard extends StatelessWidget {
  final UserDataBean data;

  const RatingBreakdownCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: AppStrings.ratingBreakdown,
      rows: [
        (AppStrings.musicRating, '${data.musicRating}'),
        (AppStrings.newChartRating, '${data.playerNewRating}'),
        (AppStrings.oldChartRating, '${data.playerOldRating}'),
        (AppStrings.highestRating, '${data.highestRating}'),
      ],
    );
  }
}

class FirstPlayCard extends StatelessWidget {
  final UserDataBean data;

  const FirstPlayCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: AppStrings.firstPlay,
      rows: [
        (AppStrings.joinDate, data.firstPlayDate),
        (AppStrings.firstGame, data.firstGameId),
        (AppStrings.firstRomVersion, data.firstRomVersion),
        (AppStrings.firstDataVersion, data.firstDataVersion),
      ],
    );
  }
}

class GameInfoFromUserDataCard extends StatelessWidget {
  final UserDataBean data;

  const GameInfoFromUserDataCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: AppStrings.gameInfo,
      rows: [
        (AppStrings.lastGame, data.lastGameId),
        (AppStrings.lastPlay, data.lastPlayDate),
        (AppStrings.lastLogin, data.lastLoginDate),
        (AppStrings.romVersion, data.lastRomVersion),
        (AppStrings.dataVersion, data.lastDataVersion),
        (
          AppStrings.lastRegion,
          '${data.lastRegionName}${data.lastRegionId > 0 ? ' (${data.lastRegionId})' : ''}',
        ),
      ],
    );
  }
}

class PlayStatsCard extends StatelessWidget {
  final UserDataBean data;

  const PlayStatsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      title: AppStrings.playStats,
      rows: [
        (AppStrings.playCount, '${data.playCount}'),
        (AppStrings.currentPlayCount, '${data.currentPlayCount}'),
        (AppStrings.totalAchievement, '${data.totalAchievement}'),
        (AppStrings.totalDxScore, '${data.totalDeluxscore}'),
        (AppStrings.totalSync, '${data.totalSync}'),
        (AppStrings.totalAwake, '${data.totalAwake}'),
      ],
    );
  }
}

class StatusFromUserDataCard extends StatelessWidget {
  /// 用连接信息（仅 JSESSIONID）恢复的会话没有走 GetUserPreviewApi，可为空。
  final UserPreviewDataBean? preview;
  final UserDataBean data;

  const StatusFromUserDataCard({
    super.key,
    required this.preview,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final p = preview;

    return HomeStatusCard(
      chips: [
        HomeStatusChip(AppStrings.netMember, data.isNetMember),
        if (p != null) HomeStatusChip(AppStrings.inherit, p.isInherit),
        HomeStatusChip(
          AppStrings.banState,
          data.banState == 0,
          trueText: AppStrings.clean,
          falseText: AppStrings.banned(data.banState),
        ),
        HomeStatusChip(
          AppStrings.dailyBonus,
          data.dailyBonusDate.isNotEmpty &&
              !data.dailyBonusDate.startsWith('1970'),
          trueText: data.dailyBonusDate,
          falseText: AppStrings.notClaimed,
        ),
      ],
    );
  }
}

/// 可展开的原始字段卡。
class UserDataDetailCard extends StatefulWidget {
  final UserDataBean data;

  const UserDataDetailCard({super.key, required this.data});

  @override
  State<UserDataDetailCard> createState() => _UserDataDetailCardState();
}

class _UserDataDetailCardState extends State<UserDataDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;

    return AppCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionTitle(title: AppStrings.moreDetails)),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            // 「更多详情」里的字段名更长，标签列比主页统计卡宽一些。
            for (final (label, value) in [
              (AppStrings.userId, '${data.userId}'),
              (AppStrings.point, '${data.point}'),
              (AppStrings.totalPoint, '${data.totalPoint}'),
              (AppStrings.iconId, '${data.iconId}'),
              (AppStrings.nameplateId, '${data.nameplateId}'),
              (AppStrings.plateId, '${data.plateId}'),
              (AppStrings.frameId, '${data.frameId}'),
              (AppStrings.titleId, '${data.titleId}'),
              (AppStrings.trophyId, '${data.trophyId}'),
              (AppStrings.partnerId, '${data.partnerId}'),
              (AppStrings.gradeRank, '${data.gradeRank}'),
              (AppStrings.courseRank, '${data.courseRank}'),
              (AppStrings.classRank, '${data.classRank}'),
            ])
              AppInfoRow(label: label, value: value, labelWidth: 130),
          ],
        ],
      ),
    );
  }
}
