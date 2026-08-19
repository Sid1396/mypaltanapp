import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupNameStep extends GetView<SignupController> {
  const SignupNameStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.h(36)),
                Text(
                  'What should we\ncall you? 👋',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(30),
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Text(
                  "This is how you'll appear to other players",
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(32)),
                Text(
                  'Full Name',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.sp(13),
                    color: Colors.white,
                    letterSpacing: SizeConfig.w(0.3),
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(8),
                    borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                    border: Border.all(
                      color: AppColors.primary.withAlpha(35),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: controller.nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: SizeConfig.sp(16),
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'e.g. Arjun Sharma',
                      hintStyle: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(15),
                        color: Colors.white.withAlpha(80),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.w(16),
                        vertical: SizeConfig.h(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            SizeConfig.w(24),
            0,
            SizeConfig.w(24),
            SizeConfig.h(24),
          ),
          child: SizedBox(
            width: double.infinity,
            height: SizeConfig.h(56),
            child: ElevatedButton(
              onPressed: () {
                if (controller.validateName()) controller.nextStep();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.sp(16),
                  color: Colors.white,
                  letterSpacing: SizeConfig.w(0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
