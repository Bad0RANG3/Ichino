import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/strings.dart';
import '../config/title_server_config.dart';
import '../widgets/app_button.dart';
import '../widgets/app_page.dart';

class ConfigExportImportPage extends StatelessWidget {
  const ConfigExportImportPage({super.key});

  Future<void> _exportConfig(BuildContext context) async {
    final config = TitleServerConfigHolder().config;
    if (config == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.noConfigToExport)),
        );
      }
      return;
    }

    final json = jsonEncode(config.toJson());
    final base64 = base64Encode(utf8.encode(json));
    await Clipboard.setData(ClipboardData(text: base64));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.exportSuccess)),
      );
    }
  }

  Future<void> _importConfig(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.importFailed)),
        );
      }
      return;
    }

    try {
      final json = utf8.decode(base64Decode(text));
      final map = jsonDecode(json) as Map<String, dynamic>;
      final config = TitleServerConfig.fromJson(map);
      await TitleServerConfigHolder().update(config);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.importSuccess)),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.importFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.configExportImport),
      ),
      body: AppPageBody(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: AppStrings.exportConfig,
              icon: Icons.upload,
              verticalPadding: 16,
              onPressed: () => _exportConfig(context),
            ),
            const SizedBox(height: 16),
            AppOutlinedButton(
              label: AppStrings.importConfig,
              icon: Icons.download,
              verticalPadding: 16,
              onPressed: () => _importConfig(context),
            ),
          ],
        ),
      ),
    );
  }
}
