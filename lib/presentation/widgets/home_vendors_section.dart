import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import 'home_section_title.dart';

class HomeVendorsSection extends GetView<HomeController> {
  const HomeVendorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle('SPORTS SHOPS & VENDORS'),
        SizedBox(height: SizeConfig.h(14)),
        SizedBox(
          height: SizeConfig.h(150),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            itemCount: controller.vendors.length,
            separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(14)),
            itemBuilder: (_, i) {
              final vendor = controller.vendors[i];
              return Container(
                width: SizeConfig.w(180),
                padding: EdgeInsets.all(SizeConfig.w(14)),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(SizeConfig.r(18)),
                  border: Border.all(color: Colors.white.withAlpha(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: SizeConfig.r(40),
                      height: SizeConfig.r(40),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                      ),
                      child: Center(
                        child: Text(vendor.emoji, style: TextStyle(fontSize: SizeConfig.sp(20))),
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(10)),
                    Text(
                      vendor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.sp(13),
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(4)),
                    Text(
                      vendor.category,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w500,
                        fontSize: SizeConfig.sp(11),
                        color: Colors.white.withAlpha(140),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${vendor.distance} • ${vendor.area}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w400,
                              fontSize: SizeConfig.sp(10),
                              color: Colors.white.withAlpha(120),
                            ),
                          ),
                        ),
                        if (vendor.rating != null) ...[
                          Icon(Icons.star_rounded, color: AppColors.primary, size: SizeConfig.r(12)),
                          SizedBox(width: SizeConfig.w(2)),
                          Text(
                            vendor.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w700,
                              fontSize: SizeConfig.sp(11),
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
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
