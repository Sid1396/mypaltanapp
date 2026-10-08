import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../data/models/tournament.dart';
import '../../data/services/deep_link_service.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import 'create_tournament_steps.dart' show rupees;
import 'tournament_form_widgets.dart';

const _sportEmoji = {'CRICKET': '🏏', 'FOOTBALL': '⚽', 'BADMINTON': '🏸', 'PICKLEBALL': '🎾'};
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDates(Tournament t) {
  final s = t.startDate, e = t.endDate;
  if (s == null) return '';
  if (e == null || e == s) return '${s.day} ${_months[s.month - 1]}';
  if (s.month == e.month) return '${s.day}–${e.day} ${_months[s.month - 1]}';
  return '${s.day} ${_months[s.month - 1]} – ${e.day} ${_months[e.month - 1]}';
}

String shareMessage(Tournament t) {
  final lines = [
    '${_sportEmoji[t.sport] ?? '🏆'} *${t.name}*',
    '📅 ${shortDates(t)} · 📍 ${t.area}',
    '💰 ${t.entryFee > 0 ? 'Entry ${rupees(t.entryFee)}' : 'Free entry'}${t.prizeType != 'NONE' && t.prizeDetails != null ? ' · 🏆 ${t.prizeDetails}' : ''}',
    '',
    'Register your team on MyPaltan 👇',
    DeepLinkService.tournamentUrl(t.code),
  ];
  return lines.join('\n');
}

void showTournamentShareSheet(Tournament t) {
  final url = DeepLinkService.tournamentUrl(t.code);
  Widget option({required Key key, required IconData icon, required Color color, required String label, required VoidCallback onTap}) =>
      Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: SizeConfig.r(56),
                height: SizeConfig.r(56),
                decoration: BoxDecoration(color: color.withAlpha(35), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: SizeConfig.r(26)),
              ),
              gapH(8),
              Text(label, textAlign: TextAlign.center, style: tfStyle(12.5, weight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Get.bottomSheet(
    SheetFrame(
      title: 'Share tournament',
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(12)),
          decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
          child: Row(
            children: [
              Icon(Icons.link_rounded, color: AppColors.primary, size: SizeConfig.r(20)),
              SizedBox(width: SizeConfig.w(10)),
              Expanded(child: Text(url.replaceFirst('https://', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w600))),
            ],
          ),
        ),
        gapH(20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            option(
              key: const ValueKey('share-whatsapp'),
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              label: 'WhatsApp',
              onTap: () => _shareToWhatsApp(t),
            ),
            option(
              key: const ValueKey('share-copy'),
              icon: Icons.copy_rounded,
              color: Colors.white,
              label: 'Copy link',
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                Get.back();
                AppSnackbar.success('Link copied', 'Paste it anywhere to invite captains.');
              },
            ),
            option(
              key: const ValueKey('share-poster'),
              icon: Icons.qr_code_2_rounded,
              color: AppColors.primary,
              label: 'QR poster',
              onTap: () {
                Get.back();
                Get.to(() => TournamentPosterPage(t: t), transition: Transition.downToUp);
              },
            ),
            option(
              key: const ValueKey('share-more'),
              icon: Icons.ios_share_rounded,
              color: Colors.white,
              label: 'More',
              onTap: () {
                Get.back();
                SharePlus.instance.share(ShareParams(text: shareMessage(t), subject: t.name));
              },
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _shareToWhatsApp(Tournament t) async {
  Get.back();
  final text = Uri.encodeComponent(shareMessage(t));
  final opened = await launchUrl(Uri.parse('whatsapp://send?text=$text'), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!opened) await SharePlus.instance.share(ShareParams(text: shareMessage(t), subject: t.name));
}

// ─── QR poster ──────────────────────────────────────────────────

/// Full-screen preview of a branded 4:5 poster that can be shared or saved as an image.
class TournamentPosterPage extends StatefulWidget {
  final Tournament t;
  const TournamentPosterPage({super.key, required this.t});

  @override
  State<TournamentPosterPage> createState() => _TournamentPosterPageState();
}

class _TournamentPosterPageState extends State<TournamentPosterPage> {
  final _posterKey = GlobalKey();
  bool _sharing = false;
  bool _logoReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logo = widget.t.logoUrl;
    if (logo == null) {
      _logoReady = true;
      return;
    }
    // The logo must be loaded before the poster is turned into an image.
    precacheImage(NetworkImage(logo), context).whenComplete(() {
      if (mounted) setState(() => _logoReady = true);
    });
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mypaltan_${widget.t.code}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${widget.t.name}\nRegister your team: ${DeepLinkService.tournamentUrl(widget.t.code)}',
      ));
    } catch (e) {
      AppSnackbar.error('Poster', "Couldn't create the poster. Please try again.");
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(12), SizeConfig.h(8), SizeConfig.w(20), 0),
              child: Row(
                children: [
                  IconButton(key: const ValueKey('poster-close'), onPressed: Get.back, icon: const Icon(Icons.close_rounded, color: Colors.white)),
                  Text('QR poster', style: tfStyle(17, weight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24), vertical: SizeConfig.h(12)),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: _logoReady
                        ? RepaintBoundary(key: _posterKey, child: TournamentPoster(t: widget.t))
                        : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(24), 0, SizeConfig.w(24), SizeConfig.h(16)),
              child: Text('Share it on WhatsApp status or Instagram, or print it for the ground.',
                  textAlign: TextAlign.center, style: tfStyle(12.5, color: Colors.white.withAlpha(140))),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(24), 0, SizeConfig.w(24), SizeConfig.h(16)),
              child: SizedBox(
                width: double.infinity,
                height: SizeConfig.h(54),
                child: ElevatedButton.icon(
                  key: const ValueKey('poster-share'),
                  onPressed: _sharing || !_logoReady ? null : _share,
                  icon: _sharing
                      ? SizedBox(width: SizeConfig.r(18), height: SizeConfig.r(18), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.ios_share_rounded),
                  label: Text('Share or save poster', style: tfStyle(15.5, weight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withAlpha(110),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The poster itself. Sized by its parent (4:5), everything scales from the width.
class TournamentPoster extends StatelessWidget {
  final Tournament t;
  const TournamentPoster({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      double u(double v) => w * v / 340; // design units on a 340-wide poster
      TextStyle s(double size, {FontWeight weight = FontWeight.w600, Color color = Colors.white, double? height, double? spacing}) =>
          TextStyle(fontFamily: 'Gilroy', fontSize: u(size), fontWeight: weight, color: color, height: height, letterSpacing: spacing);
      final sport = Sports.byCode(t.sport);
      final url = DeepLinkService.tournamentUrl(t.code);
      return ClipRRect(
        borderRadius: BorderRadius.circular(u(18)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C1C1C), Color(0xFF121212), Color(0xFF2A1208)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: [
              // Orange glow and a large faded sport icon for depth
              Positioned(
                right: -u(80),
                top: -u(80),
                child: Container(
                  width: u(240),
                  height: u(240),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(45)),
                ),
              ),
              if (sport != null)
                Positioned(right: -u(20), top: u(40), child: Opacity(opacity: 0.08, child: Image.asset(sport.asset, width: u(170)))),
              Padding(
                padding: EdgeInsets.all(u(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/images/paltan_combine_logo.png', height: u(22)),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: u(9), vertical: u(4)),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(u(100))),
                          child: Text(t.status == 'REGISTRATION_OPEN' ? 'REGISTRATION OPEN' : t.statusLabel.toUpperCase(), style: s(7.5, weight: FontWeight.w800, spacing: 0.6)),
                        ),
                      ],
                    ),
                    SizedBox(height: u(20)),
                    Row(
                      children: [
                        Container(
                          width: u(62),
                          height: u(62),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(u(14)),
                            border: Border.all(color: Colors.white.withAlpha(30), width: u(1.2)),
                          ),
                          child: t.logoUrl != null ? Image.network(t.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()) : null,
                        ),
                        SizedBox(width: u(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${sport?.label.toUpperCase() ?? t.sport} TOURNAMENT', style: s(8.5, weight: FontWeight.w800, color: AppColors.primary, spacing: 1)),
                              SizedBox(height: u(3)),
                              Text(t.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: s(19, weight: FontWeight.w900, height: 1.05)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: u(16)),
                    _fact(u, s, Icons.calendar_today_rounded, shortDates(t)),
                    _fact(u, s, Icons.place_rounded, [t.area, t.city].where((x) => x.isNotEmpty).join(', ')),
                    _fact(u, s, Icons.currency_rupee_rounded,
                        '${t.entryFee > 0 ? 'Entry ${rupees(t.entryFee)}' : 'Free entry'}  ·  ${t.maxTeams} teams'),
                    if (t.prizeType != 'NONE' && t.prizeDetails != null) _fact(u, s, Icons.emoji_events_rounded, t.prizeDetails!),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SCAN TO\nREGISTER', style: s(22, weight: FontWeight.w900, height: 0.95)),
                              SizedBox(height: u(8)),
                              Text('Captains, register your team on the MyPaltan app.', style: s(9, weight: FontWeight.w500, color: Colors.white.withAlpha(170), height: 1.3)),
                              SizedBox(height: u(10)),
                              Text(url.replaceFirst('https://', ''), style: s(8.5, weight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        SizedBox(width: u(10)),
                        Container(
                          padding: EdgeInsets.all(u(7)),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(u(14))),
                          child: QrImageView(
                            data: url,
                            size: u(118),
                            padding: EdgeInsets.zero,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF121212)),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF121212)),
                            embeddedImage: const AssetImage('assets/images/paltan_logo.png'),
                            embeddedImageStyle: QrEmbeddedImageStyle(size: Size(u(24), u(24))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _fact(double Function(double) u, TextStyle Function(double, {FontWeight weight, Color color, double? height, double? spacing}) s, IconData icon, String text) =>
      Padding(
        padding: EdgeInsets.only(bottom: u(7)),
        child: Row(
          children: [
            Container(
              width: u(20),
              height: u(20),
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(40), borderRadius: BorderRadius.circular(u(6))),
              child: Icon(icon, size: u(11), color: AppColors.primary),
            ),
            SizedBox(width: u(8)),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(11, weight: FontWeight.w600))),
          ],
        ),
      );
}
