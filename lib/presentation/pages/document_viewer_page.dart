import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../widgets/tournament_form_widgets.dart';

/// In-app viewer for tournament documents. Arguments: {'title', 'url', 'pdf': bool}.
class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({super.key});

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late final Map args = Get.arguments as Map;
  String? _pdfPath;
  String? _error;
  int _pages = 0;
  int _page = 0;

  bool get _isPdf => args['pdf'] == true;

  @override
  void initState() {
    super.initState();
    if (_isPdf) _download();
  }

  /// Signed links expire, so the PDF is downloaded fresh into a temp file each time.
  Future<void> _download() async {
    try {
      final res = await http.get(Uri.parse(args['url'] as String)).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/doc_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(res.bodyBytes);
      if (mounted) setState(() => _pdfPath = file.path);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't open this document. Check your connection and try again.");
    }
  }

  @override
  void dispose() {
    if (_pdfPath != null) File(_pdfPath!).delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_error != null) {
      body = Center(child: Padding(padding: EdgeInsets.all(SizeConfig.r(24)), child: Text(_error!, textAlign: TextAlign.center, style: tfStyle(14, color: Colors.white.withAlpha(170)))));
    } else if (!_isPdf) {
      body = InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.network(
            args['url'] as String,
            loadingBuilder: (_, child, p) => p == null ? child : const CircularProgressIndicator(color: AppColors.primary),
            errorBuilder: (_, __, ___) => Text("Couldn't load this image.", style: tfStyle(14, color: Colors.white.withAlpha(170))),
          ),
        ),
      );
    } else if (_pdfPath == null) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else {
      body = PDFView(
        filePath: _pdfPath,
        nightMode: false,
        fitPolicy: FitPolicy.WIDTH,
        backgroundColor: const Color(0xFF121212),
        onRender: (pages) => setState(() => _pages = pages ?? 0),
        onPageChanged: (page, _) => setState(() => _page = page ?? 0),
        onError: (_) => setState(() => _error = "Couldn't open this document."),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(key: const ValueKey('doc-back'), onPressed: Get.back, icon: const Icon(Icons.arrow_back_ios_new_rounded)),
        title: Text(args['title']?.toString() ?? 'Document', style: tfStyle(16, weight: FontWeight.w700)),
        actions: [
          if (_pages > 1)
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: SizeConfig.w(16)),
                child: Text('${_page + 1} / $_pages', style: tfStyle(13, color: Colors.white.withAlpha(160))),
              ),
            ),
        ],
      ),
      body: body,
    );
  }
}
