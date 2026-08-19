import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import 'package:get/get.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import 'otp_bottom_sheet.dart';

class LoginBottomSheet extends StatefulWidget {
  const LoginBottomSheet({super.key});

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _getOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      AppSnackbar.error('Invalid Number', 'Please enter your mobile number');
      return;
    }
    if (phone.length != 10) {
      AppSnackbar.error('Invalid Number', 'Enter a valid 10-digit number');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // TODO: wire up real OTP service
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.info('OTP Sent', 'A 6-digit OTP was sent to +91 ${_phoneController.text}');
      final phone = _phoneController.text;
      Get.back();
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.bottomSheet(
          OtpBottomSheet(phoneNumber: phone),
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          enterBottomSheetDuration: const Duration(milliseconds: 350),
          exitBottomSheetDuration: const Duration(milliseconds: 250),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SizeConfig.r(28)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        SizeConfig.w(24),
        SizeConfig.h(12),
        SizeConfig.w(24),
        SizeConfig.h(32) + keyboardPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ───────────────────────────────────
          Center(
            child: Container(
              width: SizeConfig.w(40),
              height: SizeConfig.h(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(60),
                borderRadius: BorderRadius.circular(SizeConfig.r(4)),
              ),
            ),
          ),

          SizedBox(height: keyboardPadding > 0 ? SizeConfig.h(8) : SizeConfig.h(20)),

          // ── Logo ──────────────────────────────────────────
          Image.asset(
            'assets/images/paltan_logo.png',
            height: SizeConfig.h(72),
          ),

          Text(
            'Enter your mobile number to get started',
            style: TextStyle(
              color: Colors.white.withAlpha(140),
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              fontSize: SizeConfig.sp(14),
            ),
          ),

          SizedBox(height: keyboardPadding > 0 ? SizeConfig.h(16) : SizeConfig.h(32)),

            // ── Phone input ───────────────────────────────────
            Text(
              'Mobile Number',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: SizeConfig.sp(13),
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
              child: Row(
                children: [
                  // Country code
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig.w(14),
                      vertical: SizeConfig.h(16),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '🇮🇳',
                          style: TextStyle(fontSize: SizeConfig.sp(18)),
                        ),
                        SizedBox(width: SizeConfig.w(6)),
                        Text(
                          '+91',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: SizeConfig.sp(15),
                          ),
                        ),
                        SizedBox(width: SizeConfig.w(4)),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withAlpha(150),
                          size: SizeConfig.r(18),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1.2,
                    height: SizeConfig.h(24),
                    color: AppColors.primary.withAlpha(35),
                  ),

                  // Number field
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.sp(16),
                        letterSpacing: SizeConfig.w(1),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: '98765 43210',
                        hintStyle: TextStyle(
                          color: Colors.white.withAlpha(80),
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                          fontSize: SizeConfig.sp(15),
                          letterSpacing: 0,
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

            SizedBox(height: SizeConfig.h(28)),

            // ── Get OTP button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: SizeConfig.h(56),
              child: ElevatedButton(
                onPressed: _loading ? null : _getOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.secondary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(120),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        width: SizeConfig.r(22),
                        height: SizeConfig.r(22),
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Get OTP',
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

            SizedBox(height: SizeConfig.h(20)),

            // ── Terms ─────────────────────────────────────────
            Center(
              child: Text(
                'By continuing, you agree to our\nTerms of Service & Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(110),
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w400,
                  fontSize: SizeConfig.sp(12),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
    );
  }
}
