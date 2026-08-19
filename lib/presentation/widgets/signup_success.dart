import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupSuccess extends GetView<SignupController> {
  const SignupSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return _SignupSuccessBody(name: controller.name.value);
  }
}

class _SignupSuccessBody extends StatefulWidget {
  final String name;
  const _SignupSuccessBody({required this.name});

  @override
  State<_SignupSuccessBody> createState() => _SignupSuccessBodyState();
}

class _SignupSuccessBodyState extends State<_SignupSuccessBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _goHome() {
    Get.offAllNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.name.trim().split(' ').first;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
      child: Column(
        children: [
          const Spacer(),
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: SizeConfig.r(96),
              height: SizeConfig.r(96),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: SizeConfig.r(56),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.h(24)),
          Text(
            'Welcome to MyPaltan,\n$firstName! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w900,
              fontSize: SizeConfig.sp(28),
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: SizeConfig.h(10)),
          Text(
            "You're all set to find your next game!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w400,
              fontSize: SizeConfig.sp(15),
              color: Colors.white.withAlpha(140),
            ),
          ),
          SizedBox(height: SizeConfig.h(40)),
          _FeatureRow(
            emoji: '🏏',
            title: 'Browse nearby events',
            subtitle: 'Find games happening around you',
          ),
          SizedBox(height: SizeConfig.h(16)),
          _FeatureRow(
            emoji: '👥',
            title: 'Join games with one tap',
            subtitle: 'Book your spot instantly',
          ),
          SizedBox(height: SizeConfig.h(16)),
          _FeatureRow(
            emoji: '⭐',
            title: 'Build your reputation',
            subtitle: 'Earn ratings from fellow players',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: SizeConfig.h(56),
            child: ElevatedButton(
              onPressed: _goHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                ),
              ),
              child: Text(
                "Let's Play! 🚀",
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.sp(17),
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.h(24)),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: SizeConfig.r(48),
          height: SizeConfig.r(48),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          ),
          child: Center(
            child: Text(emoji, style: TextStyle(fontSize: SizeConfig.sp(22))),
          ),
        ),
        SizedBox(width: SizeConfig.w(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.sp(15),
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w400,
                  fontSize: SizeConfig.sp(13),
                  color: Colors.white.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
