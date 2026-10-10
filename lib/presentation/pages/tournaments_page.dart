import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import '../controllers/my_tournaments_controller.dart';
import '../../config/app_routes.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../widgets/form_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show SmallButtonLarge;
import '../widgets/home_widgets.dart';

class TournamentsPage extends StatefulWidget {
  const TournamentsPage({super.key});

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  int _tab = 0;

  final _mine = Get.put(MyTournamentsController());

  List<Widget> _myTournaments() {
    final m = _mine;
    if (m.isLoading.value && m.items.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(top: SizeConfig.h(60)),
          child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    if (m.items.isEmpty) {
      return [
        EmptyCard(
          icon: Icons.emoji_events_outlined,
          title: 'No tournaments yet',
          message: 'Tournaments you play in, organise or score will be listed here.',
          actions: [SmallButton(label: 'Create a tournament', onTap: m.create)],
        ),
      ];
    }
    return [
      for (final t in m.items)
        Padding(
          padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(12)),
          child: MyTournamentCard(t: t, onTap: () => m.open(t.code)),
        ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
        child: SmallButton(
          label: m.items.any((t) => t.role == 'ORGANIZER') ? 'Create another tournament' : 'Organise a tournament',
          filled: false,
          onTap: m.create,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _tab == 0 ? c.load() : _mine.load(),
          child: Obx(() => ListView(
                key: const ValueKey('tournaments-list'),
                padding: EdgeInsets.only(bottom: SizeConfig.h(120)),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(16), SizeConfig.w(20), SizeConfig.h(16)),
                    child: Row(
                      children: [
                        Text(
                          'Tournaments',
                          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(26), color: Colors.white),
                        ),
                        const Spacer(),
                        GestureDetector(
                          key: const ValueKey('join-with-code'),
                          onTap: showJoinWithCode,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(8)),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                              border: Border.all(color: AppColors.primary.withAlpha(70)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_rounded, size: SizeConfig.r(16), color: AppColors.primary),
                                SizedBox(width: SizeConfig.w(6)),
                                Text('Join with code',
                                    style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(12.5), color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                    child: _Segmented(
                      labels: const ['Upcoming', 'My tournaments'],
                      index: _tab,
                      onChanged: (i) {
                        setState(() => _tab = i);
                        if (i == 1) _mine.ensureLoaded();
                      },
                    ),
                  ),
                  SizedBox(height: SizeConfig.h(16)),
                  if (_tab == 0) ...[
                    if (c.isLoading.value && c.tournaments.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: SizeConfig.h(60)),
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      )
                    else if (c.tournaments.isEmpty)
                      const EmptyCard(icon: Icons.emoji_events_rounded, title: 'No tournaments yet', message: 'New tournaments in your city will be listed here.')
                    else
                      for (final t in c.tournaments)
                        Padding(
                          padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(14)),
                          child: TournamentCard(t: t),
                        ),
                  ] else
                    ..._myTournaments(),
                ],
              )),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const _Segmented({required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SizeConfig.r(4)),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: SizeConfig.h(10)),
                decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: sel ? Colors.white : Colors.white.withAlpha(140)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}


/// Opens a tournament from a 6-character code someone shared (e.g. read out at the ground).
void showJoinWithCode() {
  final ctrl = TextEditingController();
  void go() {
    final code = ctrl.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      AppSnackbar.error('Tournament code', 'Codes have 6 letters and numbers, e.g. CPL27X.');
      return;
    }
    Get.back();
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
  }

  Get.bottomSheet(
    SheetFrame(
      title: 'Join with code',
      children: [
        Text('Enter the 6-character code from the organiser.', style: tfStyle(13.5, color: Colors.white.withAlpha(160))),
        gapH(14),
        FieldTextInput(
          key: const ValueKey('join-code-field'),
          controller: ctrl,
          hint: 'e.g. CPL27X',
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => go(),
        ),
        gapH(16),
        SizedBox(width: double.infinity, child: SmallButtonLarge(key: const ValueKey('join-code-go'), label: 'Open tournament', onTap: go)),
      ],
    ),
    isScrollControlled: true,
  );
}
