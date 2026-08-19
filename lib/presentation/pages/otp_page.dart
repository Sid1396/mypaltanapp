import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  late final String _phone;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phone = (Get.arguments as String?) ?? '';
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == 6;

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_isComplete) {
      Future.delayed(const Duration(milliseconds: 300), _verify);
    }
  }

  Future<void> _verify() async {
    if (!_isComplete || _loading) return;
    setState(() => _loading = true);
    try {
      final res = await Get.find<ApiService>().verifyOtp(_phone, _otp);
      if (!mounted) return;
      if (res['success'] == true) {
        final userExists = res['userExists'] == true;
        if (userExists) {
          Get.offAllNamed(AppRoutes.home);
        } else {
          Get.toNamed(AppRoutes.signup);
        }
      } else {
        AppSnackbar.error('Invalid OTP', res['message']?.toString() ?? 'Incorrect OTP');
        for (final c in _controllers) { c.clear(); }
        setState(() {});
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error('Network Error', 'Check your connection and try again');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    for (final c in _controllers) { c.clear(); }
    setState(() {});
    _focusNodes[0].requestFocus();
    try {
      final res = await Get.find<ApiService>().sendOtp(_phone);
      _startTimer();
      if (res['success'] == true) {
        AppSnackbar.info('OTP Sent', 'A new OTP was sent to +91 $_phone');
      } else {
        AppSnackbar.error('Failed', res['message']?.toString() ?? 'Could not resend OTP');
      }
    } catch (e) {
      AppSnackbar.error('Network Error', 'Check your connection and try again');
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
                    SizedBox(height: SizeConfig.h(8)),

                    Image.asset(
                      'assets/images/paltan_logo.png',
                      height: SizeConfig.h(72),
                    ),

                    SizedBox(height: SizeConfig.h(24)),

                    Text(
                      'Verify your',
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w500,
                        fontSize: SizeConfig.sp(15),
                      ),
                    ),
                    Text(
                      'Mobile Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: SizeConfig.sp(32),
                        height: 1.1,
                      ),
                    ),

                    SizedBox(height: SizeConfig.h(6)),

                    Text(
                      'Enter the 6-digit OTP sent to +91 $_phone',
                      style: TextStyle(
                        color: Colors.white.withAlpha(140),
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(14),
                      ),
                    ),

                    SizedBox(height: SizeConfig.h(40)),

                    // ── OTP boxes ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (v) => _onChanged(v, i),
                        ),
                      ),
                    ),

                    SizedBox(height: SizeConfig.h(40)),

                    // ── Resend ────────────────────────────────
                    Center(
                      child: _resendSeconds > 0
                          ? Text(
                              'Resend OTP in 0:${_resendSeconds.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.white.withAlpha(110),
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w400,
                                fontSize: SizeConfig.sp(13),
                              ),
                            )
                          : GestureDetector(
                              onTap: _resend,
                              child: Text(
                                'Resend OTP',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w600,
                                  fontSize: SizeConfig.sp(13),
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pinned verify button ──────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                SizeConfig.w(24),
                SizeConfig.h(16),
                SizeConfig.w(24),
                SizeConfig.h(24),
              ),
              child: SizedBox(
                width: double.infinity,
                height: SizeConfig.h(56),
                child: ElevatedButton(
                  onPressed: (_isComplete && !_loading) ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withAlpha(80),
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
                          'Verify OTP',
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
        ),
      ),
    );
  }
}

// ─── OTP single-digit box ─────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SizeConfig.r(46),
      height: SizeConfig.r(56),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w700,
          fontSize: SizeConfig.sp(20),
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: AppColors.primary.withAlpha(8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SizeConfig.r(12)),
            borderSide: BorderSide(
              color: AppColors.primary.withAlpha(60),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SizeConfig.r(12)),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
