import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
    return Scaffold(
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
                h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                blockquote: TextStyle(
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
                listBullet: Theme.of(context).textTheme.bodyMedium,
              ),
              padding: const EdgeInsets.all(16),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '加载文档失败',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
