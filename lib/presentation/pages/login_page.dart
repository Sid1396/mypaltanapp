import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getOtp() async {
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
    try {
      final res = await Get.find<ApiService>().sendOtp(phone);
      if (!mounted) return;
      if (res['success'] == true) {
        AppSnackbar.info('OTP Sent', 'A 6-digit OTP was sent to +91 $phone');
        Get.toNamed(AppRoutes.otp, arguments: phone);
      } else {
        AppSnackbar.error('Failed', res['message']?.toString() ?? 'Could not send OTP');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error('Network Error', 'Check your connection and try again');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back button ───────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                left: SizeConfig.w(4),
                top: SizeConfig.h(4),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: SizeConfig.r(20),
                ),
                onPressed: Get.back,
              ),
            ),

            // ── Scrollable content ────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: SizeConfig.h(16)),

                    // Logo
                    Image.asset(
                      'assets/images/paltan_logo.png',
                      height: SizeConfig.h(72),
                    ),

                    SizedBox(height: SizeConfig.h(4)),

                    Text(
                      'Enter your mobile number to get started',
                      style: TextStyle(
                        color: Colors.white.withAlpha(140),
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(14),
                      ),
                    ),

                    SizedBox(height: SizeConfig.h(40)),

                    // ── Phone input ───────────────────────────
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
                  ],
                ),
              ),
            ),

            // ── Pinned bottom: button + terms ─────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                SizeConfig.w(24),
                SizeConfig.h(16),
                SizeConfig.w(24),
                SizeConfig.h(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: SizeConfig.h(56),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _getOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
                              child: const CircularProgressIndicator(
                                color: Colors.white,
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

                  SizedBox(height: SizeConfig.h(16)),

                  Text(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
