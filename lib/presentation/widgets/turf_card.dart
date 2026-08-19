import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/turf_controller.dart';

class TurfCard extends StatelessWidget {
  final TurfListing turf;
  const TurfCard({super.key, required this.turf});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.h(14)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(18)),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: SizeConfig.w(90),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withAlpha(100),
                    AppColors.secondary
                  ],
                ),
              ),
              child: Center(
                child: Text(turf.emoji,
                    style: TextStyle(fontSize: SizeConfig.sp(34))),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.w(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turf.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.sp(14),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(3)),
                    Text(
                      '${turf.distance} • ${turf.area}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(12),
                        color: Colors.white.withAlpha(140),
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(8)),
                    Wrap(
                      spacing: SizeConfig.w(6),
                      runSpacing: SizeConfig.h(6),
                      children: turf.sports
                          .map((s) => Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: SizeConfig.w(8),
                                  vertical: SizeConfig.h(3),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius:
                                      BorderRadius.circular(SizeConfig.r(6)),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontWeight: FontWeight.w600,
                                    fontSize: SizeConfig.sp(10),
                                    color: AppColors.primary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    SizedBox(height: SizeConfig.h(8)),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: AppColors.primary, size: SizeConfig.r(14)),
                        SizedBox(width: SizeConfig.w(3)),
                        Text(
                          turf.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: SizeConfig.sp(12),
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: SizeConfig.w(3)),
                        Text(
                          '(${turf.ratingCount})',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w400,
                            fontSize: SizeConfig.sp(11),
                            color: Colors.white.withAlpha(120),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          turf.priceFrom,
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: SizeConfig.sp(13),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
