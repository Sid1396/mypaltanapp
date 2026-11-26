import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../utils/helpers/size_config.dart';
import 'tournament_form_widgets.dart';

/// The tournament's YouTube live stream, played in the app (YouTube's embed page), with "Open in YouTube".
class TournamentLiveTab extends StatefulWidget {
  final String url;
  const TournamentLiveTab({super.key, required this.url});

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
    final id = videoId(widget.url);
    if (id == null) return;
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const {})
        : const PlatformWebViewControllerCreationParams();
    _web = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      // Taps on YouTube links inside the player (title, logo, "watch on YouTube") open the YouTube app instead.
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
        if (r.url.contains('/embed/') || !r.isMainFrame) return NavigationDecision.navigate;
        launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      }))
      // YouTube requires embeds to say which app shows them (a Referer); without it the player refuses (error 152/153).
      ..loadRequest(Uri.parse('https://www.youtube.com/embed/$id?playsinline=1&rel=0&modestbranding=1'), headers: {'Referer': 'https://mypaltan.com/'});
  }

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
      gapH(12),
      OutlinedButton.icon(
        onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
        label: Text('Open in YouTube', style: tfStyle(14, weight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withAlpha(40)),
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
        ),
      ),
    ]);
  }
}
