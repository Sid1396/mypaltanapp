import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/team.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../controllers/team_controllers.dart';
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show SmallButtonLarge;

class MyTeamsPage extends StatelessWidget {
  const MyTeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MyTeamsController());
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.load,
          child: Obx(() => ListView(
                padding: EdgeInsets.only(bottom: SizeConfig.h(120)),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(16), SizeConfig.w(20), SizeConfig.h(16)),
                    child: Row(
                      children: [
                        Text('My Teams',
                            style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(26), color: Colors.white)),
                        const Spacer(),
                        GestureDetector(
                          key: const ValueKey('team-join-code'),
                          onTap: showJoinTeamWithCode,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(8)),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                              border: Border.all(color: AppColors.primary.withAlpha(70)),
                            ),
                            child: Row(children: [
                              Icon(Icons.qr_code_rounded, size: SizeConfig.r(16), color: AppColors.primary),
                              SizedBox(width: SizeConfig.w(6)),
                              Text('Join with code', style: tfStyle(12.5, weight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.isLoading.value && c.items.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: SizeConfig.h(60)),
                      child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (c.items.isEmpty)
                    EmptyCard(
                      icon: Icons.shield_rounded,
                      title: "You're not in a team yet",
                      message: 'Create a team and share its link, or open a link a captain sent you.',
                      actions: [
                        SmallButton(label: 'Join with code', filled: false, onTap: showJoinTeamWithCode),
                        SmallButton(key: const ValueKey('team-create-empty'), label: 'Create team', onTap: c.create),
                      ],
                    )
                  else ...[
                    for (final t in c.items)
                      Padding(
                        padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(12)),
                        child: _TeamCard(t: t, onTap: () => c.open(t.code)),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                      child: SmallButton(key: const ValueKey('team-create'), label: 'Create a team', filled: false, onTap: c.create),
                    ),
                  ],
                ],
              )),
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final MyTeam t;
  final VoidCallback onTap;
  const _TeamCard({required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = {'COACH': 'COACH', 'CAPTAIN': 'CAPTAIN', 'VICE_CAPTAIN': 'VICE-CAPTAIN'}[t.role] ?? 'PLAYER';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(18)), border: Border.all(color: Colors.white.withAlpha(12))),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SizeConfig.r(14)),
              child: SizedBox(
                width: SizeConfig.r(58),
                height: SizeConfig.r(58),
                child: t.logoUrl != null
                    ? Image.network(t.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
                    : const ColoredBox(color: Color(0xFF2A2A2A)),
              ),
            ),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role, style: tfStyle(10, weight: FontWeight.w800, color: t.role == 'PLAYER' ? Colors.white.withAlpha(120) : AppColors.primary)),
                  gapH(2),
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(16, weight: FontWeight.w800)),
                  Text('${Sports.byCode(t.sport)?.label ?? t.sport} · ${t.area} · ${t.members} ${t.members == 1 ? 'player' : 'players'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(12, color: Colors.white.withAlpha(140))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100)),
          ],
        ),
      ),
    );
  }
}

/// Opens a team from the 6-character code in its link.
void showJoinTeamWithCode() {
  final ctrl = TextEditingController();
  void go() {
    final code = ctrl.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      AppSnackbar.error('Team code', 'Codes have 6 letters and numbers. The captain can find it in the team link.');
      return;
    }
    Get.back();
    // Open through My Teams so the list refreshes after joining.
    if (Get.isRegistered<MyTeamsController>()) {
      Get.find<MyTeamsController>().open(code);
    } else {
      Get.toNamed(AppRoutes.team, arguments: {'code': code});
    }
  }

  Get.bottomSheet(
    SheetFrame(title: 'Join a team', children: [
      Text('Enter the 6-character code from the team link, e.g. mypaltan.com/team/AB12CD.', style: tfStyle(13.5, color: Colors.white.withAlpha(160))),
      gapH(14),
      FieldTextInput(
        key: const ValueKey('team-code-field'),
        controller: ctrl,
        hint: 'e.g. AB12CD',
        maxLength: 6,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => go(),
      ),
      gapH(16),
      SizedBox(width: double.infinity, child: SmallButtonLarge(key: const ValueKey('team-code-go'), label: 'Open team', onTap: go)),
    ]),
    isScrollControlled: true,
  );
}
