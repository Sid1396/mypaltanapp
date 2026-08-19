import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';

class OtpBottomSheet extends StatefulWidget {
  final String phoneNumber;

  const OtpBottomSheet({super.key, required this.phoneNumber});

  @override
  State<OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<OtpBottomSheet> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { return t.cancel(); }
      setState(() {
        if (_resendSeconds > 0) { _resendSeconds--; } else { t.cancel(); }
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

  void _verify() {
    if (!_isComplete || _loading) return;
    setState(() => _loading = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_otp != '123456') {
        AppSnackbar.error('Invalid OTP', 'The OTP you entered is incorrect');
        for (final c in _controllers) { c.clear(); }
        setState(() {});
        _focusNodes[0].requestFocus();
        return;
      }
      Get.back();
      Get.toNamed(AppRoutes.signup);
    });
  }

  void _resend() {
    if (_resendSeconds > 0) return;
    for (final c in _controllers) { c.clear(); }
    setState(() {});
    _focusNodes[0].requestFocus();
    _startTimer();
    AppSnackbar.info('OTP Sent', 'A new OTP was sent to +91 ${widget.phoneNumber}');
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

          SizedBox(height: SizeConfig.h(20)),

          // ── Logo ──────────────────────────────────────────
          Image.asset(
            'assets/images/paltan_logo.png',
            height: SizeConfig.h(72),
          ),

          SizedBox(height: SizeConfig.h(20)),

          // ── Title ─────────────────────────────────────────
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
            'Enter the 6-digit OTP sent to +91 ${widget.phoneNumber}',
            style: TextStyle(
              color: Colors.white.withAlpha(140),
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              fontSize: SizeConfig.sp(14),
            ),
          ),

          SizedBox(height: SizeConfig.h(32)),

          // ── OTP boxes ─────────────────────────────────────
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

          SizedBox(height: SizeConfig.h(32)),

          // ── Verify button ─────────────────────────────────
          SizedBox(
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

          SizedBox(height: SizeConfig.h(20)),

          // ── Resend ────────────────────────────────────────
          Center(
            child: _resendSeconds > 0
                ? Text(
                    'Resend OTP in 0:${_resendSeconds.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(110),
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w400,
                      fontSize: SizeConfig.sp(13),
                      height: 1.6,
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
