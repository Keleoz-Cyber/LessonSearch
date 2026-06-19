import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';

/// 通用 Markdown 文档查看页面
/// 用于显示隐私政策、用户协议等文档
class MarkdownDocumentPage extends StatelessWidget {
  final String title;
  final String assetPath;

  const MarkdownDocumentPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: Text(title),
      ),
      body: FutureBuilder(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Markdown(
              data: snapshot.data!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: AppTextStyles.h1.copyWith(color: c.brandPrimary),
                h2: AppTextStyles.h2.copyWith(color: c.textPrimary),
                h3: AppTextStyles.h3.copyWith(color: c.textPrimary),
                p: AppTextStyles.body.copyWith(
                  color: c.textPrimary,
                  height: 1.6,
                ),
                strong: AppTextStyles.bodyMedium.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                blockquote: AppTextStyles.body.copyWith(
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                listBullet: AppTextStyles.body.copyWith(color: c.textPrimary),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 32,
                    color: c.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '加载文档失败',
                    style: AppTextStyles.body.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(c.brandPrimary),
              ),
            ),
          );
        },
      ),
    );
  }
}