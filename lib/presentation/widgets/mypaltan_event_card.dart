import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/mypaltan_controller.dart';

class MyPaltanEventCard extends StatelessWidget {
  final CommunityEvent event;
  const MyPaltanEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final spotsLeft = event.maxSpots - event.joined;
    final isFull = spotsLeft <= 0;
    final progress = event.joined / event.maxSpots;

    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.h(16)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(20)),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner ──────────────────────────────────────
          Container(
            height: SizeConfig.h(80),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary.withAlpha(110), AppColors.secondary],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(event.emoji, style: TextStyle(fontSize: SizeConfig.sp(38))),
                ),
                Positioned(
                  top: SizeConfig.h(10),
                  left: SizeConfig.w(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig.w(10),
                      vertical: SizeConfig.h(4),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(130),
                      borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                    ),
                    child: Text(
                      event.sport,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.sp(11),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: SizeConfig.h(10),
                  right: SizeConfig.w(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig.w(10),
                      vertical: SizeConfig.h(4),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                    ),
                    child: Text(
                      event.feeLabel,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.sp(11),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(SizeConfig.w(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                    fontSize: SizeConfig.sp(16),
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: SizeConfig.h(10)),
                _MetaRow(icon: Icons.calendar_today_rounded, text: event.dateTime),
                SizedBox(height: SizeConfig.h(6)),
                _MetaRow(icon: Icons.location_on_rounded, text: event.location),
                SizedBox(height: SizeConfig.h(6)),
                _MetaRow(icon: Icons.person_rounded, text: 'Organized by ${event.organizer}'),
                SizedBox(height: SizeConfig.h(14)),

                // ── Spots progress ─────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(SizeConfig.r(4)),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: SizeConfig.h(5),
                    backgroundColor: Colors.white.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation(
                      isFull ? AppColors.negative : AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Row(
                  children: [
                    Text(
                      isFull ? 'Fully booked' : '${event.joined}/${event.maxSpots} joined',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.sp(12),
                        color: isFull ? AppColors.negative : Colors.white.withAlpha(160),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: SizeConfig.h(38),
                      child: ElevatedButton(
                        onPressed: isFull ? null : () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.white.withAlpha(20),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SizeConfig.r(10)),
                          ),
                        ),
                        child: Text(
                          isFull ? 'Full' : 'Join',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: SizeConfig.sp(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: SizeConfig.r(14)),
        SizedBox(width: SizeConfig.w(8)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              fontSize: SizeConfig.sp(12.5),
              color: Colors.white.withAlpha(160),
            ),
          ),
        ),
      ],
    );
  }
}
