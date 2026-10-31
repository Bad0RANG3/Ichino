import 'package:flutter/material.dart';

import '../config/strings.dart';
import '../widgets/app_card.dart';
import '../widgets/app_notice.dart';
import '../widgets/app_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageBody(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
            const SizedBox(height: 24),
            Icon(
              Icons.qr_code_scanner,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.aboutTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.aboutDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    icon: Icons.info_outline,
                    title: AppStrings.aboutBasics,
                  ),
                  const SizedBox(height: 14),
                  AppInfoRow(label: AppStrings.creditBuiltWith, value: 'Flutter'),
                  AppInfoRow(
                    label: AppStrings.aboutPlatforms,
                    value: 'Android · iOS · Windows · macOS · Linux',
                  ),
                  AppInfoRow(
                    label: AppStrings.aboutPackageId,
                    value: 'dev.naominet.ichino',
                  ),
                  AppInfoRow(label: AppStrings.creditLicense, value: 'MIT'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    icon: Icons.group_outlined,
                    title: AppStrings.credits,
                  ),
                  const SizedBox(height: 14),
                  AppInfoRow(
                    label: AppStrings.creditProtocol,
                    value: 'empurple · eaquira',
                  ),
                  AppInfoRow(label: AppStrings.creditB50, value: 'Empurple'),
                  AppInfoRow(
                    label: AppStrings.creditQRDecode,
                    value: '原生 MethodChannel',
                  ),
                  AppInfoRow(
                    label: AppStrings.creditIconAssets,
                    value: 'assets2.lxns.net',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const AppNotice(
              AppStrings.aboutRiskNotice,
              icon: Icons.warning_amber_rounded,
            ),
          ],
      ),
    );
  }
}
