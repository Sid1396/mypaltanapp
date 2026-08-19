import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupPincodeStep extends GetView<SignupController> {
  const SignupPincodeStep({super.key});

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
                  'Where do\nyou live? 📍',
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
                  "We'll show you games near you",
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(32)),
                Text(
                  'Pincode',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.sp(13),
                    color: Colors.white,
                    letterSpacing: SizeConfig.w(0.3),
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Obx(() {
                  final isError =
                      controller.pincodeStatus.value == PincodeStatus.invalid;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(8),
                      borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                      border: Border.all(
                        color: isError
                            ? const Color(0xFFE24B4A)
                            : AppColors.primary.withAlpha(35),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: controller.pincodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.sp(16),
                        color: Colors.white,
                        letterSpacing: SizeConfig.w(2),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: '400001',
                        hintStyle: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                          fontSize: SizeConfig.sp(15),
                          color: Colors.white.withAlpha(80),
                          letterSpacing: 0,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.w(16),
                          vertical: SizeConfig.h(16),
                        ),
                      ),
                    ),
                  );
                }),
                SizedBox(height: SizeConfig.h(12)),
                Obx(() => _PincodeStatusRow(
                    status: controller.pincodeStatus.value)),
                SizedBox(height: SizeConfig.h(24)),
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
          child: Obx(() {
            final isValid =
                controller.pincodeStatus.value == PincodeStatus.valid;
            return SizedBox(
              width: double.infinity,
              height: SizeConfig.h(56),
              child: ElevatedButton(
                onPressed: isValid ? controller.nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(60),
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
            );
          }),
        ),
      ],
    );
  }
}

class _PincodeStatusRow extends StatelessWidget {
  final PincodeStatus status;
  const _PincodeStatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PincodeStatus.loading => Row(
          children: [
            SizedBox(
              width: SizeConfig.r(16),
              height: SizeConfig.r(16),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: SizeConfig.w(8)),
            Text(
              'Fetching location...',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w500,
                fontSize: SizeConfig.sp(13),
                color: Colors.white.withAlpha(140),
              ),
            ),
          ],
        ),
      PincodeStatus.valid => Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: const Color(0xFF0F6E56), size: SizeConfig.r(18)),
            SizedBox(width: SizeConfig.w(6)),
            Text(
              'Location verified',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: SizeConfig.sp(13),
                color: const Color(0xFF0F6E56),
              ),
            ),
          ],
        ),
      PincodeStatus.invalid => Row(
          children: [
            Icon(Icons.cancel_rounded,
                color: const Color(0xFFE24B4A), size: SizeConfig.r(18)),
            SizedBox(width: SizeConfig.w(6)),
            Text(
              'Invalid pincode, try another',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w500,
                fontSize: SizeConfig.sp(13),
                color: const Color(0xFFE24B4A),
              ),
            ),
          ],
        ),
      PincodeStatus.idle => const SizedBox.shrink(),
    };
  }
}
