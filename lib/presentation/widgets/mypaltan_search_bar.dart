import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/mypaltan_controller.dart';

class MyPaltanSearchBar extends GetView<MyPaltanController> {
  const MyPaltanSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SizeConfig.h(52),
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(16)),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(SizeConfig.r(16)),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: Colors.white.withAlpha(140),
            size: SizeConfig.r(22),
          ),
          SizedBox(width: SizeConfig.w(10)),
          Expanded(
            child: TextField(
              onChanged: controller.onSearchChanged,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w500,
                fontSize: SizeConfig.sp(15),
                color: Colors.white,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Search events, sports, venues',
                hintStyle: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w400,
                  fontSize: SizeConfig.sp(14),
                  color: Colors.white.withAlpha(120),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
