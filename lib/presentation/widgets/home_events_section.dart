import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import 'home_section_title.dart';

class HomeEventsSection extends StatelessWidget {
  final String title;
  final List<SportEvent> events;
  const HomeEventsSection({super.key, required this.title, required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(title),
        SizedBox(height: SizeConfig.h(14)),
        SizedBox(
          height: SizeConfig.h(210),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            itemCount: events.length,
            separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(14)),
            itemBuilder: (_, i) {
              final event = events[i];
              return Container(
                width: SizeConfig.w(220),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(SizeConfig.r(18)),
                  border: Border.all(color: Colors.white.withAlpha(15)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: SizeConfig.h(100),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withAlpha(100),
                            AppColors.secondary,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(event.emoji, style: TextStyle(fontSize: SizeConfig.sp(44))),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(SizeConfig.w(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: AppColors.primary, size: SizeConfig.r(13)),
                              SizedBox(width: SizeConfig.w(4)),
                              Expanded(
                                child: Text(
                                  event.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontWeight: FontWeight.w500,
                                    fontSize: SizeConfig.sp(11),
                                    color: Colors.white.withAlpha(160),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: SizeConfig.h(4)),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w700,
                              fontSize: SizeConfig.sp(14),
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: SizeConfig.h(6)),
                          Text(
                            event.dateTime,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w500,
                              fontSize: SizeConfig.sp(11),
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
