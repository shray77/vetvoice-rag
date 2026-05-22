import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_colors_resolver.dart';
import '../../core/constants/app_constants.dart';

/// Экран VetLearn — WebView с существующим веб-приложением
class VetlearnScreen extends StatefulWidget {
  const VetlearnScreen({super.key});

  @override
  State<VetlearnScreen> createState() => _VetlearnScreenState();
}

class _VetlearnScreenState extends State<VetlearnScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _title = 'VetLearn';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ошибка загрузки: ${error.description}'),
                backgroundColor: AppColors.error,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiConfig.vetlearnUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsResolver.background(context),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
