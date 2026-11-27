import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../utils/helpers/size_config.dart';
import 'tournament_form_widgets.dart';

/// The tournament's YouTube live stream with the MyPaltan live score bar on it (mypaltan.com/overlay preview: the
/// video plus the bar, 15 s late to match the stream), with a full-screen view of both.
class TournamentLiveTab extends StatefulWidget {
  final String url;
  final String code;
  final String name;
  const TournamentLiveTab({super.key, required this.url, required this.code, required this.name});

  @override
  State<TournamentLiveTab> createState() => _TournamentLiveTabState();
}

class _TournamentLiveTabState extends State<TournamentLiveTab> {
  WebViewController? _web;

  /// The video id from any YouTube link form (watch?v=, youtu.be/, live/, shorts/, embed/).
  static String? videoId(String url) => RegExp(r'(?:v=|youtu\.be/|/live/|/shorts/|/embed/)([A-Za-z0-9_-]{11})').firstMatch(url)?.group(1);

  @override
  void initState() {
    super.initState();
    if (videoId(widget.url) == null) return;
    _web = liveWebView(_page);
  }

  String get _page => 'https://mypaltan.com/overlay/${widget.code}';

  @override
  Widget build(BuildContext context) {
    final web = _web;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: SizeConfig.r(8),
          height: SizeConfig.r(8),
          decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
        ),
        SizedBox(width: SizeConfig.w(8)),
        Text('WATCH LIVE', style: tfStyle(12, weight: FontWeight.w900).copyWith(letterSpacing: 1)),
      ]),
      gapH(10),
      ClipRRect(
        borderRadius: BorderRadius.circular(SizeConfig.r(16)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: web == null
              ? Container(
                  color: const Color(0xFF1A1A1A),
                  alignment: Alignment.center,
                  child: Text('This live link cannot be played here.', style: tfStyle(13, color: Colors.white.withAlpha(160))),
                )
              : WebViewWidget(controller: web),
        ),
      ),
      if (web != null) ...[
        gapH(12),
        Row(children: [
          Expanded(
            child: _button(
              key: const ValueKey('live-fullscreen'),
              icon: Icons.fullscreen_rounded,
              label: 'Full screen',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LiveFullScreen(page: _page))),
            ),
          ),
          SizedBox(width: SizeConfig.w(10)),
          Expanded(
            child: _button(
              key: const ValueKey('live-share'),
              icon: Icons.ios_share_rounded,
              label: 'Share',
              // mypaltan.com/watch: the stream with the score bar in any browser, no app needed.
              onTap: () => SharePlus.instance.share(ShareParams(
                text: '🔴 Watch *${widget.name}* live with scores 👇\nhttps://mypaltan.com/watch/${widget.code}',
                subject: widget.name,
              )),
            ),
          ),
        ]),
      ],
    ]);
  }

  Widget _button({Key? key, required IconData icon, required String label, required VoidCallback onTap}) => OutlinedButton.icon(
        key: key,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: tfStyle(14, weight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withAlpha(40)),
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
        ),
      );
}

/// The live page (YouTube video with the MyPaltan score bar) in a web view. Links out of the player open the YouTube app.
WebViewController liveWebView(String page) {
  final params = WebViewPlatform.instance is WebKitWebViewPlatform
      ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const {})
      : const PlatformWebViewControllerCreationParams();
  return WebViewController.fromPlatformCreationParams(params)
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
      if (r.url.startsWith(page) || r.url.contains('/embed/') || !r.isMainFrame) return NavigationDecision.navigate;
      launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }))
    // The page embeds the YouTube player from mypaltan.com, so YouTube knows who shows it (no error 152/153); the bar runs
    // 15 s late to match the stream.
    ..loadRequest(Uri.parse('$page?preview=1&delay=15'));
}

/// Full screen: the video and the score bar together, sideways, with a close button.
class _LiveFullScreen extends StatefulWidget {
  final String page;
  const _LiveFullScreen({required this.page});

  @override
  State<_LiveFullScreen> createState() => _LiveFullScreenState();
}

class _LiveFullScreenState extends State<_LiveFullScreen> {
  late final WebViewController _web = liveWebView(widget.page);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: WebViewWidget(controller: _web)),
        Positioned(
          top: SizeConfig.r(12),
          right: SizeConfig.r(12),
          child: SafeArea(
            child: GestureDetector(
              key: const ValueKey('live-fullscreen-close'),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.all(SizeConfig.r(8)),
                decoration: BoxDecoration(color: Colors.black.withAlpha(140), shape: BoxShape.circle),
                child: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
