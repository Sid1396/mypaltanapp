import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../widgets/home_widgets.dart';

class MyTeamsPage extends StatelessWidget {
  const MyTeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: SizeConfig.h(120)),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(16), SizeConfig.w(20), SizeConfig.h(16)),
              child: Text(
                'My Teams',
                style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(26), color: Colors.white),
              ),
            ),
            EmptyCard(
              icon: Icons.shield_rounded,
              title: "You're not in a team yet",
              message: 'Teams you captain or play for will be listed here, with their squad, invite link and results.',
              actions: [
                SmallButton(label: 'Join with code', filled: false, onTap: () => showComingSoon('Joining teams')),
                SmallButton(label: 'Create team', onTap: () => showComingSoon('Creating teams')),
              ],
            ),
            SizedBox(height: SizeConfig.h(20)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: Text(
                'HOW TEAMS WORK',
                style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(12), letterSpacing: 1, color: Colors.white.withAlpha(120)),
              ),
            ),
            SizedBox(height: SizeConfig.h(10)),
            for (final (icon, title, body) in const [
              (Icons.add_circle_outline_rounded, 'Create a team', 'Pick a sport, name and logo. You become the captain.'),
              (Icons.link_rounded, 'Share one link', 'Send the team link on WhatsApp. Players tap it and join.'),
              (Icons.emoji_events_outlined, 'Enter tournaments', 'Register your team in tournaments with the same squad.'),
            ])
              Padding(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.primary, size: SizeConfig.r(22)),
                    SizedBox(width: SizeConfig.w(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: Colors.white)),
                          Text(body, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(140), height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
